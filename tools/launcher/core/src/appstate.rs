//! What an app is doing on a phone (`x86sim app-state`, MCP `app_state`): installed or not, its process(es) (the
//! Darwin pid inside the phone, as simctl launch answers), state (foreground / background from the app's own simax
//! reader, suspended when its process is stopped or does not answer), memory and CPU, uptime, and how its last run
//! ended (launchd's exit line). Processes are found in /proc below the phone's launchd_sim, by the app's executable
//! path, as cli/libexec/simctl.py pidof does.
use crate::aot::repo_root;
use crate::instance::Instance;
use anyhow::{bail, Context, Result};
use serde::Serialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;
use std::time::Duration;

#[derive(Debug, Clone, Serialize, Default)]
pub struct Proc {
    /// the pid inside the phone (Darling's pid namespace)
    pub pid: u32,
    /// the Linux pid
    pub host_pid: u32,
    /// foreground, background, suspended, running (no UI reader: not a UIKit process, or not yet)
    pub state: String,
    pub memory_mb: f64,
    /// over the last fraction of a second
    pub cpu_pct: f64,
    pub uptime_s: f64,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct Exit {
    /// launchd's time of the line (the phone's clock)
    pub when: String,
    /// "exit(3)", "SIGABRT", "SIGKILL" ...
    pub how: String,
    /// launchd's line as it is
    pub line: String,
    /// why it died, when that was recorded (an abort reason)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct AppState {
    pub bundle_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    pub installed: bool,
    pub running: bool,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub processes: Vec<Proc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_exit: Option<Exit>,
}

/// Installed apps (simctl listapps --json): bundle id -> its Info (Path, CFBundleExecutable, CFBundleDisplayName ...)
pub fn installed(inst: &Instance) -> Result<HashMap<String, Value>> {
    let out = Command::new(repo_root().join("cli/x86sim")).arg("listapps").arg(&inst.dir).arg("--json").current_dir(repo_root()).output().context("running cli/x86sim listapps")?;
    if !out.status.success() {
        bail!("listapps: {}", String::from_utf8_lossy(&out.stderr).trim());
    }
    let v: HashMap<String, Value> = serde_json::from_slice(&out.stdout).context("listapps --json")?;
    Ok(v)
}

fn read(p: &str) -> String {
    std::fs::read(p).map(|b| String::from_utf8_lossy(&b).into_owned()).unwrap_or_default()
}

/// A path inside Darling as the Linux path (simctl.py dview_to_linux)
fn linux_path(p: &str) -> String {
    for pre in ["/private/Volumes/SystemRoot", "/Volumes/SystemRoot"] {
        if let Some(r) = p.strip_prefix(pre) {
            if r.starts_with('/') {
                return r.to_string();
            }
        }
    }
    p.to_string()
}

struct Row {
    ppid: u32,
    comm: String,
    ticks: u64,
    start: u64,
    state: char,
}

fn scan() -> HashMap<u32, Row> {
    let mut m = HashMap::new();
    for e in std::fs::read_dir("/proc").into_iter().flatten().flatten() {
        let Ok(pid) = e.file_name().to_string_lossy().parse::<u32>() else { continue };
        let stat = read(&format!("/proc/{pid}/stat"));
        let Some((head, rest)) = stat.rsplit_once(')') else { continue };
        let f: Vec<&str> = rest.split_whitespace().collect();
        let n = |i: usize| f.get(i).and_then(|x| x.parse::<u64>().ok()).unwrap_or(0);
        m.insert(pid, Row { ppid: n(1) as u32, comm: head.split_once('(').map(|x| x.1.to_string()).unwrap_or_default(), ticks: n(11) + n(12), start: n(19), state: f.first().and_then(|s| s.chars().next()).unwrap_or('?') });
    }
    m
}

/// The phone's processes: its launchd_sim and everything below it (Linux pids)
fn phone_pids(inst: &Instance, procs: &HashMap<u32, Row>) -> Vec<u32> {
    let marker = format!("/Volumes/SystemRoot{}/data/var/run/launchd_bootstrap.plist", inst.dir.display());
    let Some(l) = procs.iter().find(|(p, r)| r.comm == "launchd_sim" && read(&format!("/proc/{p}/cmdline")).contains(&marker)).map(|(p, _)| *p) else { return vec![] };
    let mut kids: HashMap<u32, Vec<u32>> = HashMap::new();
    for (p, r) in procs {
        kids.entry(r.ppid).or_default().push(*p);
    }
    let (mut out, mut work) = (vec![], vec![l]);
    while let Some(p) = work.pop() {
        out.push(p);
        work.extend(kids.get(&p).into_iter().flatten().copied());
    }
    out
}

fn ns_pid(p: u32) -> u32 {
    read(&format!("/proc/{p}/status")).lines().find_map(|l| l.strip_prefix("NSpid:")).and_then(|v| v.split_whitespace().last()).and_then(|v| v.parse().ok()).unwrap_or(p)
}

fn rss_mb(p: u32) -> f64 {
    read(&format!("/proc/{p}/status")).lines().find_map(|l| l.strip_prefix("VmRSS:")).map(|v| v.trim().trim_end_matches("kB").trim().parse::<f64>().unwrap_or(0.0) / 1024.0).unwrap_or(0.0)
}

/// The Linux pids of an app's process(es) on the phone: its executable (or arm64host loading it) by path
fn app_pids(app: &Value, pids: &[u32]) -> Vec<u32> {
    let exe = app["CFBundleExecutable"].as_str().unwrap_or("");
    let path = linux_path(app["Path"].as_str().unwrap_or(""));
    if exe.is_empty() || path.is_empty() {
        return vec![];
    }
    let tail = format!("/{exe}");
    pids.iter()
        .copied()
        .filter(|p| {
            let cl = read(&format!("/proc/{p}/cmdline"));
            let a: Vec<&str> = cl.split('\0').collect();
            let a0 = a.first().copied().unwrap_or("");
            (a0.ends_with(&tail) && a0.contains(&path)) || (a0.ends_with("/arm64host") && a.get(1).is_some_and(|x| x.ends_with(&tail) && x.contains(&path)))
        })
        .collect()
}

/// The app's state from its own simax reader (foreground / background), or what its process says (suspended)
fn ui_state(inst: &Instance, pid: u32, host_pid: u32, procs: &HashMap<u32, Row>) -> String {
    if procs.get(&host_pid).is_some_and(|r| r.state == 'T' || r.state == 't') {
        return "suspended".into();
    }
    let has_reader = crate::ax::endpoints(inst).iter().any(|e| crate::ax::pid_of_sock(&e.sock) == pid);
    if !has_reader {
        return "running".into();
    }
    match crate::ax::ask_pid(inst, pid, &json!({"op": "info"}), Duration::from_millis(1200)) {
        Ok(v) if v["error"].as_str().is_some_and(|e| e.starts_with("busy")) => "busy (main thread not answering)".into(),
        Ok(v) => match v["state"].as_str().unwrap_or("") {
            "active" => "foreground".into(),
            "inactive" => "foreground (inactive)".into(),
            "background" => "background".into(),
            s => s.to_string(),
        },
        // a reader that does not even accept: its process is held (RunningBoard's suspension)
        Err(_) => "suspended".into(),
    }
}

/// launchd's lines of the phone this boot (the state dir's copy), lossy text
fn launchd_log(inst: &Instance) -> String {
    let st = crate::instance::Monitor::default().poll(std::slice::from_ref(inst)).into_iter().next();
    let dir: PathBuf = st.map(|s| s.state_dir).unwrap_or_else(|| inst.state_dir.clone());
    read(&dir.join("launchd.log").to_string_lossy())
}

/// The last "exited due to ..." line of an app's job (UIKitApplication:<bid>[...]) in launchd's log
pub fn last_exit_in(log: &str, bundle: &str) -> Option<Exit> {
    let key = format!("UIKitApplication:{bundle}[");
    let l = log.lines().filter(|l| l.contains(&key) && (l.contains("exited due to") || l.contains("exited with"))).last()?;
    let when = l.split(" (").next().unwrap_or("").trim().to_string();
    let how = l
        .split_once("exited due to ")
        .or_else(|| l.split_once("exited with "))
        .map(|(_, r)| r.split(", ran for").next().unwrap_or(r).trim().to_string())
        .unwrap_or_default();
    Some(Exit { when, how, line: l.trim().to_string(), reason: None })
}

fn sample(procs: &HashMap<u32, Row>, pids: &[u32]) -> HashMap<u32, u64> {
    pids.iter().filter_map(|p| procs.get(p).map(|r| (*p, r.ticks))).collect()
}

/// The state of one app, or (bundle None) of every app running on the phone
pub fn app_state(inst: &Instance, bundle: Option<&str>) -> Result<Vec<AppState>> {
    let apps = installed(inst)?;
    let log = launchd_log(inst);
    let hz = unsafe { libc::sysconf(libc::_SC_CLK_TCK) }.max(1) as f64;
    let btime: f64 = read("/proc/stat").lines().find_map(|l| l.strip_prefix("btime ")).and_then(|v| v.trim().parse().ok()).unwrap_or(0.0);
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0);
    let procs = scan();
    let pids = phone_pids(inst, &procs);
    let want: Vec<String> = match bundle {
        Some(b) => vec![b.to_string()],
        None => apps.keys().cloned().collect(),
    };
    let found: Vec<(String, Vec<u32>)> = want.iter().map(|b| (b.clone(), apps.get(b).map(|a| app_pids(a, &pids)).unwrap_or_default())).collect();
    // CPU over a short window
    let all: Vec<u32> = found.iter().flat_map(|f| f.1.iter().copied()).collect();
    let t0 = sample(&procs, &all);
    let procs2 = if all.is_empty() {
        procs
    } else {
        std::thread::sleep(Duration::from_millis(300));
        scan()
    };
    let t1 = sample(&procs2, &all);
    let mut out = vec![];
    for (b, hp) in found {
        let app = apps.get(&b);
        if bundle.is_none() && hp.is_empty() {
            continue;
        }
        let processes: Vec<Proc> = hp
            .iter()
            .filter(|p| procs2.contains_key(p))
            .map(|&p| {
                let pid = ns_pid(p);
                let start = procs2.get(&p).map(|r| r.start).unwrap_or(0) as f64 / hz + btime;
                let cpu = (t1.get(&p).copied().unwrap_or(0).saturating_sub(t0.get(&p).copied().unwrap_or(0))) as f64 / hz / 0.3 * 100.0;
                Proc { pid, host_pid: p, state: ui_state(inst, pid, p, &procs2), memory_mb: (rss_mb(p) * 10.0).round() / 10.0, cpu_pct: cpu.round(), uptime_s: (now - start).max(0.0).round() }
            })
            .collect();
        out.push(AppState {
            name: app.and_then(|a| a["CFBundleDisplayName"].as_str().or(a["CFBundleName"].as_str())).map(String::from),
            installed: app.is_some(),
            running: !processes.is_empty(),
            processes,
            last_exit: last_exit_in(&log, &b),
            bundle_id: b,
        });
    }
    out.sort_by(|a, b| a.bundle_id.cmp(&b.bundle_id));
    Ok(out)
}

