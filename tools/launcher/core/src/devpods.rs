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

// ---------------------------------------------------------------------------------------------------------------
// React Native and Expo apps: package.json with react-native (kind "reactnative") or expo (kind "expo"). The iOS
// part comes from `expo prebuild` (or the app's own ios/), its pods from `pod install`, the build from the fork's
// tools/xcbuild.py (the CocoaPods workspace built on Linux); Debug builds load their JavaScript from Metro on this
// computer (localhost:8081, which the phones reach as their own localhost).

/// "expo", "reactnative" or None, from DIR/package.json
pub fn js_kind(dir: &Path) -> Option<&'static str> {
    let pj: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(dir.join("package.json")).ok()?).ok()?;
    let has = |n: &str| ["dependencies", "devDependencies"].iter().any(|k| pj[k].get(n).is_some());
    if has("expo") {
        Some("expo")
    } else if has("react-native") {
        Some("reactnative")
    } else {
        None
    }
}

/// The ios/ workspace pod install made: (ios dir, workspace, scheme)
fn workspace(dir: &Path) -> Option<(PathBuf, PathBuf, String)> {
    let ios = dir.join("ios");
    let ws = std::fs::read_dir(&ios).ok()?.flatten().map(|e| e.path()).find(|p| p.extension().is_some_and(|x| x == "xcworkspace"))?;
    let scheme = ws.file_stem()?.to_string_lossy().into_owned();
    Some((ios, ws, scheme))
}

