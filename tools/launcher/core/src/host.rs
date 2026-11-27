//! Host side: iOS versions (downloaded / in Apple's catalogue, fetched with cli/x86sim runtime), disk use of the
//! scratch dir and the caches, hub-wide settings.
use crate::aot::{repo_root, scratch};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

#[derive(Debug, Clone, Serialize)]
pub struct Runtime {
    /// runtimes/ dir name
    pub dir: String,
    /// Platforms 1: "ios", "tvos" or "watchos" (the dir's prefix)
    pub platform: String,
    pub version: String,
    pub build: String,
    pub root: PathBuf,
    /// dyld cache on disk: boots
    pub present: bool,
    /// a dir exists but is incomplete (data loss / interrupted download)
    pub partial: bool,
    pub jc: PathBuf,
    /// Models 2: model ids this runtime is limited to (empty: any), see sim::runtime_restricted_to
    pub restricted_to: Vec<String>,
    /// model ids its profile lists as unsupported (iOS 27.2 24B8117: the iPhone Duo, which has a build of its own)
    pub unsupported: Vec<String>,
}

impl Runtime {
    /// "iOS 27.2", "tvOS 27.2", "watchOS 27.2"
    pub fn label(&self) -> String {
        format!("{} {}", crate::sim::platform_name(&self.platform), self.version)
    }
}

pub fn runtimes() -> Vec<Runtime> {
    let mut v: Vec<Runtime> = std::fs::read_dir(repo_root().join("runtimes"))
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| {
            let dir = e.file_name().to_string_lossy().into_owned();
            let (platform, version, build) = crate::sim::parse_runtime_dir(&dir)?;
            let root = e.path().join("RuntimeRoot");
            let present = crate::dyldcache::Cache::cache_dir(&root).join(crate::dyldcache::CACHE_NAME).exists();
            Some(Runtime { jc: crate::sim::jc_for(&root), platform: platform.to_string(), version, build, restricted_to: crate::sim::runtime_restricted_to(&root), unsupported: crate::sim::runtime_unsupported(&root), dir, root, present, partial: !present })
        })
        .collect();
    // within a version a runtime limited to some models (the iPhone Duo's 27.2 build) after the general one
    // Platforms 1: iOS, then tvOS, then watchOS
    let rank = |p: &str| crate::sim::PLATFORMS.iter().position(|x| *x == p).unwrap_or(0);
    v.sort_by(|a, b| rank(&a.platform).cmp(&rank(&b.platform)).then(a.version.cmp(&b.version)).then(a.restricted_to.is_empty().cmp(&b.restricted_to.is_empty()).reverse()).then(a.build.cmp(&b.build)));
    v
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Catalogue {
    pub version: String,
    pub build: String,
    pub name: String,
    pub gb: f64,
    /// Platforms 1: "ios", "tvos" or "watchos" (from the name: "tvOS 27.2 Simulator Runtime"); absent in older caches
    #[serde(default = "ios")]
    pub platform: String,
    /// a beta or release candidate (its name says so)
    #[serde(default)]
    pub beta: bool,
    /// a build for particular devices: the general build of the same release it stands beside (Apple's
    /// sdkToSimulatorMappings, runtime-fetch.py alt_of), as iOS 27.2 24B91016s (iPhone Duo) beside 24B8117; empty for
    /// a general build. Which devices it is for is in the runtime's own profile, so known once downloaded (or from the
    /// general build's unsupported list, when that one is here).
    #[serde(default)]
    pub alt_of: String,
}

fn ios() -> String {
    "ios".into()
}

impl Catalogue {
    /// "iOS 27.2", "iOS 27.3 beta 2", "iOS 27.2 RC"
    pub fn title(&self) -> String {
        let short = self.name.trim_end_matches(" Simulator Runtime").trim().replace("Release Candidate", "RC");
        if !short.is_empty() {
            short
        } else if self.version.is_empty() {
            self.build.clone()
        } else {
            format!("{} {}", crate::sim::platform_name(&self.platform), self.version)
        }
    }
}

