//! x86sim dev: .NET for iOS apps (a .csproj targeting net*-ios). They build on Linux with omarchy-apple-dev's
//! dotnet/build.sh (set up once by its dotnet/setup.sh): the iOS workload's MSBuild tasks against the Darwin SDK,
//! NativeAOT for iossimulator-arm64, the app under bin/<Configuration>/<tfm>/iossimulator-arm64/<Name>.app. Its
//! output ends with "simulator app ready: <app>", as ship.sh's.

use std::path::{Path, PathBuf};
use std::process::Command;

/// The .csproj of a .NET for iOS app in DIR (one whose target frameworks include net*-ios), if any
pub fn csproj(dir: &Path) -> Option<PathBuf> {
    let mut all: Vec<PathBuf> = std::fs::read_dir(dir).ok()?.flatten().map(|e| e.path()).filter(|p| p.extension().is_some_and(|x| x == "csproj")).collect();
    all.sort();
    all.into_iter().find(|p| std::fs::read_to_string(p).is_ok_and(|t| targets_ios(&t)))
}

fn targets_ios(csproj: &str) -> bool {
    ["TargetFramework", "TargetFrameworks"].iter().any(|k| tag(csproj, k).is_some_and(|v| v.split(';').any(|f| f.trim().starts_with("net") && f.trim().contains("-ios"))))
}

/// The text of the first <KEY>...</KEY> (MSBuild properties: no nesting)
fn tag(text: &str, key: &str) -> Option<String> {
    let s = text.find(&format!("<{key}>"))? + key.len() + 2;
    let e = text[s..].find(&format!("</{key}>"))? + s;
    Some(text[s..e].trim().to_string()).filter(|v| !v.is_empty())
}

/// (name, bundle id, last simulator build's .app) of the project in DIR
pub fn describe(dir: &Path) -> Option<(String, String, Option<PathBuf>)> {
    let p = csproj(dir)?;
    let text = std::fs::read_to_string(&p).ok()?;
    let name = tag(&text, "AssemblyName").unwrap_or_else(|| p.file_stem().unwrap_or_default().to_string_lossy().into_owned());
    let bundle = tag(&text, "ApplicationId").or_else(|| crate::apps::bundle_id(dir)).unwrap_or_default();
    // bin/<Configuration>/<tfm>/iossimulator-arm64/<Name>.app, the newest
    let app = std::fs::read_dir(dir.join("bin")).into_iter().flatten().flatten()
        .flat_map(|c| std::fs::read_dir(c.path()).into_iter().flatten().flatten())
        .map(|t| t.path().join("iossimulator-arm64").join(format!("{name}.app")))
        .filter(|a| a.is_dir())
        .max_by_key(|a| std::fs::metadata(a).and_then(|m| m.modified()).ok());
    Some((name, bundle, app))
}

/// dotnet/build.sh --simulator for the project in DIR
pub fn sim_build_command(dir: &Path, release: bool) -> Command {
    let mut c = crate::dev::command("bash");
    c.arg(crate::dev::fork_dir().join("dotnet/build.sh")).arg("--simulator").args(["-c", if release { "Release" } else { "Debug" }]).arg(dir).current_dir(dir);
    c
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_ios_targets() {
        assert!(targets_ios("<Project><PropertyGroup><TargetFramework>net10.0-ios</TargetFramework></PropertyGroup></Project>"));
        assert!(targets_ios("<TargetFrameworks>net10.0-android;net10.0-ios;net10.0-maccatalyst</TargetFrameworks>"));
        assert!(!targets_ios("<TargetFramework>net10.0</TargetFramework>"));
        assert!(!targets_ios("<TargetFrameworks>net10.0-android</TargetFrameworks>"));
        assert_eq!(tag("<ApplicationId> sim.x86.A </ApplicationId>", "ApplicationId").as_deref(), Some("sim.x86.A"));
    }
}
