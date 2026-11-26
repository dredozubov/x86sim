//! The device page's panels the launcher has (gui/src/phone.rs, devctl_ui.rs), for the browser: the overview and
//! Performance (processes, the GPU helper), Logs (a tail kept per device while someone reads it), Features (the iOS
//! feature set), Simulate (appearance, text size, Increase Contrast, fidelity, the hardware keyboard) and Restart.
//! Server-wide or destructive things (versions, pre-translation, erase, clone, remove, a device's boot settings) stay
//! in the launcher and the CLI: a share link drives a device, it doesn't administer the machine.
use crate::features;
use crate::instance::{self, Instance, Phase, Status};
use crate::logs::Tail;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// A request's answer: a JSON body, or an HTTP code and a message
pub type Answer = Result<Value, (u16, String)>;

fn bad(code: u16, msg: impl Into<String>) -> (u16, String) {
    (code, msg.into())
}

struct LogTail {
    tail: Tail,
    /// lines ever added (the newest line's number; the buffer holds the last `tail.lines.len()` of them)
    total: u64,
    boot: Option<f64>,
    used: Instant,
}

#[derive(Default)]
pub struct Devices {
    /// CPU is sampled between polls: one monitor for every request, its last poll kept a moment
    monitor: Mutex<(instance::Monitor, Option<Instant>, Vec<Status>)>,
    logs: Mutex<HashMap<String, LogTail>>,
}

impl Devices {
    /// Every device's status (processes, CPU, the GPU helper), at most every 1.5 s
    pub fn statuses(&self) -> Vec<Status> {
        let mut m = self.monitor.lock().unwrap();
        if m.1.is_none_or(|t| t.elapsed() > Duration::from_millis(1500)) {
            let insts = instance::list();
            m.2 = m.0.poll(&insts);
            m.1 = Some(Instant::now());
        }
        m.2.clone()
    }

    fn status(&self, id: &str) -> Option<Status> {
        self.statuses().into_iter().find(|s| s.id == id)
    }

    /// The overview and Performance: screen, the process table (largest first, 25), the GPU helper, whether settings
    /// changed since the boot
    pub fn detail(&self, inst: &Instance) -> Answer {
        let st = self.status(&inst.id);
        let on = st.as_ref().is_some_and(|s| s.phase != Phase::Off);
        let s = st.as_ref().filter(|_| on);
        let mut procs: Vec<&instance::Proc> = s.map(|s| s.procs.iter().collect()).unwrap_or_default();
        procs.sort_by(|a, b| b.pss_mb.total_cmp(&a.pss_mb));
        Ok(json!({
            "phase": st.as_ref().map(|s| s.phase),
            "screen": [inst.screen.0, inst.screen.1],
            "memory_mb": s.map(|s| s.pss_mb), "cpu_pct": s.map(|s| s.cpu_pct), "uptime_s": s.and_then(|s| s.uptime_s),
            "processes": s.map(|s| s.procs.len()),
            "procs": procs.iter().take(25).map(|p| json!({"pid": p.pid, "name": p.comm, "memory_mb": p.pss_mb, "cpu_pct": p.cpu_pct})).collect::<Vec<_>>(),
            "gpu": s.and_then(|s| s.gpu.as_ref()).map(|g| json!({"pid": g.pid, "memory_mb": g.pss_mb, "cpu_pct": g.cpu_pct, "users": g.users,
                "name": g.device.as_ref().map(|d| d.label()), "short": g.device.as_ref().map(|d| d.compact()), "driver": g.device.as_ref().map(|d| d.driver.clone()),
                "buffers": g.buffers.as_ref().filter(|b| b.direct + b.udmabuf_buffers + b.mirrored > 0).map(|b| json!({"summary": b.summary(), "copying": b.copying(),
                    "shared": b.direct, "udmabuf": b.udmabuf_buffers, "copied": b.mirrored}))})),
            "needs_restart": instance::needs_restart(inst, st.as_ref()),
        }))
    }

    /// Restart: stop and start again, on a thread (a stop waits for the device to go down)
    pub fn restart(&self, inst: &Instance) -> Answer {
        let all = self.statuses();
        let st = all.iter().find(|s| s.id == inst.id).cloned();
        let others: Vec<Status> = all.into_iter().filter(|s| s.id != inst.id).collect();
        let inst = inst.clone();
        std::thread::spawn(move || {
            let _ = instance::restart(&inst, st.as_ref(), &others);
        });
        Ok(json!({"restarting": true}))
    }

