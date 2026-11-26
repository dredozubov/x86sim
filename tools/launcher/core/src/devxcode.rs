//! Xcode projects for `x86sim dev`: an .xcodeproj or .xcworkspace builds with Apple's open-source Swift Build (Xcode's
//! build engine), through omarchy-apple-dev's linux-bin/xcodebuild; swiftbuild/install.sh installs it (`x86sim dev
//! setup swiftbuild`). Products go to DIR/build/x86sim (the derived data dir).
use crate::dev;
use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
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

/// The fork's xcodebuild stand-in
pub fn xcodebuild() -> PathBuf {
    dev::fork_dir().join("linux-bin/xcodebuild")
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

/// The workspace or project in DIR, as xcodebuild picks it: one .xcodeproj, else the .xcworkspace (a CocoaPods
/// workspace sits next to its project: the workspace wins then)
pub fn container(dir: &Path) -> Option<(&'static str, PathBuf)> {
    let mut ws = vec![];
    let mut pj = vec![];
    for e in std::fs::read_dir(dir).ok()?.flatten() {
        let p = e.path();
        match p.extension().and_then(|x| x.to_str()) {
            Some("xcworkspace") => ws.push(p),
            Some("xcodeproj") => pj.push(p),
            _ => {}
        }
    }
    ws.sort();
    pj.sort();
    if let Some(w) = ws.into_iter().next() {
        return Some(("-workspace", w));
    }
    pj.into_iter().next().map(|p| ("-project", p))
}

/// The scheme to build: $XCODE_SCHEME, else the one named like the project / workspace, else the first
pub fn scheme(dir: &Path) -> Result<String> {
    if let Ok(s) = std::env::var("XCODE_SCHEME") {
        return Ok(s);
    }
    let (flag, path) = container(dir).context("no .xcodeproj or .xcworkspace")?;
    let out = dev::command("python3").arg(xcodebuild()).arg(flag).arg(&path).args(["-list", "-json"]).current_dir(dir).stdin(Stdio::null()).output()?;
    let v: serde_json::Value = serde_json::from_slice(&out.stdout).with_context(|| format!("xcodebuild -list: {}", String::from_utf8_lossy(&out.stderr).trim()))?;
    let schemes: Vec<String> = ["project", "workspace"].iter().filter_map(|k| v[k]["schemes"].as_array()).flatten().filter_map(|s| s.as_str().map(String::from)).collect();
    let stem = path.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
    schemes.iter().find(|s| **s == stem).or(schemes.first()).cloned().context("the project has no scheme")
}

fn derived(dir: &Path) -> PathBuf {
    dir.join("build/x86sim")
}

/// The last simulator build's .app
pub fn last_app(dir: &Path) -> Option<PathBuf> {
    let products = derived(dir).join("Build/Products");
    let mut apps: Vec<PathBuf> = std::fs::read_dir(&products)
        .into_iter()
        .flatten()
        .flatten()
        .filter(|e| e.file_name().to_string_lossy().ends_with("simulator"))
        .flat_map(|e| std::fs::read_dir(e.path()).into_iter().flatten().flatten().map(|a| a.path()))
        .filter(|p| p.extension().is_some_and(|x| x == "app"))
        .collect();
    apps.sort_by_key(|p| std::fs::metadata(p).and_then(|m| m.modified()).ok());
    apps.pop()
}

/// A simulator build of the project's app for a phone's platform (ios, tvos, watchos, xros): the .app
pub fn build(dir: &Path, platform: &str, release: bool, say: &mut dyn FnMut(&str)) -> Result<PathBuf> {
    let (flag, path) = container(dir).context("no .xcodeproj or .xcworkspace")?;
    anyhow::ensure!(swiftbuild_dir().join("current/sweetpad").exists(), "Swift Build is not installed: x86sim dev setup swiftbuild");
    let scheme = scheme(dir)?;
    let dest = match platform {
        "tvos" => "generic/platform=tvOS Simulator",
        "watchos" => "generic/platform=watchOS Simulator",
        "xros" => "generic/platform=visionOS Simulator",
        _ => "generic/platform=iOS Simulator",
    };
    let cfg = if release { "Release" } else { "Debug" };
    say(&format!("== build {scheme} ({dest}, {cfg})"));
    let mut c = dev::command("python3");
    c.arg(xcodebuild()).arg(flag).arg(&path).args(["-scheme", &scheme, "-configuration", cfg, "-destination", dest, "-derivedDataPath"]).arg(derived(dir)).arg("build").current_dir(dir);
    let mut app = None;
    let rc = dev::stream(c, &mut |l: &str| {
        if let Some(a) = l.strip_prefix("product: ") {
            app = Some(PathBuf::from(a.trim()));
        }
        say(l);
    })?;
    anyhow::ensure!(rc == 0, "the build failed (exit {rc})");
    let app = app.filter(|a| a.extension().is_some_and(|x| x == "app")).or_else(|| last_app(dir)).context("the build named no .app (is the scheme an app?)")?;
    Ok(app)
}