impl AppState {
    pub fn text(&self) -> String {
        let mut s = format!("{}{}: ", self.bundle_id, self.name.as_deref().map(|n| format!(" ({n})")).unwrap_or_default());
        if !self.installed {
            s += "not installed";
        } else if !self.running {
            s += "installed, not running";
        } else {
            s += &self
                .processes
                .iter()
                .map(|p| format!("running, pid {} {}, {:.0} MB, {:.0}% CPU, up {:.0} s", p.pid, p.state, p.memory_mb, p.cpu_pct, p.uptime_s))
                .collect::<Vec<_>>()
                .join("; ");
        }
        if let Some(e) = &self.last_exit {
            s += &format!("\n  last exit: {} at {}", e.how, e.when);
            if let Some(r) = &e.reason {
                s += &format!("\n  reason: {r}");
            }
        }
        s
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exit_lines() {
        let log = "2026-11-25 13:43:07.474116 (user/1000/UIKitApplication:com.x.a[2957][rb-legacy] [1853]) <Notice>: Successfully spawned a[1853]\n\
2026-11-25 13:43:15.140071 (user/1000/UIKitApplication:com.x.a[2957][rb-legacy] [1853]) <Notice>: exited due to SIGKILL, ran for 12276414149556ms\n\
2026-11-25 13:50:01.000001 (user/1000/UIKitApplication:com.x.a[2958][rb-legacy] [1900]) <Notice>: exited due to exit(3), ran for 5ms\n\
2026-11-25 13:51:01.000001 (user/1000/UIKitApplication:com.x.ab[2959][rb-legacy] [1901]) <Notice>: exited due to SIGABRT | sent by x86forms[1901], ran for 9ms\n";
        let e = last_exit_in(log, "com.x.a").unwrap();
        assert_eq!(e.how, "exit(3)");
        assert_eq!(e.when, "2026-11-25 13:50:01.000001");
        assert_eq!(last_exit_in(log, "com.x.ab").unwrap().how, "SIGABRT | sent by x86forms[1901]");
        assert!(last_exit_in(log, "com.x").is_none());
        assert_eq!(linux_path("/Volumes/SystemRoot/srv/x/a.app"), "/srv/x/a.app");
        assert_eq!(linux_path("/Applications/A.app"), "/Applications/A.app");
    }
}
