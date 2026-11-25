//! CocoaPods for `x86sim dev`: the pinned, user-local Ruby + CocoaPods that omarchy-apple-dev's cocoapods/install.sh
//! installs (`pod install` on Linux), shown in `x86sim dev status`, installed by `x86sim dev setup cocoapods`, run by
//! `x86sim dev pod ARGS`.
use crate::dev;
use anyhow::Result;
use std::path::{Path, PathBuf};
use std::process::Command;

fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

/// Where cocoapods/install.sh puts Ruby and the gems (its POD_HOME default)
pub fn pod_home() -> PathBuf {
    if let Some(p) = std::env::var_os("POD_HOME") {
        return PathBuf::from(p);
    }
    let data = std::env::var_os("XDG_DATA_HOME").filter(|v| !v.is_empty()).map(PathBuf::from).unwrap_or_else(|| home().join(".local/share"));
    data.join("omarchy-apple-dev/cocoapods")
}

/// The `pod` wrapper the install wrote (in POD_HOME; ~/.local/bin/pod links to it)
pub fn pod() -> Option<PathBuf> {
    let p = pod_home().join("bin/pod");
    p.is_file().then_some(p)
}

/// The pinned CocoaPods version (the fork's cocoapods/gems.lock)
fn pinned() -> String {
    std::fs::read_to_string(dev::fork_dir().join("cocoapods/gems.lock")).ok().and_then(|s| s.lines().find_map(|l| l.strip_prefix("cocoapods ").map(|v| v.trim().to_string()))).unwrap_or_default()
}

/// The status piece: ok when the pinned set is in place (install.sh --check)
pub fn status_piece() -> Option<dev::Piece> {
    let script = dev::fork_dir().join("cocoapods/install.sh");
    if !script.is_file() {
        return None;
    }
    let current = dev::command("bash").arg(&script).arg("--check").stdin(std::process::Stdio::null()).stderr(std::process::Stdio::null()).status().is_ok_and(|s| s.success());
    let (state, detail) = match (pod(), current) {
        (Some(_), true) => ("ok", format!("CocoaPods {} in {}", pinned(), pod_home().display())),
        (Some(_), false) => ("stale", format!("installed, but not the pinned set (CocoaPods {})", pinned())),
        // optional: only React Native, Expo and Flutter apps with CocoaPods plugins need it
        (None, _) => ("warn", "not installed (React Native, Expo and Flutter plugins with a Podfile need it; about 70 MB, no root)".to_string()),
    };
    Some(dev::Piece { id: "cocoapods", title: "CocoaPods", state, detail, fix: if state == "ok" { String::new() } else { "x86sim dev setup cocoapods".into() } })
}

/// Installs or updates it (the fork's cocoapods/install.sh), output to `say`
pub fn install(say: &mut dyn FnMut(&str)) -> Result<i32> {
    say("== cocoapods: install");
    let mut c = dev::command("bash");
    c.arg(dev::fork_dir().join("cocoapods/install.sh"));
    dev::stream(c, say)
}

/// `pod ARGS` in DIR (the ios/ folder of a React Native app, or wherever the Podfile is)
pub fn pod_command(dir: &Path, args: &[String]) -> Result<Command> {
    let p = pod().ok_or_else(|| anyhow::anyhow!("CocoaPods is not installed: x86sim dev setup cocoapods"))?;
    let mut c = dev::command(p);
    c.args(args).current_dir(dir);
    Ok(c)
}
