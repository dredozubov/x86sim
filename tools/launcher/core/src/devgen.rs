//! Dependency managers and project generators for `x86sim dev`, each built and run on Linux by the dev toolchain
//! (omarchy-apple-dev): Carthage (a Cartfile next to the Xcode project), XcodeGen (project.yml), Tuist (Project.swift:
//! its manifests evaluated with Tuist's own ProjectDescription built for Linux, the project written by XcodeGen). They
//! prepare the Xcode project that devxcode then builds with Swift Build. Their tools are optional setup pieces (`x86sim
//! dev setup carthage`, `xcodegen`, `tuist`).
use crate::dev;
use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use std::process::Stdio;

/// A tool of the dev toolchain: its setup id, title, install script (relative to the fork), runner, what it is for
struct Tool {
    id: &'static str,
    title: &'static str,
    install: &'static str,
    bin: &'static str,
    needed_for: &'static str,
}

const TOOLS: &[Tool] = &[
    Tool {
        id: "carthage",
        title: "Carthage",
        install: "carthage/install.sh",
        bin: "carthage/bin/carthage",
        needed_for: "apps with a Cartfile need it; built here from source, about 12 MB",
    },
    Tool {
        id: "xcodegen",
        title: "XcodeGen",
        install: "xcodegen/install.sh",
        bin: "xcodegen/bin/xcodegen",
        needed_for: "apps with a project.yml need it; built here from source, about 30 MB",
    },
    Tool {
        id: "tuist",
        title: "Tuist",
        install: "tuist/install.sh",
        bin: "tuist/bin/tuist",
        needed_for: "apps with a Tuist Project.swift need it (and XcodeGen); about 10 MB",
    },
];

fn tool(id: &str) -> Option<&'static Tool> {
    TOOLS.iter().find(|t| t.id == id)
}

/// The setup steps this module installs
pub fn is_tool(id: &str) -> bool {
    tool(id).is_some()
}

/// A setup job's "== " headings, for its progress
pub fn job_steps(id: &str) -> &'static [&'static str] {
    match id {
        "carthage" => &["== carthage: fetch", "== carthage: patch", "== carthage: build"],
        "xcodegen" => &["== xcodegen: fetch", "== xcodegen: build"],
        "tuist" => &["== tuist: fetch", "== tuist: build"],
        _ => &[],
    }
}

/// The status pieces: ok when the tool is installed (install.sh --check)
pub fn status_pieces() -> Vec<dev::Piece> {
    TOOLS
        .iter()
        .filter_map(|t| {
            let script = dev::fork_dir().join(t.install);
            if !script.is_file() {
                return None;
            }
            let out = dev::command("bash").arg(&script).arg("--check").stdin(Stdio::null()).stderr(Stdio::null()).output().ok();
            let (state, detail) = match out.filter(|o| o.status.success()) {
                Some(o) => ("ok", String::from_utf8_lossy(&o.stdout).trim().to_string()),
                None => ("warn", format!("not installed ({})", t.needed_for)),
            };
            Some(dev::Piece { id: t.id, title: t.title, state, detail, fix: if state == "ok" { String::new() } else { format!("x86sim dev setup {}", t.id) } })
        })
        .collect()
}

/// Installs a tool (the fork's install script), output to `say`
pub fn install(id: &str, say: &mut dyn FnMut(&str)) -> Result<i32> {
    let t = tool(id).with_context(|| format!("unknown tool {id}"))?;
    say(&format!("== {id}: install"));
    let mut c = dev::command("bash");
    c.arg(dev::fork_dir().join(t.install));
    dev::stream(c, say)
}

fn runner(id: &str) -> Result<PathBuf> {
    let t = tool(id).with_context(|| format!("unknown tool {id}"))?;
    let check = dev::command("bash").arg(dev::fork_dir().join(t.install)).arg("--check").stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).status();
    anyhow::ensure!(check.is_ok_and(|s| s.success()), "{} is not installed: x86sim dev setup {id}", t.title);
    Ok(dev::fork_dir().join(t.bin))
}

/// The kind of project in DIR this module prepares, if any: tuist (a Project.swift written against
/// ProjectDescription), xcodegen (a project.yml), carthage (a Cartfile and an Xcode project)
pub fn kind(dir: &Path) -> Option<&'static str> {
    if is_tuist(dir) {
        return Some("tuist");
    }
    if is_xcodegen(dir) {
        return Some("xcodegen");
    }
    let has_xcode = std::fs::read_dir(dir).ok()?.flatten().any(|e| {
        let n = e.file_name().to_string_lossy().into_owned();
        n.ends_with(".xcodeproj") || n.ends_with(".xcworkspace")
    });
    (dir.join("Cartfile").is_file() && has_xcode).then_some("carthage")
}

/// A Tuist project: Project.swift importing ProjectDescription
fn is_tuist(dir: &Path) -> bool {
    std::fs::read_to_string(dir.join("Project.swift")).is_ok_and(|s| s.contains("import ProjectDescription"))
}

/// A project.yml that is an XcodeGen spec (it names targets)
fn is_xcodegen(dir: &Path) -> bool {
    std::fs::read_to_string(dir.join("project.yml")).is_ok_and(|y| y.lines().any(|l| l.starts_with("targets:") || l.starts_with("include:")))
}

/// Carthage's name for a phone's platform
fn carthage_platform(platform: &str) -> &'static str {
    match platform {
        "tvos" => "tvOS",
        "watchos" => "watchOS",
        "xros" => "visionOS",
        _ => "iOS",
    }
}

/// Gets the project ready for Swift Build: `carthage bootstrap` when there is a Cartfile (xcframeworks, cached builds:
/// a dependency is built again only when its version changes), then `xcodegen generate` for a project.yml (after
/// Carthage: XcodeGen's Carthage dependencies look at Carthage/Build)
pub fn prepare(dir: &Path, platform: &str, say: &mut dyn FnMut(&str)) -> Result<()> {
    if dir.join("Cartfile").is_file() {
        let carthage = runner("carthage")?;
        say(&format!("== carthage bootstrap ({})", carthage_platform(platform)));
        let mut c = dev::command("bash");
        c.arg(&carthage).args(["bootstrap", "--use-xcframeworks", "--cache-builds", "--platform", carthage_platform(platform)]).current_dir(dir);
        let rc = dev::stream(c, say)?;
        anyhow::ensure!(rc == 0, "carthage bootstrap failed (exit {rc}; its xcodebuild log is named above)");
    }
    if is_tuist(dir) {
        let tuist = runner("tuist")?;
        runner("xcodegen")?;
        say("== tuist generate");
        let mut c = dev::command("bash");
        c.arg(&tuist).args(["generate", "--no-open"]).current_dir(dir);
        let rc = dev::stream(c, say)?;
        anyhow::ensure!(rc == 0, "tuist generate failed (exit {rc})");
    } else if is_xcodegen(dir) {
        let xcodegen = runner("xcodegen")?;
        say("== xcodegen generate");
        let mut c = dev::command("bash");
        c.arg(&xcodegen).arg("generate").current_dir(dir);
        let rc = dev::stream(c, say)?;
        anyhow::ensure!(rc == 0, "xcodegen generate failed (exit {rc})");
    }
    Ok(())
}
