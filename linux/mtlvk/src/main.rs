//! mtlvk: the native Linux half of x86Sim's Metal stand-in for the iOS simulator.
//!
//! metalhostd (a Darling process running Apple's MTLSimImplementation over our MTLDevice classes) connects
//! here over a Unix socket and forwards Metal objects and command buffers in the VKMTL protocol
//! (host/metalhostd/vkmtl_proto.h). mtlvk executes them on Vulkan through metal2vulkan-runtime. Buffer memory is
//! shared without copying: metalhostd passes the memfd behind each MTLBuffer (Darling syscall 599) and
//! mtlvk maps it and imports the pages into Vulkan (VK_EXT_external_memory_host).
//!
//! Usage: mtlvk [socket path]      (default: var/run/mtlvk.sock, relative to the repo root)
//!        mtlvk selftest           (memfd import, clear, blits on this GPU; no Darling needed)
//!        mtlvk selftest-compute [metallib]  (stage 4: kernels of tests/metal/shaders/probe.metallib)
//!        mtlvk --list-gpus   (every Vulkan device as JSON: name, type, driver, the id MTLVK_DEVICE_ID takes; gpus.rs)

mod conn;
mod gpus;
mod hang;
mod memstat;
mod proto;

use metal2vulkan_runtime::Device;
use std::os::unix::net::UnixListener;

pub const DEFAULT_SOCKET: &str = "var/run/mtlvk.sock";

extern "C" fn on_usr1(_: libc::c_int) {
    conn::STATS_REQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
}

/// The device mtlvk serves every phone on, among the Vulkan devices above metal2vulkan-runtime's floor:
/// MTLVK_DEVICE_ID's (a GPU's "<deviceUUID>,<vendor>:<device>", or "cpu" for lavapipe; gpus.rs), else MTLVK_DEVICE=<n>'s
/// (the n-th, in the loader's order), else a discrete GPU, an integrated one, the first, a CPU device last.
///
/// Dropped with the new runtime (metal2vulkan-runtime 0.2, upstream's rewrite): the old runtime's x86Sim RAM 2 options.
/// - Ray tracing withheld: the new runtime enables only the floor's extensions and those the consumer names
///   (`DeviceOptions::extensions`); it never asks for VK_KHR_acceleration_structure / ray_query, so NVIDIA's
///   libnvidia-rtcore stays out without a knob (MTLVK_RAYTRACING is gone).
/// - METAL2VULKAN_QUEUES=8: the new runtime takes one VkQueue for its work and a second for presenting, not the
///   family's 16.
/// - The in-memory memo (MTLVK_MEMO_MB): the new runtime keeps the last 1,024 compiled contents by its own rule, and
///   its lowerings on disk in `pipeline_cache_dir` (MTLVK_PIPELINE_CACHE, default $XDG_CACHE_HOME/metal2vulkan-rt;
///   MTLVK_PIPELINE_CACHE_MB caps the lowerings, default the runtime's 128).
pub fn open_device() -> Result<(Device, gpus::Gpu), String> {
    use metal2vulkan_runtime::{DeviceOptions, Instance};
    gpus::prepare_loader(false);
    let instance = Instance::new(&[]).map_err(|e| format!("Vulkan instance: {e}"))?;
    let mut physical = instance.physical_devices().map_err(|e| format!("physical devices: {e}"))?;
    let mut all = gpus::describe(instance.raw().1, &physical);
    for (p, g) in physical.iter().zip(&all) {
        if let Err(e) = p.check() {
            eprintln!("mtlvk: a Vulkan device below the runtime's floor: {} ({}): {e:?}", g.name, g.kind);
        }
    }
    let want = gpus::want();
    let Some((pick, note)) = gpus::pick(&all, &want) else {
        return Err("no Vulkan device above metal2vulkan-runtime's floor".into());
    };
    if let Some(n) = note {
        eprintln!("mtlvk: {n}");
    }
    let gpu = all.swap_remove(pick);
    eprintln!("mtlvk: GPU {} ({}, {}, {}) id {} [asked: {want}]", gpu.name, gpu.kind, gpu.driver, gpu.pci(), gpu.uuid);
    let physical = physical.swap_remove(pick);
    let mut o = DeviceOptions::default();
    let dir = std::env::var_os("MTLVK_PIPELINE_CACHE").map(std::path::PathBuf::from).or_else(|| {
        let base = std::env::var_os("XDG_CACHE_HOME")
            .map(std::path::PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| std::path::Path::new(&h).join(".cache")))?;
        Some(base.join("metal2vulkan-rt"))
    });
    if dir.as_deref().is_some_and(|d| d.as_os_str() != "0") {
        o.pipeline_cache_dir = dir;
    }
    o.pipeline_cache_cap = std::env::var("MTLVK_PIPELINE_CACHE_MB").ok().and_then(|v| v.parse::<u64>().ok()).map(|mb| mb << 20);
    let device = Device::new(&physical, o).map_err(|e| format!("device: {e}"))?;
    conn::grant_indices(&device)?;
    Ok((device, gpu))
}

