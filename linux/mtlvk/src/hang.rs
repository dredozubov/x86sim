//! x86Sim (issue #37): command buffers that take too long, named in mtlvk.log.
//!
//! A GPU job that runs past the kernel's timeout is ended by the driver (amdgpu: "ring gfx_0.0.0 timeout", the
//! process and thread named are mtlvk's m2v-submit, which only submitted it), and the log then showed nothing of
//! what that job was. Every committed command buffer is noted here with a one-line summary of what it carries (render
//! passes and their target sizes, draws, dispatches, blits, the pipelines' function names, its event waits and
//! signals); a watchdog thread logs each one still not complete MTLVK_HANG_SECS (default 1; 0 = off) after its commit,
//! once, before amdgpu's ~10 s timeout fires, with whether each of its event waits is met (a wait not met is held on
//! the host by the runtime and never reaches the GPU), and how long it finally took. The device's first loss
//! (`Device::loss`: the Vulkan call, its result and the driver's fault report, where VK_EXT_device_fault gave one) is
//! logged once, as are the Vulkan driver and its version at startup.

use metal2vulkan_runtime::{Device, SharedEvent};
use std::collections::BTreeMap;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// What one committed command buffer carries, built while its commands are decoded.
#[derive(Default)]
pub struct Summary {
    pub passes: u32,
    /// The first colour (or depth) target size of each render pass, up to a few.
    pub targets: Vec<(u32, u32)>,
    pub draws: u32,
    pub indirect_draws: u32,
    /// The most vertices (or indices) x instances of one direct draw.
    pub max_draw: u64,
    pub dispatches: u32,
    pub indirect_dispatches: u32,
    /// The most threads of one direct dispatch.
    pub max_threads: u64,
    pub blits: u32,
    /// Function names of the pipelines bound, in order, without repeats (up to a few).
    pub pipelines: Vec<String>,
    /// (event id, value): the event waits and signals it encodes.
    pub waits: Vec<(u64, SharedEvent, u64)>,
    pub signals: Vec<(u64, u64)>,
    pub proxy_copies: usize,
}

impl Summary {
    pub fn pipeline(&mut self, name: Option<&str>) {
        let name = name.unwrap_or("?");
        if self.pipelines.len() < 8 && !self.pipelines.iter().any(|p| p == name) {
            self.pipelines.push(name.to_owned());
        }
    }

    fn line(&self) -> String {
        let mut s = format!("{} pass(es)", self.passes);
        if !self.targets.is_empty() {
            let t: Vec<String> = self.targets.iter().map(|(w, h)| format!("{w}x{h}")).collect();
            s += &format!(" [{}]", t.join(" "));
        }
        s += &format!(", {} draw(s) (+{} indirect, largest {})", self.draws, self.indirect_draws, self.max_draw);
        s += &format!(", {} dispatch(es) (+{} indirect, largest {} threads)", self.dispatches, self.indirect_dispatches, self.max_threads);
        s += &format!(", {} blit(s), {} VRAM-target copy-back(s)", self.blits, self.proxy_copies);
        if !self.pipelines.is_empty() {
            s += &format!(", functions: {}", self.pipelines.join(" "));
        }
        for (id, ev, v) in &self.waits {
            let now = ev.signaled_value();
            s += &format!(", waits event {id:#x} for {v} (now {now}{})", if now >= *v { ", met" } else { ", NOT met: held on the host" });
        }
        for (id, v) in &self.signals {
            s += &format!(", signals event {id:#x} to {v}");
        }
        s
    }
}

struct Flight {
    conn: usize,
    cb: u64,
    at: Instant,
    summary: Summary,
    reported: bool,
}

static NEXT: AtomicU64 = AtomicU64::new(1);
static FLIGHT: Mutex<BTreeMap<u64, Flight>> = Mutex::new(BTreeMap::new());
static ON: AtomicBool = AtomicBool::new(false);

fn secs() -> f64 {
    std::env::var("MTLVK_HANG_SECS").ok().and_then(|v| v.parse::<f64>().ok()).unwrap_or(1.0)
}

/// Notes a command buffer as it is committed; the token goes to [`done`] from its completed handler.
pub fn committed(conn: usize, cb: u64, summary: Summary) -> u64 {
    let token = NEXT.fetch_add(1, Ordering::Relaxed);
    if ON.load(Ordering::Relaxed) {
        let f = Flight { conn, cb, at: Instant::now(), summary, reported: false };
        FLIGHT.lock().unwrap_or_else(|e| e.into_inner()).insert(token, f);
    }
    token
}

