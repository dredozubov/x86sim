//! Xcode projects for `x86sim dev`: an .xcodeproj or .xcworkspace builds with Apple's open-source Swift Build (Xcode's
//! build engine), through omarchy-apple-dev's linux-bin/xcodebuild; swiftbuild/install.sh installs it (`x86sim dev
//! setup swiftbuild`). The fork's tools/build-project runs the build (products in DIR/build/x86sim, the derived data dir).
use crate::dev;
use anyhow::Result;
use std::path::PathBuf;
use std::process::Stdio;

fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

/// Where swiftbuild/install.sh puts sweetpad + Swift Build (its OAD_SWIFTBUILD_DIR default)
pub fn swiftbuild_dir() -> PathBuf {
    if let Some(p) = std::env::var_os("OAD_SWIFTBUILD_DIR") {
        return PathBuf::from(p);
    }
    let data = std::env::var_os("XDG_DATA_HOME").filter(|v| !v.is_empty()).map(PathBuf::from).unwrap_or_else(|| home().join(".local/share"));
    data.join("omarchy-apple-dev/swiftbuild")
}

/// The status piece: ok when Swift Build is installed (install.sh --check)
pub fn status_piece() -> Option<dev::Piece> {
    let script = dev::fork_dir().join("swiftbuild/install.sh");
    if !script.is_file() {
        return None;
    }
    let out = dev::command("bash").arg(&script).arg("--check").stdin(Stdio::null()).stderr(Stdio::null()).output().ok();
    let (state, detail) = match out.filter(|o| o.status.success()) {
        Some(o) => ("ok", format!("{} (Swift Build) in {}", String::from_utf8_lossy(&o.stdout).trim(), swiftbuild_dir().display())),
        // optional: only Xcode projects need it (xtool packages, Flutter, React Native / Expo build without it)
        None => ("warn", "not installed (Xcode projects and workspaces need it; about 220 MB, no root)".to_string()),
    };
    Some(dev::Piece { id: "swiftbuild", title: "Swift Build", state, detail, fix: if state == "ok" { String::new() } else { "x86sim dev setup swiftbuild".into() } })
}

/// Installs it (the fork's swiftbuild/install.sh), output to `say`
pub fn install(say: &mut dyn FnMut(&str)) -> Result<i32> {
    say("== swiftbuild: install");
    let mut c = dev::command("bash");
    c.arg(dev::fork_dir().join("swiftbuild/install.sh"));
    dev::stream(c, say)
}