/// x86Sim RAM 2/8/14: every MTLVK_TRIM_EVERY seconds (default 5; 0 = never), give back what this process holds and
/// does not use: clean file pages (MTLVK_FILETRIM, memstat::FileTrim) and glibc's free arena pages (malloc_trim, after
/// a quiet tick and at least every minute).
///
/// x86Sim RAM 8: compiled contents (compute kernels and render pipelines, with their VkPipelines) no pipeline state's
/// creation looked up for MTLVK_PIPELINE_IDLE seconds (default 300; 0 = never) are forgotten from the device's map
/// (`Device::forget_idle_contents`, x86Sim's addition to the new runtime): the map keeps the last 1,024 for the
/// device's life otherwise, those of every app that ended among them. Each goes once no live state holds it.
///
/// Dropped with the old runtime: Device::trim_idle (spare command pools reset with RELEASE_RESOURCES or destroyed,
/// spare descriptor pools released). The new runtime records into at most 64 idle pools and keeps one descriptor set
/// for every pipeline; after a boot and nine apps NVIDIA's command memory (memstat nvctl-small) stayed at 21 MB, where
/// the old runtime's spares grew it to 126 MB.
fn start_trim(device: Device) {
    let every = std::env::var("MTLVK_TRIM_EVERY").ok().and_then(|v| v.parse::<f64>().ok()).unwrap_or(5.0);
    if every <= 0.0 {
        return;
    }
    let log = std::env::var_os("MTLVK_MEMSTATS").is_some();
    let file_trim_mb = std::env::var("MTLVK_FILETRIM").ok().and_then(|v| v.parse::<u64>().ok()).unwrap_or(8);
    let pipeline_idle = std::env::var("MTLVK_PIPELINE_IDLE").ok().and_then(|v| v.parse::<f64>().ok()).unwrap_or(300.0);
    let pipeline_idle = (pipeline_idle > 0.0).then(|| std::time::Duration::from_secs_f64(pipeline_idle));
    let _ = std::thread::Builder::new().name("trim".into()).spawn(move || {
        let mut last_malloc_trim = std::time::Instant::now();
        let mut ft = memstat::FileTrim::new(file_trim_mb << 10);
        loop {
            std::thread::sleep(std::time::Duration::from_secs_f64(every));
            let mut quiet = false;
            if let Some(idle) = pipeline_idle {
                let forgotten = device.forget_idle_contents(idle);
                if forgotten > 0 {
                    quiet = true;
                    if log {
                        eprintln!("mtlvk trim: {forgotten} idle compiled contents forgotten");
                    }
                }
            }
            if file_trim_mb > 0 {
                if let Some((before, after)) = ft.tick(every) {
                    quiet = true;
                    if log {
                        eprintln!("mtlvk trim: file pages {} -> {} MB", before >> 10, after >> 10);
                    }
                }
            }
            // glibc keeps freed pages of its arenas (an app's pipelines and command logs, gone with it); give back
            // the whole free pages after a quiet trim and at least every minute.
            if quiet || last_malloc_trim.elapsed().as_secs() >= 60 {
                last_malloc_trim = std::time::Instant::now();
                // SAFETY: plain libc call.
                let malloc = unsafe { libc::malloc_trim(0) != 0 };
                if log {
                    eprintln!("mtlvk trim: malloc_trim {malloc}");
                }
            }
        }
    });
}

