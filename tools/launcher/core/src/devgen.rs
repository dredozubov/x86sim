//! Dependency managers and project generators for `x86sim dev`, each built and run on Linux by the dev toolchain
//! (omarchy-apple-dev): Carthage (a Cartfile next to the Xcode project), XcodeGen (project.yml), Tuist (Project.swift:
//! its manifests evaluated with Tuist's own ProjectDescription built for Linux, the project written by XcodeGen). The
//! fork's tools/build-project runs them before the Xcode build; here they are optional setup pieces (`x86sim dev setup
//! carthage`, `xcodegen`, `tuist`): their status and install.
use crate::dev;
use anyhow::{Context, Result};
use std::process::Stdio;

/// A tool of the dev toolchain: its setup id, title, install script (relative to the fork), what it is for
struct Tool {
    id: &'static str,
    title: &'static str,
    install: &'static str,
    needed_for: &'static str,
}

const TOOLS: &[Tool] = &[
    Tool {
        id: "carthage",
        title: "Carthage",
        install: "carthage/install.sh",
        needed_for: "apps with a Cartfile need it; built here from source, about 12 MB",
    },
    Tool {
        id: "xcodegen",
        title: "XcodeGen",
        install: "xcodegen/install.sh",
        needed_for: "apps with a project.yml need it; built here from source, about 30 MB",
    },
    Tool {
        id: "tuist",
        title: "Tuist",
        install: "tuist/install.sh",
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