    /// Log lines after line `after` (0: the last ones), up to 1000, newest last; `group` / `q` filter them as the
    /// launcher's Logs section does. The tail lives while someone reads it (a minute after the last read).
    pub fn logs(&self, inst: &Instance, after: u64, group: &str, q: &str) -> Answer {
        let st = self.status(&inst.id);
        let boot = st.as_ref().and_then(|s| s.boot_time);
        let mut all = self.logs.lock().unwrap();
        all.retain(|_, t| t.used.elapsed() < Duration::from_secs(60));
        let t = all.entry(inst.id.clone()).or_insert_with(|| LogTail { tail: Tail::new(vec![]), total: 0, boot: None, used: Instant::now() });
        // one tail per boot: a restart starts over (the dirs may change)
        if t.tail.srcs.is_empty() || (boot.is_some() && t.boot != boot) {
            t.tail = Tail::new(instance::log_sources(inst, st.as_ref()));
            t.tail.since = boot;
            t.boot = boot;
        }
        t.used = Instant::now();
        t.total += t.tail.poll() as u64;
        let first = t.total - t.tail.lines.len() as u64 + 1;
        let q = q.to_lowercase();
        let lines: Vec<Value> = t
            .tail
            .lines
            .iter()
            .enumerate()
            .map(|(i, l)| (first + i as u64, l))
            .filter(|(n, l)| *n > after && (group.is_empty() || l.group == group) && (q.is_empty() || l.text.to_lowercase().contains(&q) || l.source.to_lowercase().contains(&q)))
            .map(|(n, l)| {
                let (time, msg) = crate::logs::split_time(&l.text);
                json!({"n": n, "group": l.group, "source": l.source, "time": time, "text": msg})
            })
            .collect();
        let skip = lines.len().saturating_sub(1000);
        // a restart restarted the numbering: the page starts over when `last` goes down
        Ok(json!({"last": t.total, "boot": boot, "groups": t.tail.groups(), "lines": &lines[skip..]}))
    }

    /// Features (iPhone and iPad): the preset, each feature and what it costs
    pub fn features(&self, inst: &Instance) -> Answer {
        if inst.platform != "ios" {
            return Err(bad(400, "features are for iPhone and iPad"));
        }
        let prof = features::load(&inst.dir);
        let st = self.status(&inst.id);
        Ok(json!({
            "preset": features::preset_of(&prof),
            "features": features::list(&inst.dir).into_iter().map(|f| json!({"id": f.id, "title": f.title, "desc": f.desc, "tech": f.tech, "enabled": f.enabled, "default": f.default, "cost_mb": f.cost_mb})).collect::<Vec<_>>(),
            "running": st.as_ref().is_some_and(|s| s.phase != Phase::Off),
            "needs_restart": instance::needs_restart(inst, st.as_ref()),
        }))
    }

    /// `{"preset": "full" | "lean" | "minimal"}` or `{"id": …, "on": bool}`
    pub fn set_feature(&self, inst: &Instance, b: &Value) -> Answer {
        if inst.platform != "ios" {
            return Err(bad(400, "features are for iPhone and iPad"));
        }
        let r = if let Some(p) = b["preset"].as_str() {
            if !["full", "lean", "minimal"].contains(&p) {
                return Err(bad(400, "preset: full, lean or minimal"));
            }
            features::apply_preset(&inst.dir, p)
        } else {
            let id = b["id"].as_str().ok_or_else(|| bad(400, "id: a feature"))?;
            if !features::defs().features.iter().any(|f| f.id == id) {
                return Err(bad(404, "no such feature"));
            }
            features::set(&inst.dir, id, b["on"].as_bool().unwrap_or(true))
        };
        r.map_err(|e| bad(500, format!("{e:#}")))?;
        self.features(inst)
    }

    /// GPU: the device's setting (BootSettings::gpu), the choices, the GPU it renders on now; restart to apply
    pub fn gpu(&self, inst: &Instance) -> Answer {
        let l = crate::gpu::list().map_err(|e| bad(500, format!("{e:#}")))?;
        let st = self.status(&inst.id);
        let set = instance::load_settings(&inst.dir);
        let now = st.as_ref().filter(|s| s.phase != Phase::Off).and_then(|s| s.gpu.as_ref()).and_then(|g| g.device.as_ref()).map(|d| d.label());
        Ok(json!({
            "gpu": if set.gpu.is_empty() { "auto".to_string() } else { set.gpu.clone() },
            "label": crate::gpu::setting_label(&set.gpu, &l),
            "choices": crate::gpu::choices(&l).into_iter().map(|(v, l)| json!({"value": v, "label": l})).collect::<Vec<_>>(),
            "metal": set.metal != "0",
            "renders_on": now,
            "running": st.as_ref().is_some_and(|s| s.phase != Phase::Off),
            "needs_restart": instance::needs_restart(inst, st.as_ref()),
        }))
    }

