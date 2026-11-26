//! Cross-platform app shells for `x86sim dev`: a web or JavaScript app with a generated native iOS project. The shell's
//! own CLI writes (or refreshes) that Xcode project on Linux, then it builds with Swift Build like any Xcode project
//! (devxcode.rs). Kinds:
//!
//! - capacitor: package.json with @capacitor/ios, or @capacitor/core and a capacitor.config.* (an Ionic starter, which
//!   gets @capacitor/ios added as `ionic capacitor add ios` would). The web build (`npm run build`, when the app has
//!   one), then `npx cap add ios` once and `npx cap sync ios`; the Xcode project is ios/App (Swift packages, or a
//!   CocoaPods workspace when the app uses pods).
//! - nativescript: package.json with @nativescript/ios or @nativescript/core and a nativescript.config.*. The dev
//!   toolchain's shells/nativescript/ns runs `ns prepare ios` with the CLI's macOS gates lifted, then puts its Linux
//!   build of NativeScript's metadata generator into platforms/ios (the Xcode project; its link step runs it).
//! - godot: a Godot 4 project (project.godot) with an iOS export preset. The dev toolchain's shells/godot/export.sh
//!   exports it on Linux (Godot's editor, headless, and its iOS template) into build/godot-ios; the Xcode project
//!   builds for iOS devices (the template's simulator library is x86_64 only), which x86Sim converts at install.
//! - unity: a Unity project (ProjectSettings/ProjectVersion.txt, Assets/). The dev toolchain's shells/unity/build.sh
//!   exports its iOS Xcode project (IL2CPP, arm64 simulator) with the Unity editor for Linux (UNITY_EDITOR /
//!   UNITY_HOME; it needs iOS Build Support and an activated license) into build/unity-ios and makes its IL2CPP step
//!   run on Linux.
//! - cordova: package.json with cordova-ios (config.xml beside it). `cordova prepare ios` (the app's own cordova CLI,
//!   else npx's) adds the platform and copies www/; the Xcode project is platforms/ios (App.xcworkspace).
use crate::{dev, devxcode};
use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use std::process::Command;

fn package_json(dir: &Path) -> Option<serde_json::Value> {
    serde_json::from_str(&std::fs::read_to_string(dir.join("package.json")).ok()?).ok()
}

fn has_dep(pj: &serde_json::Value, name: &str) -> bool {
    ["dependencies", "devDependencies"].iter().any(|k| pj[k].get(name).is_some())
}

/// The shell kind of the app in DIR, if it is one
pub fn detect(dir: &Path) -> Option<&'static str> {
    if dir.join("project.godot").is_file() {
        return Some("godot");
    }
    if dir.join("ProjectSettings/ProjectVersion.txt").is_file() && dir.join("Assets").is_dir() {
        return Some("unity");
    }
    let pj = package_json(dir)?;
    let cap_config = ["capacitor.config.ts", "capacitor.config.js", "capacitor.config.json"].iter().any(|f| dir.join(f).exists());
    if has_dep(&pj, "@capacitor/ios") || (has_dep(&pj, "@capacitor/core") && cap_config) {
        return Some("capacitor");
    }
    if has_dep(&pj, "cordova-ios") && dir.join("config.xml").exists() {
        return Some("cordova");
    }
    let ns_config = ["nativescript.config.ts", "nativescript.config.js"].iter().any(|f| dir.join(f).exists());
    if has_dep(&pj, "@nativescript/ios") || (has_dep(&pj, "@nativescript/core") && ns_config) {
        return Some("nativescript");
    }
    None
}

pub fn is_shell(kind: &str) -> bool {
    matches!(kind, "capacitor" | "cordova" | "nativescript" | "godot" | "unity")
}

