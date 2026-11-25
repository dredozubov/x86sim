//! Screen recording you start and stop (MCP `sim_record_video action=start|stop|status`, CLI `x86sim-ax record`):
//! the recorder is cli/libexec/simctl.py's `io recordVideo` (simfb's frame ring to ffmpeg), run in the background with
//! --secs = max_secs; stop sends it SIGTERM (by the pid recorded at start), which it takes as Ctrl-C: ffmpeg finishes
//! the file (moov atom) and the recorder exits. One recording per device; its state is a small JSON file in the scratch
//! dir (record-<device id>.json).
use crate::aot::{repo_root, scratch};
use crate::instance::Instance;
use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Rec {
    pid: u32,
    path: PathBuf,
    started: f64,
    max_secs: f64,
    log: PathBuf,
}

fn state_file(inst: &Instance) -> PathBuf {
    scratch().join(format!("record-{}.json", inst.id))
}

fn now() -> f64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0)
}

/// Is `pid` still our recorder (its command line names recordVideo and the file): never signal a pid reused since
fn ours(r: &Rec) -> bool {
    let cl = std::fs::read(format!("/proc/{}/cmdline", r.pid)).map(|b| String::from_utf8_lossy(&b).replace('\0', " ")).unwrap_or_default();
    let st = std::fs::read_to_string(format!("/proc/{}/stat", r.pid)).unwrap_or_default();
    let zombie = st.rsplit(')').next().is_some_and(|x| x.trim_start().starts_with('Z'));
    !zombie && cl.contains("recordVideo") && cl.contains(&*r.path.to_string_lossy())
}

fn load(inst: &Instance) -> Option<Rec> {
    serde_json::from_slice(&std::fs::read(state_file(inst)).ok()?).ok()
}

fn file_info(p: &Path) -> Value {
    json!({"path": p, "bytes": std::fs::metadata(p).map(|m| m.len()).unwrap_or(0)})
}

/// Starts recording into `path` (an .mp4), at most `max_secs`; returns at once
pub fn start(inst: &Instance, path: &Path, max_secs: f64, codec: &str) -> Result<Value> {
    if let Some(r) = load(inst).filter(ours) {
        bail!("{} is already being recorded into {} (pid {}): stop it first", inst.name, r.path.display(), r.pid);
    }
    anyhow::ensure!(!path.as_os_str().is_empty() && !path.to_string_lossy().starts_with('-'), "path: the .mp4 to write");
    anyhow::ensure!(matches!(codec, "h264" | "hevc"), "codec: h264 or hevc");
    let path = if path.is_absolute() { path.to_path_buf() } else { std::env::current_dir()?.join(path) };
    if let Some(d) = path.parent() {
        std::fs::create_dir_all(d).with_context(|| format!("{}", d.display()))?;
    }
    let max_secs = max_secs.clamp(1.0, 3600.0);
    let log = scratch().join(format!("record-{}.log", inst.id));
    let out = std::fs::File::create(&log)?;
    let mut cmd = Command::new(repo_root().join("cli/x86sim"));
    cmd.arg("io").arg(&inst.dir).args(["recordVideo", "--codec", codec, "--secs", &max_secs.to_string()]).arg(&path);
    // this device's frame ring, whatever the caller's environment says: an MCP server started from a shell that
    // sourced cli/lib/config.sh inherits the configured device's SIMFB_RING_LINUX, and `x86sim io` keeps a given one
    cmd.env("SIMFB_RING_LINUX", crate::ax::screen_ring(inst));
    cmd.current_dir(repo_root()).stdin(Stdio::null()).stdout(out.try_clone()?).stderr(out);
    // its own session: an MCP server that exits does not take it along (it ends at max_secs, or at stop)
    use std::os::unix::process::CommandExt;
    unsafe {
        cmd.pre_exec(|| {
            libc::setsid();
            Ok(())
        });
    }
    let mut child = cmd.spawn().context("starting the recorder")?;
    let r = Rec { pid: child.id(), path: path.clone(), started: now(), max_secs, log: log.clone() };
    // it says "recording" once ffmpeg is fed; a phone without frames fails at once
    let t0 = Instant::now();
    loop {
        if let Ok(Some(st)) = child.try_wait() {
            bail!("the recorder stopped ({st}): {}", std::fs::read_to_string(&log).unwrap_or_default().trim());
        }
        if std::fs::read_to_string(&log).unwrap_or_default().contains("recording") || t0.elapsed() > Duration::from_secs(5) {
            break;
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    std::fs::write(state_file(inst), serde_json::to_vec(&r)?)?;
    // reap it in the background when it ends by itself (max_secs), so no zombie lingers in a long-lived server
    std::thread::spawn(move || {
        let _ = child.wait();
    });
    Ok(json!({"phone": inst.name, "recording": true, "pid": r.pid, "path": path, "max_secs": max_secs}))
}

/// Where the recording is: running or not, how long so far, the file
pub fn status(inst: &Instance) -> Result<Value> {
    match load(inst) {
        Some(r) => {
            let running = ours(&r);
            let mut v = file_info(&r.path);
            v["phone"] = json!(inst.name);
            v["recording"] = json!(running);
            v["secs"] = json!(((now() - r.started).min(r.max_secs) * 10.0).round() / 10.0);
            v["max_secs"] = json!(r.max_secs);
            if !running {
                v["note"] = json!("ended (max_secs reached, or stopped): stop answers the file");
            }
            Ok(v)
        }
        None => Ok(json!({"phone": inst.name, "recording": false})),
    }
}

/// Stops the recording (SIGTERM to the recorder it started: ffmpeg finishes the file) and answers the file: path,
/// length, size
pub fn stop(inst: &Instance) -> Result<Value> {
    let Some(r) = load(inst) else { bail!("{} is not being recorded (sim_record_video action=start)", inst.name) };
    if ours(&r) {
        unsafe {
            libc::kill(r.pid as i32, libc::SIGTERM);
        }
        let t0 = Instant::now();
        while ours(&r) && t0.elapsed() < Duration::from_secs(60) {
            std::thread::sleep(Duration::from_millis(100));
        }
        anyhow::ensure!(!ours(&r), "the recorder (pid {}) did not finish within 60 s", r.pid);
    }
    let _ = std::fs::remove_file(state_file(inst));
    let log = std::fs::read_to_string(&r.log).unwrap_or_default();
    // "x86sim: wrote <path> (<n> frames, <s> s)"
    let secs = log.lines().filter_map(|l| l.strip_prefix("x86sim: wrote ")).filter_map(|l| l.rsplit_once(", ")).filter_map(|(_, t)| t.trim_end_matches(')').trim_end_matches(" s").parse::<f64>().ok()).last();
    let mut v = file_info(&r.path);
    anyhow::ensure!(v["bytes"].as_u64().unwrap_or(0) > 0, "no video written: {}", log.trim());
    v["phone"] = json!(inst.name);
    v["secs"] = json!(secs.unwrap_or(((now() - r.started).min(r.max_secs) * 10.0).round() / 10.0));
    v["stopped"] = json!(true);
    Ok(v)
}
