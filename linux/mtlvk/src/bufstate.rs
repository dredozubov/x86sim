//! How guest buffers reach the GPU, for the launcher and the web page: `<socket>.state`, a small JSON file next to mtlvk's
//! socket, rewritten (at most once a second) as buffers are imported or mirrored. It holds the GPU's name, the udmabuf
//! path's state ("unused": every import so far took the buffer's address; "on"; "off: why"; "unavailable: why"), and
//! counts of buffers imported by address, imported as a udmabuf, and mirrored (copied), with the first reason a buffer
//! was mirrored. Also keeps the log short: a refusal reason is logged in full the first time only.
use std::collections::HashSet;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering::Relaxed};
use std::sync::{Mutex, OnceLock};
use std::time::Instant;

pub static DIRECT: AtomicU64 = AtomicU64::new(0);
pub static UDMABUF: AtomicU64 = AtomicU64::new(0);
pub static MIRRORED: AtomicU64 = AtomicU64::new(0);

struct Info {
    path: Option<PathBuf>,
    gpu: String,
    udmabuf: String,
    mirror_reason: Option<String>,
    seen: HashSet<String>,
    written: Option<Instant>,
}

fn info() -> &'static Mutex<Info> {
    static I: OnceLock<Mutex<Info>> = OnceLock::new();
    I.get_or_init(|| Mutex::new(Info { path: None, gpu: String::new(), udmabuf: "unused".into(), mirror_reason: None, seen: HashSet::new(), written: None }))
}

/// At start: where the state goes (next to the socket) and which GPU this mtlvk renders on
pub fn init(socket: &str, gpu: &str) {
    let mut i = info().lock().unwrap();
    i.path = Some(PathBuf::from(format!("{socket}.state")));
    i.gpu = gpu.to_string();
    write(&mut i, true);
}

/// The udmabuf path's state: "on", "off: …", "unavailable: …"
pub fn set_udmabuf(state: String) {
    let mut i = info().lock().unwrap();
    i.udmabuf = state;
    write(&mut i, true);
}

pub fn imported(as_udmabuf: bool) {
    if as_udmabuf { &UDMABUF } else { &DIRECT }.fetch_add(1, Relaxed);
    let mut i = info().lock().unwrap();
    write(&mut i, false);
}

/// A buffer that is mirrored, and why. Returns true the first time this reason (its words, numbers left out) is seen:
/// the caller logs it in full then, later ones only count.
pub fn mirrored(reason: &str) -> bool {
    MIRRORED.fetch_add(1, Relaxed);
    // the reason's words: sizes, offsets and ids left out
    let key: String = reason.chars().filter(|c| !c.is_ascii_digit()).collect();
    let mut i = info().lock().unwrap();
    if i.mirror_reason.is_none() {
        i.mirror_reason = Some(reason.to_string());
    }
    let first = i.seen.insert(key);
    write(&mut i, first);
    first
}

/// A JSON string (quotes, backslashes and control characters escaped)
fn js(s: &str) -> String {
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

fn write(i: &mut Info, now: bool) {
    let Some(p) = i.path.clone() else { return };
    if !now && i.written.is_some_and(|t| t.elapsed().as_millis() < 1000) {
        return;
    }
    i.written = Some(Instant::now());
    let j = format!(
        "{{\"gpu\":{},\"udmabuf\":{},\"direct\":{},\"udmabuf_buffers\":{},\"mirrored\":{},\"mirror_reason\":{}}}",
        js(&i.gpu),
        js(&i.udmabuf),
        DIRECT.load(Relaxed),
        UDMABUF.load(Relaxed),
        MIRRORED.load(Relaxed),
        i.mirror_reason.as_deref().map_or("null".into(), js)
    );
    let tmp = p.with_extension("state.tmp");
    if std::fs::write(&tmp, j).is_ok() {
        let _ = std::fs::rename(&tmp, &p);
    }
}