/// Apple's catalogue (network; `x86sim runtime list all json`: every platform), cached in scratch
pub fn catalogue(refresh: bool) -> Vec<Catalogue> {
    // a new file name for each new shape, so an older cache (iOS only; no beta / alt_of) is not taken for this one
    let cache = scratch().join("launcher-runtimes-all-2.json");
    if !refresh {
        if let Some(v) = std::fs::read(&cache).ok().and_then(|b| serde_json::from_slice(&b).ok()) {
            return v;
        }
    }
    let out = Command::new(repo_root().join("cli/x86sim")).args(["runtime", "list", "all", "json"]).stdin(Stdio::null()).output();
    let v: Vec<Catalogue> = out.ok().and_then(|o| serde_json::from_slice(&o.stdout).ok()).unwrap_or_default();
    if !v.is_empty() {
        let _ = crate::aot::write_json(&cache, &v);
    }
    v
}

/// The (version, build) to download for a model no installed runtime takes: the build in Apple's list beside an
/// installed one that refuses the model (iOS 27.2 24B91016s for the iPhone Duo, beside 24B8117, which refuses it), else
/// the platform's default build when that is not here yet. None: nothing known to fetch (Apple's list not loaded).
/// Offering the default build again for a model it refuses downloaded it over and over (issue #64).
pub fn build_for_model(platform: &str, model_id: &str, have: &[Runtime], cat: &[Catalogue]) -> Option<(String, String)> {
    let mine = |r: &&Runtime| r.platform == platform;
    let installed = |b: &str| have.iter().any(|r| r.build == b && r.present);
    let refuses = |r: &&Runtime| r.unsupported.iter().any(|m| m == model_id) || (!r.restricted_to.is_empty() && !r.restricted_to.iter().any(|m| m == model_id));
    // which devices a build beside a general one is for is only in its own profile (known once downloaded): the
    // general build's unsupported list is what says the model needs one of them
    let mut alts: Vec<&Catalogue> = have
        .iter()
        .filter(mine)
        .filter(|r| r.present && r.restricted_to.is_empty() && refuses(r))
        .flat_map(|r| cat.iter().filter(move |c| c.platform == platform && c.alt_of == r.build))
        .filter(|c| !installed(&c.build))
        .collect();
    alts.sort_by_key(|c| c.beta);
    if let Some(c) = alts.first() {
        return Some((c.version.clone(), c.build.clone()));
    }
    let (ver, build) = crate::sim::platform_default_build(platform);
    (!installed(build)).then(|| (ver.to_string(), build.to_string()))
}

pub fn fetch_log(build: &str) -> PathBuf {
    scratch().join(format!("launcher-fetch-{build}.log"))
}

/// Downloads a runtime (x86sim runtime fetch BUILD) in the background; progress in fetch_log
pub fn fetch(build: &str) -> Result<u32> {
    let log = std::fs::File::create(fetch_log(build))?;
    let c = Command::new("setsid").arg(repo_root().join("cli/x86sim")).args(["runtime", "fetch", build]).current_dir(repo_root()).stdin(Stdio::null()).stdout(log.try_clone()?).stderr(log).spawn()?;
    Ok(c.id())
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct Disk {
    pub total_gb: f64,
    pub free_gb: f64,
}

pub fn disk(p: &Path) -> Disk {
    let c = std::ffi::CString::new(p.to_string_lossy().as_bytes()).unwrap_or_default();
    let mut st: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(c.as_ptr(), &mut st) } != 0 {
        return Disk::default();
    }
    let bs = st.f_frsize as f64;
    Disk { total_gb: st.f_blocks as f64 * bs / 1e9, free_gb: st.f_bavail as f64 * bs / 1e9 }
}

/// Bytes under a dir (walk; symlinks not followed)
pub fn dir_size(p: &Path) -> u64 {
    let mut total = 0;
    let mut work = vec![p.to_path_buf()];
    while let Some(d) = work.pop() {
        for e in std::fs::read_dir(&d).into_iter().flatten().flatten() {
            let Ok(md) = e.metadata() else { continue };
            if md.is_dir() {
                work.push(e.path());
            } else if md.is_file() {
                total += md.len();
            }
        }
    }
    total
}

