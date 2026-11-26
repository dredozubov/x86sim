//! Cross-platform app shells for `x86sim dev`: a web or JavaScript app with a generated native iOS project. The shell's
//! own CLI writes (or refreshes) that Xcode project on Linux, then it builds with Swift Build like any Xcode project
//! (devxcode.rs). Kinds:
//!
//! - capacitor: package.json with @capacitor/ios. The web build (`npm run build`, when the app has one), then `npx cap
//!   sync ios`; the Xcode project is ios/App (Swift packages, or a CocoaPods workspace when the app uses pods).
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
    let pj = package_json(dir)?;
    if has_dep(&pj, "@capacitor/ios") {
        return Some("capacitor");
    }
    if has_dep(&pj, "cordova-ios") && dir.join("config.xml").exists() {
        return Some("cordova");
    }
    None
}

pub fn is_shell(kind: &str) -> bool {
    matches!(kind, "capacitor" | "cordova")
}

/// The generated Xcode project's directory (where its .xcodeproj / .xcworkspace is)
fn native_dir(dir: &Path, kind: &str) -> PathBuf {
    if kind == "cordova" {
        return dir.join("platforms/ios");
    }
    // capacitor.config.json's ios.path moves ios/ (capacitor.config.ts: the default)
    let cfg: Option<serde_json::Value> = std::fs::read_to_string(dir.join("capacitor.config.json")).ok().and_then(|s| serde_json::from_str(&s).ok());
    let ios = cfg.as_ref().and_then(|c| c["ios"]["path"].as_str()).unwrap_or("ios");
    dir.join(ios).join("App")
}

/// The last simulator build's .app
pub fn last_app(dir: &Path, kind: &str) -> Option<PathBuf> {
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
    let pm = package_manager(dir);
    if !dir.join("node_modules").is_dir() {
        let mut c = dev::command(pm);
        c.arg("install");
        step(c, dir, &format!("{pm} install"), say)?;
    }
    let pj = package_json(dir).unwrap_or_default();
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
    Ok(())
}

/// A simulator build for a phone's platform: the .app
pub fn build(dir: &Path, kind: &str, platform: &str, release: bool, say: &mut dyn FnMut(&str)) -> Result<PathBuf> {
    anyhow::ensure!(platform == "ios", "{kind} apps build for iPhone and iPad devices here (not {platform})");
    prepare(dir, kind, say)?;
    let native = native_dir(dir, kind);
    anyhow::ensure!(devxcode::container(&native).is_some(), "{}: no Xcode project after the {kind} step", native.display());
    devxcode::build(&native, platform, release, say).context("the Xcode project's build")
}
