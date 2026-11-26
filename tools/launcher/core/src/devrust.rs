//! `x86sim dev` for Rust iOS apps: a cargo package (Cargo.toml, or src-tauri/Cargo.toml for a Tauri app) is built by
//! the dev toolchain's rust/build.py (cargo for aarch64-apple-ios-sim with the Darwin SDK and ld64.lld, then the .app).
//! The app's name and bundle id come from [package.metadata.ios] (bundle-id, display-name), else from tauri.conf.json
//! (identifier, productName) or Dioxus.toml, as build.py takes them.
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct RustProject {
    pub crate_dir: PathBuf,
    pub name: String,
    pub bundle_id: String,
    pub app: Option<PathBuf>,
}

/// `key = "value"` lines of one TOML table (enough for the plain string keys read here)
fn toml_table(text: &str, table: &str) -> Vec<(String, String)> {
    let mut cur = String::new();
    let mut v = vec![];
    for l in text.lines() {
        let l = l.trim();
        if l.starts_with('[') {
            cur = l.trim_matches(|c| c == '[' || c == ']').trim().to_string();
            continue;
        }
        if cur != table {
            continue;
        }
        if let Some((k, val)) = l.split_once('=') {
            let val = val.trim();
            if let Some(s) = val.strip_prefix('"').and_then(|s| s.split('"').next()) {
                v.push((k.trim().to_string(), s.to_string()));
            }
        }
    }
    v
}

fn get(t: &[(String, String)], k: &str) -> Option<String> {
    t.iter().find(|(a, _)| a == k).map(|(_, v)| v.clone()).filter(|v| !v.is_empty())
}

/// The cargo package of a Rust app project, if DIR is one
pub fn detect(dir: &Path) -> Option<RustProject> {
    let crate_dir = [dir.to_path_buf(), dir.join("src-tauri")].into_iter().find(|d| d.join("Cargo.toml").is_file())?;
    let text = std::fs::read_to_string(crate_dir.join("Cargo.toml")).ok()?;
    let pkg = toml_table(&text, "package");
    let meta = toml_table(&text, "package.metadata.ios");
    let mut name = get(&pkg, "name")?;
    let mut bundle_id = String::new();
    if let Ok(t) = std::fs::read_to_string(crate_dir.join("tauri.conf.json")) {
        if let Ok(j) = serde_json::from_str::<serde_json::Value>(&t) {
            bundle_id = j["identifier"].as_str().unwrap_or_default().to_string();
            name = j["productName"].as_str().map(String::from).unwrap_or(name);
        }
    }
    for d in [&crate_dir, &dir.to_path_buf()] {
        if let Ok(t) = std::fs::read_to_string(d.join("Dioxus.toml")) {
            name = get(&toml_table(&t, "application"), "name").unwrap_or(name);
            bundle_id = get(&toml_table(&t, "bundle"), "identifier").unwrap_or(bundle_id);
        }
    }
    let name = get(&meta, "display-name").unwrap_or(name);
    let bundle_id = get(&meta, "bundle-id").unwrap_or(bundle_id);
    let target = std::env::var_os("CARGO_TARGET_DIR").map(PathBuf::from).unwrap_or_else(|| crate_dir.join("target"));
    let app = Some(target.join("ios-sim").join(format!("{}.app", name.replace('/', "_")))).filter(|p| p.is_dir());
    Some(RustProject { crate_dir, name, bundle_id, app })
}

/// cargo and the iOS target the build needs, as a list of what is missing (empty: ready)
pub fn missing() -> Vec<String> {
    let mut v = vec![];
    if crate::dev::which("cargo").is_none() {
        v.push("cargo (rustup.rs)".to_string());
    }
    let rustup = crate::dev::which("rustup");
    let has_target = rustup
        .and_then(|r| Command::new(r).args(["target", "list", "--installed"]).output().ok())
        .is_some_and(|o| String::from_utf8_lossy(&o.stdout).lines().any(|l| l.trim() == "aarch64-apple-ios-sim"));
    if !has_target {
        v.push("the aarch64-apple-ios-sim target (rustup target add aarch64-apple-ios-sim, or the dev toolchain's rust/setup.sh)".to_string());
    }
    v
}

/// The status line for Rust apps: (state, detail, fix). Optional for x86Sim, so "warn" when missing.
pub fn status() -> (&'static str, String, String) {
    let m = missing();
    let fix = format!("{}", crate::dev::fork_dir().join("rust/setup.sh").display());
    if m.is_empty() {
        ("ok", "cargo with aarch64-apple-ios-sim: Rust apps (cargo packages) build with rust/build.py".to_string(), String::new())
    } else {
        ("warn", format!("only for Rust apps: missing {}", m.join("; ")), fix)
    }
}

/// rust/build.py for the simulator (prints "simulator app ready: PATH" at the end, as ship.sh --simulator)
pub fn build_command(dir: &Path, release: bool) -> Command {
    let mut c = crate::dev::command("python3");
    c.arg("-I").arg(crate::dev::fork_dir().join("rust/build.py")).arg("--simulator");
    if release {
        c.arg("--release");
    }
    c.arg(dir).current_dir(dir);
    c
}
