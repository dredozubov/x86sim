//! Is the phone's shell (SpringBoard; PineBoard, Carousel, SurfBoard on the other platforms) still answering?
//!
//! A phone whose SpringBoard main thread is stuck keeps every process, so the monitor (processes + a home frame once
//! seen) went on calling it "running" while taps, launches and snapshots timed out. The check asks the shell's simax
//! reader (host/simax) for `info`, which runs on the shell's main queue: a healthy shell answers in milliseconds, a
//! stuck one answers "busy" (simax's listener thread is alive, the main thread is not) or nothing.
//!
//! One slow answer is no hang: a boot or a heavy app keeps every core busy for seconds, and simax serves one client
//! at a time (a snapshot in progress queues the probe). The phone is called hung only after `MISSES` probes in a row
//! failed over at least `HUNG_AFTER`, and only once the shell has answered at least once this boot (a phone whose
//! shell never loads simax, X86SIM_AX_OFF, stays "unknown", never hung). The state (misses, the shell's socket) is kept
//! per boot in `<state dir>/shell-liveness.json`, so the MCP server, the CLI and the pool share one count; probes are
//! at most every `PROBE_EVERY` per phone, whoever asks.
use crate::ax;
use crate::instance::Instance;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::path::{Path, PathBuf};
use std::time::Duration;

/// How long one probe waits for the answer
const PROBE_TIMEOUT: Duration = Duration::from_millis(2500);
/// No new probe within this many seconds of the last one: its result stands
const PROBE_EVERY: f64 = 3.0;
/// Failed probes in a row (and the time they span) before the phone counts as hung
const MISSES: u32 = 3;
const HUNG_AFTER: f64 = 10.0;

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
#[serde(default)]
struct State {
    /// the boot these counts are of (launchd_sim's start, unix seconds)
    boot: f64,
    /// the shell answered at least once this boot
    seen: bool,
    /// its reader's socket (kept: Carousel drops its .fg marker while an app is in front, and still answers)
    sock: Option<PathBuf>,
    misses: u32,
    first_miss: f64,
    last_probe: f64,
    /// what the last failed probe saw
    why: String,
}

/// The shell's liveness, as phones_list / pool status show it
#[derive(Debug, Clone, Serialize)]
pub struct Liveness {
    /// None: not known (not at home yet, or the shell never answered this boot); Some(false): it does not answer now
    pub responsive: Option<bool>,
    /// failed probes in a row over at least HUNG_AFTER s: the shell is stuck (restart the phone)
    pub hung: bool,
    /// the last failed probe's reason
    pub why: String,
}

fn path(inst: &Instance) -> PathBuf {
    inst.state_dir.join("shell-liveness.json")
}

fn now() -> f64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0)
}

fn load(p: &Path) -> State {
    std::fs::read(p).ok().and_then(|b| serde_json::from_slice(&b).ok()).unwrap_or_default()
}

fn save(p: &Path, st: &State) {
    let tmp = p.with_extension(format!("json.{}", std::process::id()));
    if std::fs::write(&tmp, serde_json::to_vec(st).unwrap_or_default()).is_ok() {
        let _ = std::fs::rename(&tmp, p);
    }
}

/// The shell's reader sockets on screen (by their .fg marker), the remembered one first
fn shell_socks(inst: &Instance, known: Option<&PathBuf>) -> Vec<PathBuf> {
    let mut v: Vec<PathBuf> = known.filter(|k| k.exists()).cloned().into_iter().collect();
    for e in ax::endpoints(inst) {
        if e.fg && ax::SHELLS.contains(&ax::fg_bundle(&e.sock).as_str()) && !v.contains(&e.sock) {
            v.push(e.sock);
        }
    }
    v
}

/// One probe: Ok(socket) when the shell answered, Err(why) when not, None when there is no shell socket to ask
fn probe(inst: &Instance, known: Option<&PathBuf>) -> Option<Result<PathBuf, String>> {
    let socks = shell_socks(inst, known);
    if socks.is_empty() {
        return None;
    }
    let mut why = String::new();
    for s in socks {
        match ax::ask(&s, &json!({"op": "info"}), PROBE_TIMEOUT) {
            Ok(Some(v)) if v.get("error").is_none() => return Some(Ok(s)),
            Ok(Some(v)) => why = v["error"].as_str().unwrap_or("error").to_string(),
            // the process is gone (its socket was removed)
            Ok(None) => why = "its process is gone".into(),
            Err(e) => why = format!("no answer in {:.1} s ({e:#})", PROBE_TIMEOUT.as_secs_f64()),
        }
    }
    Some(Err(why))
}

