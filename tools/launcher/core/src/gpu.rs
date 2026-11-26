//! The GPU a device renders on (BootSettings::gpu, per device; applies at the next start).
//!
//! The setting: "auto" (mtlvk's own pick: a discrete GPU, else an integrated one), "cpu" (a software Vulkan device,
//! lavapipe: everything on the CPU, no GPU at all), or a GPU's id as `mtlvk --list-gpus` gives it:
//! "<deviceUUID>,<vendor>:<device>" (the UUID stays the same across reboots and driver updates; vendor:device takes
//! over when it changed, e.g. a card moved to another slot). The loader's index is never stored: its order can change.
//!
//! The launcher passes the setting to boot-a64.sh as MTLVK_DEVICE_ID; each choice gets its own mtlvk (its socket
//! `<state>/mtlvk<key>.sock`), and mtlvk writes the device it chose beside its socket (`<socket minus .sock>.gpu`),
//! which is how a start finds a helper on the same GPU to share and how a running phone's GPU is shown.

use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// A Vulkan device, as `mtlvk --list-gpus` lists it
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Gpu {
    /// in the loader's order (changes between boots; never stored)
    pub index: usize,
    /// the setting's form: "<uuid>,<vendor>:<device>"
    pub id: String,
    pub uuid: String,
    pub pci: String,
    pub name: String,
    /// discrete | integrated | virtual | cpu | other
    #[serde(rename = "type")]
    pub kind: String,
    pub driver: String,
    /// above the Metal translator's floor (mtlvk can serve on it)
    pub usable: bool,
    /// what "auto" picks
    pub auto: bool,
}

impl Gpu {
    /// "NVIDIA GeForce RTX 5090 · discrete"; a CPU device as "CPU (llvmpipe)"
    pub fn label(&self) -> String {
        if self.kind == "cpu" {
            return format!("CPU ({})", short_name(&self.name));
        }
        format!("{} · {}", short_name(&self.name), self.kind)
    }
}

/// "AMD Ryzen 7 9800X3D 8-Core Processor (RADV RAPHAEL_MENDOCINO)" -> "AMD Radeon (RADV RAPHAEL_MENDOCINO)",
/// "llvmpipe (LLVM 23.1.3, 256 bits)" -> "llvmpipe": RADV names an APU's GPU after the CPU
pub fn short_name(n: &str) -> String {
    if let Some(i) = n.find("(RADV ") {
        if !n.to_lowercase().contains("radeon") {
            return format!("AMD Radeon {}", &n[i..]);
        }
    }
    if n.starts_with("llvmpipe") {
        return "llvmpipe".into();
    }
    n.to_string()
}

/// The device a running mtlvk serves on (its `.gpu` record, gpus.rs `record`)
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct HelperGpu {
    /// what it was asked for (MTLVK_DEVICE_ID / index:<n> / auto)
    pub want: String,
    pub id: String,
    pub uuid: String,
    pub pci: String,
    pub name: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub driver: String,
}

/// A GPU in a few words, for a device card: "RTX 5090", "Radeon", "CPU"
pub fn compact(name: &str, kind: &str) -> String {
    if kind == "cpu" {
        return "CPU".into();
    }
    let n = short_name(name);
    if n.starts_with("AMD Radeon (RADV") {
        return "Radeon".into();
    }
    n.trim_start_matches("NVIDIA ").trim_start_matches("GeForce ").trim_start_matches("AMD ").trim_start_matches("Intel(R) ").to_string()
}

impl HelperGpu {
    pub fn compact(&self) -> String {
        compact(&self.name, &self.kind)
    }
    pub fn label(&self) -> String {
        Gpu { index: 0, id: self.id.clone(), uuid: self.uuid.clone(), pci: self.pci.clone(), name: self.name.clone(), kind: self.kind.clone(), driver: self.driver.clone(), usable: true, auto: false }.label()
    }
}

pub fn mtlvk_bin() -> PathBuf {
    std::env::var_os("X86SIM_MTLVK").or_else(|| std::env::var_os("MTLVK")).map(PathBuf::from).unwrap_or_else(|| crate::aot::repo_root().join("linux/mtlvk/target/release/mtlvk"))
}

