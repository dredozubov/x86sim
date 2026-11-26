//! Which Vulkan device mtlvk serves on: the list (`mtlvk --list-gpus`), the choice (MTLVK_DEVICE_ID, MTLVK_DEVICE)
//! and the record of what it chose (`<socket>.gpu` beside its socket, read by boot-a64.sh and the launcher).
//!
//! A GPU is named by its Vulkan deviceUUID, which the spec keeps the same across processes, reboots and driver
//! versions, with its PCI vendor:device as a fallback (RADV derives its UUID from the PCI address, so a card moved to
//! another slot gets a new one): MTLVK_DEVICE_ID="<uuid>,<vendor>:<device>" takes the first that matches. "cpu" is a
//! software device (lavapipe: everything on the CPU, no GPU at all), "auto" (or unset) mtlvk's own pick. The loader's
//! order, which MTLVK_DEVICE=<n> indexes, can change between boots.

use metal2vulkan_runtime::PhysicalDevice;

pub struct Gpu {
    pub index: usize,
    pub name: String,
    pub vendor_id: u32,
    pub device_id: u32,
    /// discrete | integrated | virtual | cpu | other
    pub kind: &'static str,
    pub driver: String,
    pub uuid: String,
    /// above metal2vulkan-runtime's floor
    pub usable: bool,
}

impl Gpu {
    pub fn pci(&self) -> String {
        format!("{:04x}:{:04x}", self.vendor_id, self.device_id)
    }
    /// The setting's form: the UUID, then vendor:device
    pub fn id(&self) -> String {
        format!("{},{}", self.uuid, self.pci())
    }
    fn json(&self, auto: bool) -> String {
        format!(
            "{{\"index\":{},\"id\":{},\"uuid\":{},\"pci\":{},\"name\":{},\"type\":{},\"driver\":{},\"usable\":{},\"auto\":{}}}",
            self.index,
            q(&self.id()),
            q(&self.uuid),
            q(&self.pci()),
            q(&self.name),
            q(self.kind),
            q(&self.driver),
            self.usable,
            auto
        )
    }
}

/// A JSON string
fn q(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    o.push('"');
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

fn uuid_str(u: &[u8; 16]) -> String {
    let h: String = u.iter().map(|b| format!("{b:02x}")).collect();
    format!("{}-{}-{}-{}-{}", &h[0..8], &h[8..12], &h[12..16], &h[16..20], &h[20..32])
}

/// What mtlvk was asked for: MTLVK_DEVICE_ID, else MTLVK_DEVICE's index, else auto (boot-a64.sh's a64_gpu_want says
/// the same, to tell whether a running mtlvk serves the GPU a boot wants)
pub fn want() -> String {
    match std::env::var("MTLVK_DEVICE_ID").map(|v| v.trim().to_string()) {
        Ok(v) if !v.is_empty() && v != "auto" => v,
        _ => match std::env::var("MTLVK_DEVICE").ok().and_then(|v| v.trim().parse::<usize>().ok()) {
            Some(n) => format!("index:{n}"),
            None => "auto".into(),
        },
    }
}

/// A software Vulkan driver's manifest to add to the loader's search when none is installed system-wide:
/// MTLVK_LAVAPIPE_ICD, else $XDG_DATA_HOME/x86sim/lavapipe/lvp_icd.json (a user's own unpacked lavapipe).
fn lavapipe_icd() -> Option<String> {
    if let Some(p) = std::env::var_os("MTLVK_LAVAPIPE_ICD").filter(|p| !p.is_empty()) {
        return Some(p.to_string_lossy().into_owned());
    }
    let data = std::env::var_os("XDG_DATA_HOME")
        .map(std::path::PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| std::path::Path::new(&h).join(".local/share")))?;
    let p = data.join("x86sim/lavapipe/lvp_icd.json");
    p.exists().then(|| p.to_string_lossy().into_owned())
}

/// Before the Vulkan instance: let the loader also find a lavapipe that is not installed system-wide, when the list
/// or a CPU device is wanted (a GPU choice does not load it)
pub fn prepare_loader(listing: bool) {
    if !(listing || want() == "cpu") {
        return;
    }
    let Some(icd) = lavapipe_icd() else { return };
    let mut v = std::env::var("VK_ADD_DRIVER_FILES").unwrap_or_default();
    if !v.split(':').any(|p| p == icd) {
        if !v.is_empty() {
            v.push(':');
        }
        v.push_str(&icd);
        // main's first steps, before any other thread starts
        std::env::set_var("VK_ADD_DRIVER_FILES", v);
    }
}

/// Every Vulkan device, in the loader's order
pub fn describe(instance: &ash::Instance, physical: &[PhysicalDevice]) -> Vec<Gpu> {
    physical
        .iter()
        .enumerate()
        .map(|(index, p)| {
            let mut id = ash::vk::PhysicalDeviceIDProperties::default();
            let mut driver = ash::vk::PhysicalDeviceDriverProperties::default();
            let mut props = ash::vk::PhysicalDeviceProperties2::default().push_next(&mut id).push_next(&mut driver);
            // SAFETY: a query of the instance's own physical device (Vulkan 1.2 queries; the instance is 1.3)
            unsafe { instance.get_physical_device_properties2(p.raw(), &mut props) };
            let pr = props.properties;
            use ash::vk::PhysicalDeviceType as T;
            let kind = match pr.device_type {
                T::DISCRETE_GPU => "discrete",
                T::INTEGRATED_GPU => "integrated",
                T::VIRTUAL_GPU => "virtual",
                T::CPU => "cpu",
                _ => "other",
            };
            let s = |c: Result<&std::ffi::CStr, _>| c.map(|c| c.to_string_lossy().into_owned()).unwrap_or_default();
            let (dn, di) = (s(driver.driver_name_as_c_str()), s(driver.driver_info_as_c_str()));
            Gpu {
                index,
                name: s(pr.device_name_as_c_str()),
                vendor_id: pr.vendor_id,
                device_id: pr.device_id,
                kind,
                driver: if di.is_empty() || dn.contains(&di) { dn } else { format!("{dn} {di}") },
                uuid: uuid_str(&id.device_uuid),
                usable: p.check().is_ok(),
            }
        })
        .collect()
}

