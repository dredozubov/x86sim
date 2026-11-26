//! `x86sim dev` for Rust iOS apps: a cargo package (Cargo.toml, or src-tauri/Cargo.toml for a Tauri app) is built by
//! the dev toolchain's rust/build.py (cargo for aarch64-apple-ios-sim with the Darwin SDK and ld64.lld, then the .app),
//! through its tools/build-project. Here: whether cargo and the iOS target are there (x86sim dev status).
use std::process::Command;

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