/// The generated Xcode project's directory (where its .xcodeproj / .xcworkspace is)
fn native_dir(dir: &Path, kind: &str) -> PathBuf {
    if kind == "godot" {
        return dir.join("build/godot-ios");
    }
    if kind == "unity" {
        return dir.join("build/unity-ios");
    }
    if kind == "cordova" || kind == "nativescript" {
        return dir.join("platforms/ios");
    }
    // capacitor.config.json's ios.path moves ios/ (capacitor.config.ts: the default)
    let cfg: Option<serde_json::Value> = std::fs::read_to_string(dir.join("capacitor.config.json")).ok().and_then(|s| serde_json::from_str(&s).ok());
    let ios = cfg.as_ref().and_then(|c| c["ios"]["path"].as_str()).unwrap_or("ios");
    dir.join(ios).join("App")
}

/// The last simulator build's .app
pub fn last_app(dir: &Path, kind: &str) -> Option<PathBuf> {
    if kind == "godot" {
        let products = native_dir(dir, kind).join("build/x86sim/Build/Products");
        return std::fs::read_dir(products).ok()?.flatten().filter(|e| e.file_name().to_string_lossy().ends_with("-iphoneos")).flat_map(|e| std::fs::read_dir(e.path()).into_iter().flatten().flatten().map(|a| a.path())).find(|p| p.extension().is_some_and(|x| x == "app"));
    }
    devxcode::last_app(&native_dir(dir, kind))
}

/// The JavaScript package manager the app uses (its lock file)
fn package_manager(dir: &Path) -> &'static str {
    if dir.join("yarn.lock").exists() {
        "yarn"
    } else if dir.join("pnpm-lock.yaml").exists() {
        "pnpm"
    } else if dir.join("bun.lock").exists() || dir.join("bun.lockb").exists() {
        "bun"
    } else {
        "npm"
    }
}

/// The CocoaPods wrapper (x86sim dev setup cocoapods) first on the command's PATH, for CLIs that run `pod install`
fn with_pod(c: &mut Command) {
    let Some(bin) = crate::devpods::pod().and_then(|p| p.parent().map(Path::to_path_buf)) else { return };
    let path = dev::env().into_iter().find(|(k, _)| k == "PATH").map(|(_, v)| v).unwrap_or_default();
    c.env("PATH", format!("{}:{path}", bin.display()));
}

fn step(mut c: Command, dir: &Path, what: &str, say: &mut dyn FnMut(&str)) -> Result<()> {
    say(&format!("== {what}"));
    c.current_dir(dir);
    let rc = dev::stream(c, say)?;
    anyhow::ensure!(rc == 0, "{what} failed (exit {rc})");
    Ok(())
}