/// Counts one probe's result into the state (at time `t`)
fn record(st: &mut State, r: Option<Result<PathBuf, String>>, t: f64) {
    st.last_probe = t;
    match r {
        Some(Ok(s)) => {
            st.seen = true;
            st.sock = Some(s);
            st.misses = 0;
            st.why.clear();
        }
        // nothing answered: unknown until the shell answered once this boot; after that a miss (a silent shell, or
        // no shell socket at all: SpringBoard crashed and is not back)
        _ if !st.seen => {}
        other => {
            if st.misses == 0 {
                st.first_miss = t;
            }
            st.misses += 1;
            st.why = match other {
                Some(Err(w)) => w,
                _ => "no SpringBoard process answers".into(),
            };
        }
    }
}

fn verdict(st: &State, t: f64) -> Liveness {
    let hung = st.seen && st.misses >= MISSES && t - st.first_miss >= HUNG_AFTER;
    Liveness { responsive: if st.seen { Some(st.misses == 0) } else { None }, hung, why: st.why.clone() }
}

/// The liveness of a running phone at its home screen (`boot`: its launchd_sim start). Probes when the last probe is
/// older than PROBE_EVERY, else answers from the shared state.
pub fn check(inst: &Instance, boot: f64) -> Liveness {
    let p = path(inst);
    let of_boot = |st: State| if (st.boot - boot).abs() > 1.0 { State { boot, ..Default::default() } } else { st };
    let mut st = of_boot(load(&p));
    let t = now();
    if t - st.last_probe >= PROBE_EVERY {
        // claimed first: callers in parallel (the pool's take loop, phones_list) don't all wait on a stuck shell
        st.last_probe = t;
        save(&p, &st);
        let r = probe(inst, st.sock.as_ref());
        // counted into the state as it is now (another caller may have counted meanwhile)
        st = of_boot(load(&p));
        record(&mut st, r, t);
        save(&p, &st);
    }
    verdict(&st, now())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn miss() -> Option<Result<PathBuf, String>> {
        Some(Err("busy".into()))
    }

    #[test]
    fn unknown_until_the_shell_answered_once() {
        let mut st = State::default();
        for i in 0..10 {
            record(&mut st, if i % 2 == 0 { None } else { miss() }, i as f64 * 3.0);
        }
        let v = verdict(&st, 30.0);
        assert_eq!(v.responsive, None);
        assert!(!v.hung);
    }

    #[test]
    fn hung_after_several_misses_over_time() {
        let mut st = State::default();
        record(&mut st, Some(Ok(PathBuf::from("/s"))), 0.0);
        assert_eq!(verdict(&st, 0.0).responsive, Some(true));
        // three quick misses: not responsive, not hung yet (a busy boot or a long snapshot)
        for t in [3.0, 6.0, 9.0] {
            record(&mut st, miss(), t);
        }
        let v = verdict(&st, 9.0);
        assert_eq!(v.responsive, Some(false));
        assert!(!v.hung);
        record(&mut st, None, 13.0);
        let v = verdict(&st, 13.0);
        assert!(v.hung, "{v:?}");
        assert_eq!(v.why, "no SpringBoard process answers");
        // one answer clears it
        record(&mut st, Some(Ok(PathBuf::from("/s2"))), 16.0);
        let v = verdict(&st, 16.0);
        assert!(!v.hung);
        assert_eq!(v.responsive, Some(true));
        assert_eq!(st.sock, Some(PathBuf::from("/s2")));
    }

    #[test]
    fn two_slow_answers_do_not_make_a_hang() {
        let mut st = State::default();
        record(&mut st, Some(Ok(PathBuf::from("/s"))), 0.0);
        record(&mut st, miss(), 3.0);
        record(&mut st, miss(), 30.0);
        assert!(!verdict(&st, 30.0).hung);
    }
}