/// The host's Vulkan devices (`mtlvk --list-gpus`, kept for a minute: the list is the same until a driver changes)
pub fn list() -> Result<Vec<Gpu>> {
    static CACHE: Mutex<Option<(Instant, Vec<Gpu>)>> = Mutex::new(None);
    let mut c = CACHE.lock().unwrap_or_else(|e| e.into_inner());
    if let Some((t, l)) = c.as_ref() {
        if t.elapsed() < Duration::from_secs(60) {
            return Ok(l.clone());
        }
    }
    let bin = mtlvk_bin();
    let out = std::process::Command::new(&bin).arg("--list-gpus").stdin(std::process::Stdio::null()).stderr(std::process::Stdio::piped()).output().map_err(|e| anyhow::anyhow!("{}: {e}", bin.display()))?;
    if !out.status.success() {
        bail!("mtlvk --list-gpus: {}", String::from_utf8_lossy(&out.stderr).trim());
    }
    let l: Vec<Gpu> = serde_json::from_slice(&out.stdout)?;
    *c = Some((Instant::now(), l.clone()));
    Ok(l)
}

/// The usable device a setting names, by mtlvk's own rule (gpus.rs `pick`): None for auto with no usable device, or a
/// name that matches none (mtlvk then takes auto's)
pub fn resolve<'a>(want: &str, l: &'a [Gpu]) -> Option<&'a Gpu> {
    let ok = || l.iter().filter(|g| g.usable);
    let auto = || ok().find(|g| g.auto);
    match want {
        "" | "auto" => auto(),
        "cpu" => ok().find(|g| g.kind == "cpu"),
        w => {
            let norm = |s: &str| s.trim().to_ascii_lowercase().replace('-', "");
            w.split(',').map(norm).filter(|w| !w.is_empty()).find_map(|w| ok().find(|g| if w.contains(':') { g.pci == w } else { norm(&g.uuid) == w })).or_else(auto)
        }
    }
}

/// Whether a running helper serves the GPU a setting wants: the same device (auto and a GPU that auto picks share);
/// with no list, the same setting. A helper of an older mtlvk (no record) serves auto.
pub fn serves(helper: Option<&HelperGpu>, want: &str, l: Option<&[Gpu]>) -> bool {
    let want = if want.is_empty() { "auto" } else { want };
    let Some(h) = helper else { return want == "auto" };
    match l.and_then(|l| resolve(want, l)) {
        Some(g) => g.uuid == h.uuid,
        None => h.want == want || (want == "cpu" && h.kind == "cpu"),
    }
}

/// A setting from what a person typed: auto, cpu, an index of the list, an id or UUID, or part of a name ("nvidia",
/// "amd", "5090", "radeon")
pub fn parse(input: &str, l: &[Gpu]) -> Result<String> {
    let s = input.trim();
    let lc = s.to_lowercase();
    match lc.as_str() {
        "auto" | "default" => return Ok("auto".into()),
        "cpu" | "none" | "no-gpu" | "nogpu" | "lavapipe" | "llvmpipe" | "software" => {
            if !l.iter().any(|g| g.usable && g.kind == "cpu") {
                bail!("no CPU Vulkan device: install lavapipe (Arch: vulkan-swrast, Debian/Ubuntu: mesa-vulkan-drivers, Fedora: mesa-vulkan-drivers), or put its lvp_icd.json in ~/.local/share/x86sim/lavapipe/");
            }
            return Ok("cpu".into());
        }
        _ => {}
    }
    let usable: Vec<&Gpu> = l.iter().filter(|g| g.usable).collect();
    let id_of = |g: &Gpu| if g.kind == "cpu" { "cpu".to_string() } else { g.id.clone() };
    if let Ok(n) = lc.parse::<usize>() {
        if let Some(g) = l.iter().find(|g| g.index == n && g.usable) {
            return Ok(id_of(g));
        }
    }
    let norm = |s: &str| s.to_ascii_lowercase().replace('-', "");
    if let Some(g) = usable.iter().find(|g| norm(&g.id) == norm(s) || norm(&g.uuid) == norm(s.split(',').next().unwrap_or("")) || g.pci == lc) {
        return Ok(id_of(g));
    }
    let hits: Vec<&&Gpu> = usable.iter().filter(|g| g.name.to_lowercase().contains(&lc) || g.label().to_lowercase().contains(&lc) || g.driver.to_lowercase().contains(&lc) || vendor(g).contains(&lc)).collect();
    match hits.as_slice() {
        [g] => Ok(id_of(g)),
        [] => bail!("no GPU matches {s:?}: auto, cpu, or one of {}", usable.iter().map(|g| g.label()).collect::<Vec<_>>().join(", ")),
        m => bail!("{s:?} matches {}: name one", m.iter().map(|g| g.label()).collect::<Vec<_>>().join(", ")),
    }
}

fn vendor(g: &Gpu) -> &'static str {
    match g.pci.split(':').next().unwrap_or("") {
        "10de" => "nvidia",
        "1002" => "amd radeon",
        "8086" => "intel",
        _ => "",
    }
}