/// node_modules, the web build, the shell's native project: what the Xcode build needs
pub fn prepare(dir: &Path, kind: &str, say: &mut dyn FnMut(&str)) -> Result<()> {
    if kind == "godot" {
        let mut c = dev::command("bash");
        c.arg(dev::fork_dir().join("shells/godot/export.sh")).arg(dir).arg(native_dir(dir, kind));
        return step(c, dir, "Godot: export the iOS Xcode project (shells/godot/export.sh)", say);
    }
    if kind == "unity" {
        let mut c = dev::command("bash");
        c.arg(dev::fork_dir().join("shells/unity/build.sh")).arg(dir).arg(native_dir(dir, kind));
        return step(c, dir, "Unity: export the iOS Xcode project (shells/unity/build.sh)", say);
    }
    let pm = package_manager(dir);
    if !dir.join("node_modules").is_dir() {
        let mut c = dev::command(pm);
        c.arg("install");
        step(c, dir, &format!("{pm} install"), say)?;
    }
    let mut pj = package_json(dir).unwrap_or_default();
    if kind == "capacitor" && !has_dep(&pj, "@capacitor/ios") {
        // the iOS platform package, at the version of the app's @capacitor/core (Ionic's `ionic capacitor add ios`)
        let core = pj["dependencies"]["@capacitor/core"].as_str().unwrap_or("latest").trim_start_matches(['^', '~']).to_string();
        let mut c = dev::command(pm);
        c.args([if pm == "npm" { "install" } else { "add" }, &format!("@capacitor/ios@{core}")]);
        step(c, dir, &format!("{pm} add @capacitor/ios@{core} (the app had no iOS platform package)"), say)?;
        pj = package_json(dir).unwrap_or_default();
    }
    if kind == "capacitor" {
        // Ionic / Vite / Angular apps build their web assets into the web dir cap copies
        if pj["scripts"].get("build").is_some() {
            let mut c = dev::command(pm);
            c.args(["run", "build"]);
            step(c, dir, &format!("{pm} run build"), say)?;
        }
        let native = native_dir(dir, kind);
        let mut c = dev::command("npx");
        // add ios once, then sync: copies the web assets and writes the plugins' Package.swift, or runs pod install
        // for an app on CocoaPods
        let verb = if native.is_dir() { "sync" } else { "add" };
        c.args(["cap", verb, "ios"]);
        if native.join("Podfile").exists() {
            anyhow::ensure!(crate::devpods::pod().is_some(), "{}: the app uses CocoaPods, which is not installed: x86sim dev setup cocoapods", dir.display());
        }
        with_pod(&mut c);
        step(c, dir, &format!("cap {verb} ios"), say)?;
    }
    if kind == "cordova" {
        let local = dir.join("node_modules/.bin/cordova");
        let mut c = if local.exists() { dev::command(local) } else { let mut c = dev::command("npx"); c.args(["--yes", "cordova"]); c };
        // prepare adds the platform package.json lists when it is missing, then copies www/ and config.xml
        c.args(["prepare", "ios", "--no-telemetry"]);
        with_pod(&mut c);
        step(c, dir, "cordova prepare ios", say)?;
    }
    if kind == "nativescript" {
        let mut c = dev::command(dev::fork_dir().join("shells/nativescript/ns"));
        c.args(["prepare", "ios"]).env("POD_HOME", crate::devpods::pod_home());
        step(c, dir, "ns prepare ios (shells/nativescript/ns)", say)?;
    }
    Ok(())
}

/// A simulator build for a phone's platform: the .app
pub fn build(dir: &Path, kind: &str, platform: &str, release: bool, say: &mut dyn FnMut(&str)) -> Result<PathBuf> {
    anyhow::ensure!(platform == "ios", "{kind} apps build for iPhone and iPad devices here (not {platform})");
    prepare(dir, kind, say)?;
    let native = native_dir(dir, kind);
    anyhow::ensure!(devxcode::container(&native).is_some(), "{}: no Xcode project after the {kind} step", native.display());
    if kind == "godot" {
        return device_build(&native, release, say);
    }
    devxcode::build(&native, platform, release, say).context("the Xcode project's build")
}

/// An unsigned iOS device build of the Xcode project in DIR (x86Sim's install converts a device app for its simulator)
fn device_build(dir: &Path, release: bool, say: &mut dyn FnMut(&str)) -> Result<PathBuf> {
    let (flag, path) = devxcode::container(dir).context("no Xcode project")?;
    let scheme = devxcode::scheme(dir)?;
    let cfg = if release { "Release" } else { "Debug" };
    say(&format!("== build {scheme} (generic/platform=iOS, {cfg}, unsigned: converted for the simulator at install)"));
    let mut c = dev::command("python3");
    c.arg(devxcode::xcodebuild()).arg(flag).arg(&path).args(["-scheme", &scheme, "-configuration", cfg, "-destination", "generic/platform=iOS", "-derivedDataPath"]);
    c.arg(dir.join("build/x86sim")).args(["CODE_SIGNING_ALLOWED=NO", "build"]).current_dir(dir);
    let mut app = None;
    let rc = dev::stream(c, &mut |l: &str| {
        if let Some(a) = l.strip_prefix("product: ") {
            app = Some(PathBuf::from(a.trim()));
        }
        say(l);
    })?;
    anyhow::ensure!(rc == 0, "the build failed (exit {rc})");
    app.filter(|a| a.extension().is_some_and(|x| x == "app")).context("the build named no .app")
}