/// Client connections being served (metalhostd's, one per phone process that renders).
static CONNS: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

struct ConnGuard;
impl ConnGuard {
    fn new() -> Self {
        CONNS.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        ConnGuard
    }
}
impl Drop for ConnGuard {
    fn drop(&mut self) {
        CONNS.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
    }
}

/// Darlingservers (one per running phone) whose environment names `sock` as their phone's mtlvk.
fn phone_users(sock: &str) -> usize {
    let want = format!("X86SIM_MTLVK_SOCKET={sock}");
    let rd = |p: &std::path::Path, f: &str| std::fs::read(p.join(f)).unwrap_or_default();
    std::fs::read_dir("/proc")
        .into_iter()
        .flatten()
        .flatten()
        .filter(|e| rd(&e.path(), "comm") == b"darlingserver\n")
        .filter(|e| rd(&e.path(), "environ").split(|b| *b == 0).any(|kv| kv == want.as_bytes()))
        .count()
}

/// x86Sim RAM 5: an mtlvk lives as long as its phones. Every stop path (launcher GUI, x86sim-aot, boot-a64.sh's
/// A64_STOP_ONLY, a phone that crashed or was restarted onto another mtlvk) used to have to find and end it, and a
/// shared one whose last phone stopped through a path that did not look (or a phone that moved to a new mtlvk) stayed
/// up for good (~250-600 MB). Now mtlvk ends itself once it has had no client connection and no running phone naming
/// its socket (a darlingserver's X86SIM_MTLVK_SOCKET) for MTLVK_IDLE_EXIT seconds (default 30; 0 = never; a boot's
/// darlingserver exists ~1 s after mtlvk, and a restart's new darlingserver names the socket before its old one is
/// gone or within seconds). The socket is unlinked first, so a boot that looks for it starts a fresh mtlvk.
fn start_idle_exit(sock: String) {
    let secs = std::env::var("MTLVK_IDLE_EXIT").ok().and_then(|v| v.parse::<f64>().ok()).unwrap_or(30.0);
    if secs <= 0.0 {
        return;
    }
    let ino = |p: &str| std::fs::metadata(p).ok().map(|m| std::os::unix::fs::MetadataExt::ino(&m));
    let mine = ino(&sock);
    let _ = std::thread::Builder::new().name("idle-exit".into()).spawn(move || {
        let mut idle_since = std::time::Instant::now();
        loop {
            std::thread::sleep(std::time::Duration::from_secs(2));
            if CONNS.load(std::sync::atomic::Ordering::SeqCst) > 0 || phone_users(&sock) > 0 {
                idle_since = std::time::Instant::now();
                continue;
            }
            if idle_since.elapsed().as_secs_f64() < secs {
                continue;
            }
            // another mtlvk may have taken the path over: leave its socket alone
            if mine.is_some() && ino(&sock) == mine {
                let _ = std::fs::remove_file(&sock);
            }
            std::thread::sleep(std::time::Duration::from_millis(300));
            if CONNS.load(std::sync::atomic::Ordering::SeqCst) == 0 {
                eprintln!("mtlvk: no phone and no connection for {secs} s: exiting (MTLVK_IDLE_EXIT)");
                std::process::exit(0);
            }
        }
    });
}