/// The command buffer of `token` completed (`ok`) or failed.
pub fn done(token: u64, ok: bool) {
    let Some(f) = FLIGHT.lock().unwrap_or_else(|e| e.into_inner()).remove(&token) else { return };
    if f.reported || !ok {
        eprintln!(
            "mtlvk hang: conn{} cb {:#x} {} after {:.1} s",
            f.conn,
            f.cb,
            if ok { "completed" } else { "FAILED" },
            f.at.elapsed().as_secs_f64()
        );
    }
}

/// Logs the Vulkan driver once, and starts the watchdog: the device's loss always (issue #39: MTLVK_HANG_SECS=0 hid it
/// too), late command buffers unless MTLVK_HANG_SECS=0.
pub fn start(device: Device) {
    log_driver(&device);
    let limit = secs();
    let late_on = limit > 0.0;
    ON.store(late_on, Ordering::Relaxed);
    let limit = Duration::from_secs_f64(limit.max(0.0));
    if late_on {
        eprintln!("mtlvk: command buffers not complete {:.1} s after commit are logged (MTLVK_HANG_SECS)", limit.as_secs_f64());
    }
    let _ = std::thread::Builder::new().name("hang-watch".into()).spawn(move || {
        let mut loss_logged = false;
        loop {
            std::thread::sleep(Duration::from_millis(500));
            if !loss_logged {
                if let Some(loss) = device.loss() {
                    loss_logged = true;
                    // The runtime ends every command buffer the loss reaches DeviceLost. Recreating the device is not
                    // done: every guest Metal object of every phone on this mtlvk lives on it, and metalhostd does
                    // not reconnect, so those phones keep their last frame until they are restarted.
                    eprintln!(
                        "mtlvk hang: DEVICE LOST at {} ({:?}): every phone on this mtlvk keeps its last frame until it is restarted",
                        loss.call, loss.result
                    );
                    match &loss.fault {
                        Some(f) => {
                            eprintln!("mtlvk hang: driver fault report: {:?}", f.description);
                            for a in f.accesses.iter().chain(&f.instructions) {
                                eprintln!("mtlvk hang:   {a:?}");
                            }
                            for p in &f.places {
                                eprintln!("mtlvk hang:   {p}");
                            }
                            for (d, code, data) in &f.vendor {
                                eprintln!("mtlvk hang:   vendor {d:?} code {code:#x} data {data:#x}");
                            }
                        }
                        None => eprintln!("mtlvk hang: no driver fault report (VK_EXT_device_fault absent or empty)"),
                    }
                }
            }
            if !late_on {
                if loss_logged {
                    return;
                }
                continue;
            }
            let mut flight = FLIGHT.lock().unwrap_or_else(|e| e.into_inner());
            let total = flight.len();
            let late: Vec<u64> = flight.iter().filter(|(_, f)| !f.reported && f.at.elapsed() >= limit).map(|(t, _)| *t).collect();
            if late.is_empty() {
                continue;
            }
            eprintln!("mtlvk hang: {} command buffer(s) not complete after {:.1} s ({total} in flight):", late.len(), limit.as_secs_f64());
            for (i, t) in late.iter().enumerate() {
                let f = flight.get_mut(t).unwrap();
                f.reported = true;
                if i < 6 {
                    eprintln!(
                        "mtlvk hang:   conn{} cb {:#x}, committed {:.1} s ago: {}",
                        f.conn,
                        f.cb,
                        f.at.elapsed().as_secs_f64(),
                        f.summary.line()
                    );
                }
            }
            if late.len() > 6 {
                eprintln!("mtlvk hang:   ... and {} more", late.len() - 6);
            }
        }
    });
}

fn log_driver(device: &Device) {
    let raw = device.raw();
    let mut driver = ash::vk::PhysicalDeviceDriverProperties::default();
    let mut props = ash::vk::PhysicalDeviceProperties2::default().push_next(&mut driver);
    // SAFETY: a query of the device's own physical device (Vulkan 1.2 is in the runtime's floor).
    unsafe { raw.instance.get_physical_device_properties2(raw.physical_device, &mut props) };
    let p = props.properties;
    let name = driver.driver_name_as_c_str().map(|c| c.to_string_lossy().into_owned()).unwrap_or_default();
    let info = driver.driver_info_as_c_str().map(|c| c.to_string_lossy().into_owned()).unwrap_or_default();
    eprintln!(
        "mtlvk: Vulkan driver {name} (id {}) {info}, API {}.{}.{}, vendor {:#06x} device {:#06x}",
        driver.driver_id.as_raw(),
        ash::vk::api_version_major(p.api_version),
        ash::vk::api_version_minor(p.api_version),
        ash::vk::api_version_patch(p.api_version),
        p.vendor_id,
        p.device_id
    );
}