/// The last simulator build's .app
pub fn last_app(dir: &Path) -> Option<PathBuf> {
    let products = dir.join("ios/build/xcbuild/Build/Products");
    let mut apps: Vec<PathBuf> = std::fs::read_dir(&products)
        .into_iter()
        .flatten()
        .flatten()
        .filter(|e| e.file_name().to_string_lossy().ends_with("-iphonesimulator"))
        .flat_map(|e| std::fs::read_dir(e.path()).into_iter().flatten().flatten().map(|a| a.path()))
        .filter(|p| p.extension().is_some_and(|x| x == "app"))
        .collect();
    apps.sort_by_key(|p| std::fs::metadata(p).and_then(|m| m.modified()).ok());
    apps.pop()
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

fn step(c: Command, what: &str, say: &mut dyn FnMut(&str)) -> Result<()> {
    say(&format!("== {what}"));
    let rc = dev::stream(c, say)?;
    anyhow::ensure!(rc == 0, "{what} failed (exit {rc})");
    Ok(())
}

/// node_modules, ios/ (expo prebuild), pods: what the build needs, done when missing or out of date
pub fn prepare(dir: &Path, kind: &str, say: &mut dyn FnMut(&str)) -> Result<()> {
    if !dir.join("node_modules").is_dir() {
        let pm = package_manager(dir);
        let mut c = dev::command(pm);
        c.arg("install").current_dir(dir);
        step(c, &format!("{pm} install"), say)?;
    }
    if kind == "expo" && !dir.join("ios").is_dir() {
        let mut c = dev::command("npx");
        c.args(["expo", "prebuild", "--platform", "ios", "--no-install"]).current_dir(dir).env("CI", "1");
        step(c, "expo prebuild --platform ios", say)?;
    }
    let ios = dir.join("ios");
    anyhow::ensure!(ios.join("Podfile").exists(), "{}: no ios/Podfile (a React Native app has one; Expo makes one with expo prebuild)", dir.display());
    let lock = std::fs::read(ios.join("Podfile.lock")).ok();
    let manifest = std::fs::read(ios.join("Pods/Manifest.lock")).ok();
    let mtime = |p: PathBuf| std::fs::metadata(p).and_then(|m| m.modified()).ok();
    let stale = lock.is_none() || lock != manifest || mtime(ios.join("Podfile")) > mtime(ios.join("Pods/Manifest.lock")) || workspace(dir).is_none();
    if stale {
        anyhow::ensure!(pod().is_some(), "CocoaPods is not installed: x86sim dev setup cocoapods");
        step(pod_command(&ios, &["install".into()])?, "pod install", say)?;
    }
    Ok(())
}

/// Simulator (or, with sdk iphoneos, device) build of a React Native / Expo app: the .app
pub fn build(dir: &Path, kind: &str, sdk: &str, release: bool, say: &mut dyn FnMut(&str)) -> Result<PathBuf> {
    prepare(dir, kind, say)?;
    let (ios, ws, scheme) = workspace(dir).context_msg("no .xcworkspace in ios/ after pod install")?;
    let mut c = dev::command("python3");
    c.arg(dev::fork_dir().join("tools/xcbuild.py"))
        .arg("-workspace")
        .arg(&ws)
        .args(["-scheme", &scheme, "-sdk", sdk, "-configuration", if release { "Release" } else { "Debug" }])
        .current_dir(&ios);
    if std::env::var_os("XCBUILD_JOBS").is_none() {
        c.args(["-jobs", "4"]);
    }
    say(&format!("== build {scheme} ({sdk}, {})", if release { "Release" } else { "Debug" }));
    let mut app = None;
    let rc = dev::stream(c, &mut |l: &str| {
        if let Some(a) = l.strip_prefix("app: ") {
            app = Some(PathBuf::from(a.trim()));
        }
        // ld64.lld says this for every image; it is not news
        if !l.contains("does not support linking for platform") {
            say(l);
        }
    })?;
    anyhow::ensure!(rc == 0, "the build failed (exit {rc})");
    app.context_msg("the build named no .app")
}

trait ContextMsg<T> {
    fn context_msg(self, m: &str) -> Result<T>;
}
impl<T> ContextMsg<T> for Option<T> {
    fn context_msg(self, m: &str) -> Result<T> {
        self.ok_or_else(|| anyhow::anyhow!("{m}"))
    }
}

/// Metro's answer on port 8081 (any app's Metro)
pub fn metro_running() -> bool {
    use std::io::{Read, Write};
    let Ok(mut s) = std::net::TcpStream::connect_timeout(&"127.0.0.1:8081".parse().unwrap(), std::time::Duration::from_secs(1)) else { return false };
    let _ = s.set_read_timeout(Some(std::time::Duration::from_secs(3)));
    let _ = s.write_all(b"GET /status HTTP/1.0\r\nHost: localhost\r\n\r\n");
    let mut b = String::new();
    let _ = s.read_to_string(&mut b);
    b.contains("packager-status:running")
}

fn metro_files(dir: &Path) -> (PathBuf, PathBuf) {
    let name = dir.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    (dev::work_dir().join(format!("metro-{name}.log")), dev::work_dir().join(format!("metro-{name}.pid")))
}

/// Starts Metro for the app (expo start / react-native start) in the background unless one answers on 8081.
/// Its log and pid are in the dev work dir; it keeps running for edits (Fast Refresh) until `x86sim dev metro --stop`.
pub fn start_metro(dir: &Path, kind: &str, say: &mut dyn FnMut(&str)) -> Result<()> {
    if metro_running() {
        say("Metro already answers on localhost:8081");
        return Ok(());
    }
    let (log, pidf) = metro_files(dir);
    std::fs::create_dir_all(dev::work_dir())?;
    let mut c = dev::command("setsid");
    c.arg("npx");
    if kind == "expo" {
        c.args(["expo", "start", "--port", "8081"]);
    } else {
        c.args(["react-native", "start", "--port", "8081"]);
    }
    c.current_dir(dir).env("BROWSER", "none").env("EXPO_NO_TELEMETRY", "1").env_remove("CI");
    let f = std::fs::File::create(&log)?;
    c.stdin(std::process::Stdio::null()).stdout(f.try_clone()?).stderr(f);
    let child = c.spawn().map_err(|e| anyhow::anyhow!("starting Metro: {e}"))?;
    std::fs::write(&pidf, child.id().to_string())?;
    std::thread::spawn(move || {
        let mut c = child;
        let _ = c.wait();
    });
    say(&format!("== Metro (log {})", log.display()));
    for _ in 0..90 {
        if metro_running() {
            return Ok(());
        }
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
    anyhow::bail!("Metro did not answer on localhost:8081 within 90 s (log: {})", log.display())
}

/// Stops the Metro this module started for DIR (its process group, by the recorded pid)
pub fn stop_metro(dir: &Path) -> Result<bool> {
    let (_, pidf) = metro_files(dir);
    let Some(pid) = std::fs::read_to_string(&pidf).ok().and_then(|s| s.trim().parse::<i32>().ok()) else { return Ok(false) };
    unsafe {
        libc::kill(-pid, libc::SIGTERM);
    }
    let _ = std::fs::remove_file(pidf);
    Ok(true)
}

/// Reloads the JavaScript of every app connected to Metro (what `r` in Metro's terminal does)
pub fn reload() -> Result<()> {
    use std::io::{Read, Write};
    anyhow::ensure!(metro_running(), "Metro is not running on localhost:8081 (x86sim dev run starts it)");
    let mut s = std::net::TcpStream::connect("127.0.0.1:8081")?;
    s.write_all(b"POST /reload HTTP/1.0\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n")?;
    let mut b = String::new();
    let _ = s.read_to_string(&mut b);
    anyhow::ensure!(b.starts_with("HTTP/1.1 200") || b.starts_with("HTTP/1.0 200"), "Metro refused the reload: {}", b.lines().next().unwrap_or(""));
    Ok(())
}