pub fn mtlvk_pids() -> Vec<u32> {
    std::fs::read_dir("/proc")
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| e.file_name().to_string_lossy().parse::<u32>().ok())
        .filter(|p| std::fs::read_to_string(format!("/proc/{p}/comm")).map(|c| c.trim() == "mtlvk").unwrap_or(false))
        .collect()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct HubSettings {
    /// show live thumbnails on the home view
    pub thumbnails: bool,
    /// open the phone's view when it starts
    pub open_on_start: bool,
    /// home view card width
    pub card_w: f32,
    /// order of the phones on the home view: "name" | "newest" | "oldest" | "model" | "ios"
    pub sort: String,
    /// look for a newer x86Sim release (AppImage only) at start and every few hours
    pub check_updates: bool,
    /// release channel: "" (the running version's: pre-release builds follow pre-releases) | "stable" | "pre"
    pub channel: String,
    /// "system" (the Omarchy theme, else the desktop's light or dark preference) | "dark" | "light"
    pub appearance: String,
    /// keep every version's pre-translated image up to date on its own (the launcher's automatic runs); off: only
    /// when the user starts a run (issue #63)
    pub aot_auto: bool,
}

impl Default for HubSettings {
    fn default() -> Self {
        HubSettings { thumbnails: true, open_on_start: false, card_w: 250.0, sort: "name".into(), check_updates: true, channel: String::new(), appearance: "system".into(), aot_auto: true }
    }
}

pub fn hub_path() -> PathBuf {
    scratch().join("launcher-hub.json")
}

pub fn load_hub() -> HubSettings {
    std::fs::read(hub_path()).ok().and_then(|b| serde_json::from_slice(&b).ok()).unwrap_or_default()
}

pub fn save_hub(s: &HubSettings) -> Result<()> {
    crate::aot::write_json(&hub_path(), s)
}

// ---- downloads ----

/// A running download (x86sim runtime fetch BUILD): found by its command line, so one started before the hub opened
/// (or from a terminal) shows too.
#[derive(Debug, Clone, Default, Serialize)]
pub struct Fetch {
    pub build: String,
    /// the process group leader (setsid by `fetch`), or the runtime-fetch.py process
    pub pid: u32,
    /// "starting" | "downloading" | "decrypting" | "unpacking"
    pub phase: String,
    pub pct: Option<f32>,
    pub done_bytes: u64,
    pub total_bytes: u64,
    /// bytes per second (curl's current speed)
    pub speed: u64,
    pub eta_s: Option<u64>,
}

fn proc_read(pid: u32, f: &str) -> String {
    std::fs::read_to_string(format!("/proc/{pid}/{f}")).unwrap_or_default()
}

/// "7900M" -> bytes
fn curl_size(s: &str) -> Option<u64> {
    let s = s.trim();
    let (n, mul) = match s.chars().last()? {
        'k' => (&s[..s.len() - 1], 1u64 << 10),
        'M' => (&s[..s.len() - 1], 1 << 20),
        'G' => (&s[..s.len() - 1], 1 << 30),
        'T' => (&s[..s.len() - 1], 1 << 40),
        _ => (s, 1),
    };
    n.parse::<f64>().ok().map(|v| (v * mul as f64) as u64)
}

/// "1:49:00" / "--:--:--" -> seconds
fn curl_time(s: &str) -> Option<u64> {
    let p: Vec<u64> = s.split(':').map(|x| x.parse().ok()).collect::<Option<_>>()?;
    Some(p.iter().fold(0, |a, v| a * 60 + v))
}