/// What the setting means, for a picker or a list: "Auto", "CPU (llvmpipe)", "NVIDIA GeForce RTX 5090 · discrete",
/// or the stored id when the GPU is not there now
pub fn setting_label(want: &str, l: &[Gpu]) -> String {
    match want {
        "" | "auto" => "Auto".into(),
        "cpu" => l.iter().find(|g| g.kind == "cpu").map(|g| g.label()).unwrap_or_else(|| "CPU".into()),
        w => {
            let norm = |s: &str| s.trim().to_ascii_lowercase().replace('-', "");
            let first = norm(w.split(',').next().unwrap_or(""));
            let pci = w.split(',').nth(1).unwrap_or("").trim().to_ascii_lowercase();
            l.iter().find(|g| norm(&g.uuid) == first).or_else(|| l.iter().find(|g| !pci.is_empty() && g.pci == pci)).map(|g| g.label()).unwrap_or_else(|| format!("{w} (not found)"))
        }
    }
}

/// The choices a picker offers: (setting, label, usable) — Auto, every usable GPU, then the CPU device
pub fn choices(l: &[Gpu]) -> Vec<(String, String)> {
    let auto = l.iter().find(|g| g.auto).map(|g| format!("Auto ({})", short_name(&g.name))).unwrap_or_else(|| "Auto".into());
    let mut v = vec![("auto".to_string(), auto)];
    v.extend(l.iter().filter(|g| g.usable && g.kind != "cpu").map(|g| (g.id.clone(), g.label())));
    if let Some(g) = l.iter().find(|g| g.usable && g.kind == "cpu") {
        v.push(("cpu".into(), g.label()));
    }
    v
}

/// A running mtlvk's record (`<sock minus .sock>.gpu`)
pub fn helper_of_socket(sock: &Path) -> Option<HelperGpu> {
    let b = std::fs::read(sock.with_extension("gpu")).ok()?;
    serde_json::from_slice(&b).ok()
}

/// How a running mtlvk's guest buffers reach the GPU (its `<socket>.state`, mtlvk bufstate.rs): shared without a copy
/// (by address, or as a udmabuf where the driver refuses addresses: AMD / RADV) or mirrored, copied each time they change
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct GpuBuffers {
    /// "unused" (every import took the address), "on", "off: …" or "unavailable: …"
    pub udmabuf: String,
    pub direct: u64,
    pub udmabuf_buffers: u64,
    pub mirrored: u64,
    /// why the first mirrored buffer was not imported
    pub mirror_reason: Option<String>,
}

impl GpuBuffers {
    /// One line for a status row: "Shared", "Shared (udmabuf)", "Copied (udmabuf unavailable: …)", …
    pub fn summary(&self) -> String {
        if self.mirrored == 0 {
            return if self.udmabuf_buffers > 0 { "Shared (udmabuf)".into() } else { "Shared".into() };
        }
        let why = if let Some(u) = self.udmabuf.strip_prefix("unavailable: ").or_else(|| self.udmabuf.strip_prefix("off: ")) {
            format!("udmabuf {}: {u}", if self.udmabuf.starts_with("off") { "off" } else { "unavailable" })
        } else {
            self.mirror_reason.clone().unwrap_or_default()
        };
        let some = self.direct + self.udmabuf_buffers > 0;
        format!("{} ({})", if some { "Partly copied" } else { "Copied" }, why)
    }

    /// Whether buffers are being copied (the slow path)
    pub fn copying(&self) -> bool {
        self.mirrored > 0
    }
}

/// The buffer state of the mtlvk at `sock` (None: no such mtlvk, or one older than the state file)
pub fn buffers_of_socket(sock: &Path) -> Option<GpuBuffers> {
    let b = std::fs::read(format!("{}.state", sock.display())).ok()?;
    serde_json::from_slice(&b).ok()
}

/// Every mtlvk a boot started in `state_dir` (one per GPU choice): (pid, socket) of the live ones
pub fn helpers_in(state_dir: &Path) -> Vec<(u32, PathBuf)> {
    let mut v = vec![];
    let Ok(rd) = std::fs::read_dir(state_dir) else { return v };
    for e in rd.flatten() {
        let n = e.file_name().to_string_lossy().into_owned();
        if !(n.starts_with("mtlvk") && n.ends_with(".pid")) {
            continue;
        }
        let Ok(pid) = std::fs::read_to_string(e.path()).unwrap_or_default().trim().parse::<u32>() else { continue };
        let sock = e.path().with_extension("sock");
        if std::fs::read_to_string(format!("/proc/{pid}/comm")).is_ok_and(|c| c.trim() == "mtlvk") && sock.exists() {
            v.push((pid, sock));
        }
    }
    v.sort();
    v
}