/// mtlvk's own pick among the usable: a discrete GPU, else an integrated one, else the first; a CPU device last
fn auto(g: &[Gpu]) -> Option<usize> {
    let rank = |k: &str| match k {
        "discrete" => 0,
        "integrated" => 1,
        "cpu" => 3,
        _ => 2,
    };
    g.iter().filter(|g| g.usable).min_by_key(|g| (rank(g.kind), g.index)).map(|g| g.index)
}

/// The device `want` names among the usable, None when it names none of them
fn named(g: &[Gpu], want: &str) -> Option<usize> {
    let ok = || g.iter().filter(|g| g.usable);
    if want == "cpu" {
        return ok().find(|g| g.kind == "cpu").map(|g| g.index);
    }
    if let Some(n) = want.strip_prefix("index:") {
        // MTLVK_DEVICE=<n>: the n-th usable one, in the loader's order (as before)
        return n.parse::<usize>().ok().and_then(|n| ok().nth(n)).map(|g| g.index);
    }
    // each part in turn: "<vendor>:<device>" (hex), else a UUID (dashes and case aside)
    let norm = |s: &str| s.trim().to_ascii_lowercase().replace('-', "");
    want.split(',').map(norm).filter(|w| !w.is_empty()).find_map(|w| {
        let hit = |g: &&Gpu| if w.contains(':') { g.pci() == w } else { norm(&g.uuid) == w };
        ok().find(hit).map(|g| g.index)
    })
}

/// The index mtlvk serves on, and a note when the choice named no usable device (then it is auto's)
pub fn pick(g: &[Gpu], want: &str) -> Option<(usize, Option<String>)> {
    if want == "auto" {
        return auto(g).map(|i| (i, None));
    }
    match named(g, want) {
        Some(i) => Some((i, None)),
        None => auto(g).map(|i| (i, Some(format!("no usable Vulkan device matches {want}: mtlvk's own pick instead")))),
    }
}

/// `mtlvk --list-gpus`: every Vulkan device as a JSON array on stdout (no device is opened)
pub fn list() -> Result<(), String> {
    prepare_loader(true);
    let instance = metal2vulkan_runtime::Instance::new(&[]).map_err(|e| format!("Vulkan instance: {e}"))?;
    let physical = instance.physical_devices().map_err(|e| format!("physical devices: {e}"))?;
    let g = describe(instance.raw().1, &physical);
    let a = auto(&g);
    let rows: Vec<String> = g.iter().map(|x| x.json(Some(x.index) == a)).collect();
    println!("[{}]", rows.join(",\n "));
    Ok(())
}

/// `<socket>.gpu` (mtlvk.sock -> mtlvk.gpu): the device this mtlvk serves on and what it was asked for, so a boot or
/// the launcher shares it only with phones that want the same GPU
pub fn record(sock: &str, g: &Gpu) {
    let path = std::path::Path::new(sock).with_extension("gpu");
    let body = format!(
        "{{\"want\":{},\"id\":{},\"uuid\":{},\"pci\":{},\"name\":{},\"type\":{},\"driver\":{},\"pid\":{}}}\n",
        q(&want()),
        q(&g.id()),
        q(&g.uuid),
        q(&g.pci()),
        q(&g.name),
        q(g.kind),
        q(&g.driver),
        std::process::id()
    );
    let tmp = path.with_extension("gpu.tmp");
    if std::fs::write(&tmp, body).is_ok() {
        let _ = std::fs::rename(&tmp, &path);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn g(index: usize, kind: &'static str, uuid: &str, v: u32, d: u32) -> Gpu {
        Gpu { index, name: format!("g{index}"), vendor_id: v, device_id: d, kind, driver: String::new(), uuid: uuid.into(), usable: true }
    }
    #[test]
    fn picks() {
        let l = vec![
            g(0, "integrated", "00000000-7a00-0000-0000-000000000000", 0x1002, 0x13c0),
            g(1, "cpu", "6d657361-3236-2e32-2e35-000000000000", 0x10005, 0),
            g(2, "discrete", "db9f2c19-5281-1700-f6e4-7ed08fa734f0", 0x10de, 0x2b85),
        ];
        assert_eq!(pick(&l, "auto").unwrap(), (2, None));
        assert_eq!(pick(&l, "cpu").unwrap(), (1, None));
        assert_eq!(pick(&l, "00000000-7a00-0000-0000-000000000000,1002:13c0").unwrap(), (0, None));
        // the UUID changed (another PCI slot): vendor:device
        assert_eq!(pick(&l, "11111111-7a00-0000-0000-000000000000,1002:13c0").unwrap(), (0, None));
        assert_eq!(pick(&l, "DB9F2C1952811700F6E47ED08FA734F0").unwrap(), (2, None));
        assert_eq!(pick(&l, "index:0").unwrap(), (0, None));
        assert!(pick(&l, "ffffffff-0000-0000-0000-000000000000").unwrap().1.is_some());
        assert_eq!(l[2].id(), "db9f2c19-5281-1700-f6e4-7ed08fa734f0,10de:2b85");
    }
}