/// x86Sim RAM 8: glibc malloc for a long-lived process whose driver compiles. NVIDIA's compiler takes large
/// short-lived blocks on the threads that make pipelines, beside the pipelines' small long-lived objects; glibc
/// raises its mmap threshold to each large block freed (up to 32 MB), so later ones came from the arenas and left
/// them holed around the long-lived objects (after a gate run: 110 MB free in the arenas, malloc_trim returning
/// little). A fixed threshold (MTLVK_MMAP_THRESHOLD KiB, default 256; 0 = glibc's dynamic one) keeps large blocks
/// in their own mappings, returned at free; MTLVK_ARENA_MAX (default 4; 0 = glibc's 8 per core) bounds the arenas
/// the many short-lived threads (one per off-class compile, the pool's) spread over.
fn tune_malloc() {
    let env = |k: &str, d: i32| std::env::var(k).ok().and_then(|v| v.parse::<i32>().ok()).unwrap_or(d);
    let threshold = env("MTLVK_MMAP_THRESHOLD", 256);
    let arenas = env("MTLVK_ARENA_MAX", 4);
    // SAFETY: plain libc calls, before any other thread starts.
    unsafe {
        if threshold > 0 {
            libc::mallopt(libc::M_MMAP_THRESHOLD, threshold << 10);
        }
        if arenas > 0 {
            libc::mallopt(libc::M_ARENA_MAX, arenas);
        }
    }
}

fn main() {
    tune_malloc();
    // x86Sim Speed 7: SIGUSR1 -> per-connection object counts on stderr (next request)
    // SAFETY: the handler only bumps an atomic.
    unsafe { libc::signal(libc::SIGUSR1, on_usr1 as extern "C" fn(libc::c_int) as libc::sighandler_t) };
    let arg = std::env::args().nth(1);
    if matches!(arg.as_deref(), Some("--list-gpus" | "list-gpus")) {
        std::process::exit(match gpus::list() {
            Ok(()) => 0,
            Err(e) => {
                eprintln!("mtlvk: {e}");
                1
            }
        });
    }
    let (device, gpu) = match open_device() {
        Ok(d) => d,
        Err(e) => {
            eprintln!("mtlvk: no Vulkan device: {e}");
            std::process::exit(1);
        }
    };
    let (name, registry) = conn::device_identity(&device);
    eprintln!("mtlvk: device {name} (registryID {registry:#x})");
    if arg.as_deref() == Some("selftest-compute") {
        let path = std::env::args().nth(2).unwrap_or_else(|| "tests/metal/shaders/probe.metallib".into());
        let data = std::fs::read(&path).unwrap_or_else(|e| {
            eprintln!("mtlvk: {path}: {e}");
            std::process::exit(1);
        });
        std::process::exit(match conn::selftest_compute(&device, &data) {
            Ok(()) => {
                println!("mtlvk selftest-compute: PASS");
                0
            }
            Err(e) => {
                println!("mtlvk selftest-compute: FAIL: {e}");
                1
            }
        });
    }
    if arg.as_deref() == Some("selftest") {
        std::process::exit(match conn::selftest(&device) {
            Ok(()) => {
                println!("mtlvk selftest: PASS");
                0
            }
            Err(e) => {
                println!("mtlvk selftest: FAIL: {e}");
                1
            }
        });
    }
    hang::start(device.clone());
    memstat::start(device.clone());
    start_trim(device.clone());
    let path = arg.unwrap_or_else(|| DEFAULT_SOCKET.to_string());
    let _ = std::fs::remove_file(&path);
    if let Some(dir) = std::path::Path::new(&path).parent() {
        let _ = std::fs::create_dir_all(dir);
    }
    gpus::record(&path, &gpu);
    let listener = UnixListener::bind(&path).unwrap_or_else(|e| {
        eprintln!("mtlvk: bind {path}: {e}");
        std::process::exit(1);
    });
    eprintln!("mtlvk: listening on {path}");
    start_idle_exit(path.clone());
    for (n, stream) in listener.incoming().enumerate() {
        match stream {
            Ok(s) => {
                let device = device.clone();
                // counted until the thread ends, a panic included (the guard drops on unwind or if spawn fails)
                let guard = ConnGuard::new();
                std::thread::Builder::new()
                    .name(format!("conn{n}"))
                    .spawn(move || {
                        let _g = guard;
                        conn::serve(n, device, s)
                    })
                    .ok();
            }
            Err(e) => eprintln!("mtlvk: accept: {e}"),
        }
    }
}