/// Downloads in progress (runtime-fetch.py fetch BUILD processes), with progress from curl's meter in the log.
pub fn fetches() -> Vec<Fetch> {
    let mut out: Vec<Fetch> = vec![];
    let mut groups: std::collections::HashMap<u32, Vec<String>> = std::collections::HashMap::new(); // pgid -> comms
    let mut found: Vec<(u32, u32, String)> = vec![]; // pid, pgid, build
    for e in std::fs::read_dir("/proc").into_iter().flatten().flatten() {
        let Ok(pid) = e.file_name().to_string_lossy().parse::<u32>() else { continue };
        let stat = proc_read(pid, "stat");
        let Some(rest) = stat.rsplit(')').next() else { continue };
        let pgid: u32 = rest.split_whitespace().nth(2).and_then(|x| x.parse().ok()).unwrap_or(0);
        let comm = proc_read(pid, "comm").trim().to_string();
        groups.entry(pgid).or_default().push(comm.clone());
        if comm.starts_with("python") {
            let args: Vec<String> = proc_read(pid, "cmdline").split('\0').map(String::from).collect();
            if let Some(i) = args.iter().position(|a| a.ends_with("arm64/runtime-fetch.py")) {
                if args.get(i + 1).map(String::as_str) == Some("fetch") {
                    if let Some(b) = args.get(i + 2) {
                        found.push((pid, pgid, b.clone()));
                    }
                }
            }
        }
    }
    for (pid, pgid, build) in found {
        let comms = groups.get(&pgid).cloned().unwrap_or_default();
        let has = |c: &str| comms.iter().any(|x| x == c);
        let phase = if has("curl") {
            "downloading"
        } else if has("ipsw") {
            "decrypting"
        } else if has("7z") || comms.iter().filter(|c| c.starts_with("python")).count() > 1 {
            "unpacking"
        } else {
            "starting"
        };
        let mut f = Fetch { build: build.clone(), pid: if pgid > 1 { pgid } else { pid }, phase: phase.into(), ..Default::default() };
        if phase == "downloading" {
            // curl's meter: the last \r-separated record of the log
            let log = std::fs::read(fetch_log(&build)).unwrap_or_default();
            let tail = String::from_utf8_lossy(&log[log.len().saturating_sub(4096)..]).into_owned();
            // a resumed download's meter counts only the rest
            let resumed: u64 = String::from_utf8_lossy(&log[..log.len().min(16384)])
                .split("Resuming transfer from byte position ")
                .nth(1)
                .and_then(|r| r.split_whitespace().next())
                .and_then(|n| n.parse().ok())
                .unwrap_or(0);
            if let Some(rec) = tail.rsplit(['\r', '\n']).find(|r| r.split_whitespace().next().is_some_and(|w| w.parse::<u32>().is_ok())) {
                let w: Vec<&str> = rec.split_whitespace().collect();
                if w.len() >= 12 {
                    f.total_bytes = curl_size(w[1]).unwrap_or(0) + resumed;
                    f.done_bytes = curl_size(w[3]).unwrap_or(0) + resumed;
                    f.pct = (f.total_bytes > 0).then(|| f.done_bytes as f32 / f.total_bytes as f32 * 100.0);
                    f.speed = curl_size(w[11]).unwrap_or(0);
                    f.eta_s = curl_time(w[10]);
                }
            }
        }
        out.push(f);
    }
    out
}

/// Stops a download (its whole process group). What was downloaded stays: Download again resumes it.
pub fn cancel_fetch(f: &Fetch) {
    unsafe {
        if libc::getpgid(f.pid as i32) == f.pid as i32 {
            libc::kill(-(f.pid as i32), libc::SIGTERM);
        } else {
            libc::kill(f.pid as i32, libc::SIGTERM);
        }
    }
}

/// A download that stopped part way (no RuntimeRoot yet): runtimes/<dir>/download/runtime.aar and its size
pub fn partial_download(r: &Runtime) -> Option<u64> {
    if r.present {
        return None;
    }
    let dir = repo_root().join("runtimes").join(&r.dir);
    if dir.join("RuntimeRoot").symlink_metadata().is_ok() {
        return None;
    }
    std::fs::metadata(dir.join("download/runtime.aar")).ok().map(|m| m.len())
}