/// Every pidfile of an mtlvk in `state_dir` (live or not)
pub fn pidfiles_in(state_dir: &Path) -> Vec<PathBuf> {
    let Ok(rd) = std::fs::read_dir(state_dir) else { return vec![] };
    let mut v: Vec<PathBuf> = rd.flatten().map(|e| e.path()).filter(|p| p.file_name().is_some_and(|n| { let n = n.to_string_lossy(); n.starts_with("mtlvk") && n.ends_with(".pid") })).collect();
    v.sort();
    v
}

/// Sets a device's GPU (applies at its next start); `input` as `parse` takes it. Returns the setting stored.
pub fn set(dir: &Path, input: &str) -> Result<String> {
    let l = list()?;
    let v = parse(input, &l)?;
    let mut s = crate::instance::load_settings(dir);
    if s.gpu != v {
        s.gpu = v.clone();
        crate::instance::save_settings(dir, &s)?;
    }
    Ok(v)
}

#[cfg(test)]
mod tests {
    use super::*;
    fn l() -> Vec<Gpu> {
        let g = |index, id: &str, name: &str, kind: &str, auto| {
            let (uuid, pci) = id.split_once(',').unwrap();
            Gpu { index, id: id.into(), uuid: uuid.into(), pci: pci.into(), name: name.into(), kind: kind.into(), driver: String::new(), usable: true, auto }
        };
        vec![
            g(0, "db9f2c19-5281-1700-f6e4-7ed08fa734f0,10de:2b85", "NVIDIA GeForce RTX 5090", "discrete", true),
            g(1, "00000000-7a00-0000-0000-000000000000,1002:13c0", "AMD Ryzen 7 9800X3D 8-Core Processor (RADV RAPHAEL_MENDOCINO)", "integrated", false),
            g(2, "6d657361-3236-2e32-2e35-2d6172636800,10005:0000", "llvmpipe (LLVM 23.1.3, 256 bits)", "cpu", false),
        ]
    }
    #[test]
    fn parse_and_resolve() {
        let l = l();
        assert_eq!(parse("nvidia", &l).unwrap(), l[0].id);
        assert_eq!(parse("AMD", &l).unwrap(), l[1].id);
        assert_eq!(parse("radeon", &l).unwrap(), l[1].id);
        assert_eq!(parse("1", &l).unwrap(), l[1].id);
        assert_eq!(parse("none", &l).unwrap(), "cpu");
        assert_eq!(parse("2", &l).unwrap(), "cpu");
        assert_eq!(parse("Auto", &l).unwrap(), "auto");
        assert_eq!(parse("DB9F2C19-5281-1700-F6E4-7ED08FA734F0", &l).unwrap(), l[0].id);
        assert!(parse("intel", &l).is_err());
        assert!(parse("cpu", &l[..2]).is_err());
        assert_eq!(resolve("auto", &l).unwrap().index, 0);
        assert_eq!(resolve("ffffffff-0000-0000-0000-000000000000,1002:13c0", &l).unwrap().index, 1);
        assert_eq!(l[1].label(), "AMD Radeon (RADV RAPHAEL_MENDOCINO) · integrated");
        assert_eq!(l[2].label(), "CPU (llvmpipe)");
        assert_eq!(setting_label(&l[1].id, &l), l[1].label());
        assert_eq!(choices(&l).len(), 4);
        assert_eq!(compact(&l[0].name, "discrete"), "RTX 5090");
        assert_eq!(compact(&l[1].name, "integrated"), "Radeon");
    }
    #[test]
    fn sharing() {
        let l = l();
        let nv = HelperGpu { want: "auto".into(), uuid: l[0].uuid.clone(), ..Default::default() };
        let amd = HelperGpu { want: l[1].id.clone(), uuid: l[1].uuid.clone(), ..Default::default() };
        assert!(serves(Some(&nv), "auto", Some(&l)));
        assert!(serves(Some(&nv), &l[0].id, Some(&l)));
        assert!(!serves(Some(&nv), &l[1].id, Some(&l)));
        assert!(serves(Some(&amd), &l[1].id, Some(&l)));
        assert!(!serves(Some(&amd), "auto", Some(&l)));
        assert!(!serves(Some(&amd), "cpu", Some(&l)));
        assert!(serves(None, "auto", None));
        assert!(!serves(None, "cpu", None));
        assert!(serves(Some(&amd), &l[1].id, None));
    }
}