    /// `{"gpu": "auto" | "cpu" | an id | part of a name}`
    pub fn set_gpu(&self, inst: &Instance, b: &Value) -> Answer {
        let w = b["gpu"].as_str().ok_or_else(|| bad(400, "gpu: auto, cpu or a GPU"))?;
        crate::gpu::set(&inst.dir, w).map_err(|e| bad(400, format!("{e:#}")))?;
        self.gpu(inst)
    }

    /// Simulate: what `x86sim ui` and `x86sim fidelity` say, and the hardware keyboard
    pub fn simulate(&self, inst: &Instance) -> Answer {
        let (mut appearance, mut content_size, mut contrast) = (String::new(), String::new(), String::new());
        if let Ok(t) = cli(inst, &["ui"]) {
            for l in t.lines() {
                match l.split_once(": ") {
                    Some(("appearance", v)) => appearance = v.into(),
                    Some(("content_size", v)) => content_size = v.into(),
                    Some(("increase_contrast", v)) => contrast = v.into(),
                    _ => {}
                }
            }
        }
        let fidelity = cli(inst, &["fidelity"]).map(|t| t.split_whitespace().next().unwrap_or("high").to_string()).unwrap_or_else(|_| "high".into());
        let phase = self.status(&inst.id).map(|s| s.phase).unwrap_or(Phase::Off);
        Ok(json!({
            "phase": phase,
            "appearance": appearance, "content_size": content_size, "increase_contrast": contrast == "enabled",
            "fidelity": fidelity, "hw_keyboard": crate::ax::hw_keyboard_connected(inst),
        }))
    }

    /// One change: `{"appearance": "light"}`, `{"content_size": "large"}`, `{"increase_contrast": true}`,
    /// `{"fidelity": "fast"}` or `{"hw_keyboard": false}`
    pub fn set_simulate(&self, inst: &Instance, b: &Value) -> Answer {
        const SIZES: [&str; 12] = ["extra-small", "small", "medium", "large", "extra-large", "extra-extra-large", "extra-extra-extra-large", "accessibility-medium", "accessibility-large", "accessibility-extra-large", "accessibility-extra-extra-large", "accessibility-extra-extra-extra-large"];
        let phase = self.status(&inst.id).map(|s| s.phase).unwrap_or(Phase::Off);
        if matches!(phase, Phase::Starting | Phase::Stopping) {
            return Err(bad(409, "wait until the device has started or stopped"));
        }
        let r = if let Some(v) = b["appearance"].as_str() {
            if !["light", "dark"].contains(&v) {
                return Err(bad(400, "appearance: light or dark"));
            }
            cli(inst, &["ui", "appearance", v])
        } else if let Some(v) = b["content_size"].as_str() {
            if !SIZES.contains(&v) {
                return Err(bad(400, "unknown text size"));
            }
            cli(inst, &["ui", "content_size", v])
        } else if let Some(on) = b["increase_contrast"].as_bool() {
            cli(inst, &["ui", "increase_contrast", if on { "enabled" } else { "disabled" }])
        } else if let Some(v) = b["fidelity"].as_str() {
            if !["fast", "high"].contains(&v) {
                return Err(bad(400, "fidelity: fast or high"));
            }
            cli(inst, &["fidelity", v])
        } else if let Some(on) = b["hw_keyboard"].as_bool() {
            crate::ax::keyboard(inst, "hardware", if on { "connect" } else { "disconnect" }, crate::ax::After::None).map(|o| o.did).map_err(|e| format!("{e:#}"))
        } else {
            return Err(bad(400, "nothing to change"));
        };
        r.map_err(|e| bad(500, e.lines().last().unwrap_or(&e).to_string()))?;
        self.simulate(inst)
    }
}

/// cli/x86sim <cmd> <device> <args…> (as the launcher's Simulate section runs it)
fn cli(inst: &Instance, args: &[&str]) -> Result<String, String> {
    let mut c = std::process::Command::new(crate::aot::repo_root().join("cli/x86sim"));
    c.arg(args[0]).arg(&inst.dir).args(&args[1..]).stdin(std::process::Stdio::null());
    match c.output() {
        Ok(o) if o.status.success() => Ok(String::from_utf8_lossy(&o.stdout).trim().to_string()),
        Ok(o) => Err(String::from_utf8_lossy(&o.stderr).trim().to_string()),
        Err(e) => Err(e.to_string()),
    }
}