/// Removes a stopped download: only a runtimes/ dir that never got a RuntimeRoot (the files the download made).
pub fn discard_download(r: &Runtime) -> Result<()> {
    let dir = repo_root().join("runtimes").join(&r.dir);
    anyhow::ensure!(!r.present && dir.join("RuntimeRoot").symlink_metadata().is_err(), "{} is installed, not a stopped download", r.dir);
    anyhow::ensure!(!fetches().iter().any(|f| f.build == r.build), "it is still downloading");
    for e in std::fs::read_dir(&dir)?.flatten() {
        let n = e.file_name().to_string_lossy().into_owned();
        anyhow::ensure!(matches!(n.as_str(), "download" | "decrypted" | "bundle" | "extracted"), "{} has other files ({n}); left alone", dir.display());
    }
    std::fs::remove_dir_all(&dir)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rt(build: &str, restricted_to: &[&str], unsupported: &[&str]) -> Runtime {
        Runtime { dir: format!("ios-27.2-{build}-arm64"), platform: "ios".into(), version: "27.2".into(), build: build.into(), root: PathBuf::new(), present: true, partial: false, jc: PathBuf::new(), restricted_to: restricted_to.iter().map(|s| s.to_string()).collect(), unsupported: unsupported.iter().map(|s| s.to_string()).collect() }
    }

    fn cat(build: &str, alt_of: &str) -> Catalogue {
        Catalogue { version: "27.2".into(), build: build.into(), name: String::new(), gb: 8.0, platform: "ios".into(), beta: false, alt_of: alt_of.into() }
    }

    // issue #64: with only 24B8117 here (it refuses the Duo), the Duo's download is its own build, not 24B8117 again
    #[test]
    fn duo_gets_its_own_build() {
        let have = [rt("24B8117", &[], &["iPhone19,4"])];
        let c = [cat("24B8117", ""), cat("24B91016s", "24B8117")];
        assert_eq!(build_for_model("ios", "iPhone19,4", &have, &c), Some(("27.2".into(), "24B91016s".into())));
        // any other iPhone fits 24B8117: nothing to fetch for it
        assert_eq!(build_for_model("ios", "iPhone18,1", &have, &c), None);
    }

    #[test]
    fn nothing_installed_offers_the_default() {
        assert_eq!(build_for_model("ios", "iPhone19,4", &[], &[cat("24B8117", ""), cat("24B91016s", "24B8117")]), Some(("27.2".into(), "24B8117".into())));
    }

    // no model on any platform loops: from any set of installed builds, downloading what the dialog offers until the
    // model fits never offers the same build twice (an offered build is never one already here) and ends on one that
    // takes it, or on nothing to offer
    #[test]
    fn no_model_loops() {
        // (platform, build, alt_of, restricted_to, unsupported): the real iOS 27.2 pair, the other platforms' defaults,
        // and made-up builds for some devices on them (as Apple ships for new hardware)
        let all: &[(&str, &str, &str, &[&str], &[&str])] = &[
            ("ios", "24B8117", "", &[], &["iPhone19,4"]),
            ("ios", "24B91016s", "24B8117", &["iPhone19,4"], &[]),
            ("tvos", "24K150", "", &[], &["AppleTV18,1"]),
            ("tvos", "24K9000", "24K150", &["AppleTV18,1"], &[]),
            ("watchos", "24S118", "", &[], &["Watch8,1", "Watch8,4"]),
            ("watchos", "24S9001", "24S118", &["Watch8,4"], &[]),
            ("watchos", "24S9002", "24S118", &["Watch8,1"], &[]),
            ("xros", "24N120", "", &[], &[]),
        ];
        let models: &[(&str, &str)] = &[("ios", "iPhone19,4"), ("ios", "iPhone18,1"), ("ios", "iPad17,4"), ("tvos", "AppleTV18,1"), ("tvos", "AppleTV14,1"), ("watchos", "Watch8,1"), ("watchos", "Watch8,4"), ("watchos", "Watch7,18"), ("xros", "RealityDevice14,1")];
        let cat: Vec<Catalogue> = all.iter().map(|a| Catalogue { platform: a.0.into(), ..cat(a.1, a.2) }).collect();
        let mk = |a: &(&str, &str, &str, &[&str], &[&str])| Runtime { platform: a.0.into(), ..rt(a.1, a.3, a.4) };
        for &(plat, mid) in models {
            let mine: Vec<_> = all.iter().filter(|a| a.0 == plat).collect();
            for mask in 0..(1u32 << mine.len()) {
                let mut have: Vec<Runtime> = mine.iter().enumerate().filter(|(i, _)| mask & (1 << i) != 0).map(|(_, a)| mk(a)).collect();
                let fits = |h: &[Runtime]| h.iter().any(|r| (r.restricted_to.is_empty() || r.restricted_to.iter().any(|m| m == mid)) && !r.unsupported.iter().any(|m| m == mid));
                let mut offered = vec![];
                while !fits(&have) {
                    let Some((_, b)) = build_for_model(plat, mid, &have, &cat) else { break };
                    assert!(!offered.contains(&b) && !have.iter().any(|r| r.build == b), "{mid} from {mask:b}: {b} offered again ({offered:?})");
                    offered.push(b.clone());
                    have.push(mk(all.iter().find(|a| a.1 == b).unwrap()));
                }
                assert!(fits(&have), "{mid} from {mask:b}: stuck after {offered:?}");
            }
        }
    }

    #[test]
    fn no_catalogue_no_refetch_of_the_default() {
        assert_eq!(build_for_model("ios", "iPhone19,4", &[rt("24B8117", &[], &["iPhone19,4"])], &[]), None);
    }
}
