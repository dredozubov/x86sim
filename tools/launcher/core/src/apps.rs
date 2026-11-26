//! Apps on a phone, as `xcrun simctl install|uninstall|launch|listapps`: the requests go to the phone's
//! com.x86sim.openurl job (host/openurl) through cli/x86sim (appinstall.sh / simctl.py), which installs through
//! InstallCoordination -> installd (LaunchServices registers the app, the home screen shows its icon) and launches
//! through FrontBoard. Used by the launcher ("Install app…") and the MCP tools app_install / app_uninstall /
//! app_launch / app_list.
use crate::aot::repo_root;
use crate::instance::Instance;
use anyhow::{bail, Context, Result};
use serde::Serialize;
use std::path::{Path, PathBuf};
use std::process::Command;

fn helper(inst: &Instance, args: &[&str]) -> Result<String> {
    let out = Command::new(repo_root().join("cli/x86sim"))
        .args(&args[..1])
        .arg(&inst.dir)
        .args(&args[1..])
        .current_dir(repo_root())
        // install gets an .app crate::devapp already prepared: appinstall.sh need not look again
        .env("X86SIM_NO_CONVERT", "1")
        .output()
        .context("running cli/x86sim")?;
    let text = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        bail!("{} {}: {}", args[0], args.get(1).unwrap_or(&""), if text.is_empty() { err.trim().to_string() } else { text });
    }
    Ok(text)
}

/// The bundle id in an .app's Info.plist (CFBundleIdentifier), XML or binary plist
pub fn bundle_id(app: &Path) -> Option<String> {
    let out = Command::new("python3")
        .args(["-I", "-c", "import plistlib,sys;print(plistlib.load(open(sys.argv[1],'rb'))['CFBundleIdentifier'])"])
        .arg(app.join("Info.plist"))
        .output()
        .ok()?;
    out.status.success().then(|| String::from_utf8_lossy(&out.stdout).trim().to_string())
}

#[derive(Debug, Clone, Serialize)]
pub struct Installed {
    pub bundle_id: String,
    /// the helper's answer line (install <path> (<bundle id>): ...)
    pub answer: String,
    /// a device build (.ipa, .xcarchive, device .app) converted for the simulator first (crate::devapp)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub converted: Option<crate::devapp::Prepared>,
}

/// Installs an app on a running phone (simctl install): a simulator .app as it is; an .ipa, .xcarchive or device .app
/// after crate::devapp made a simulator .app of it. Returns once installd answered.
pub fn install(inst: &Instance, app: &Path) -> Result<Installed> {
    let app: PathBuf = app.canonicalize().with_context(|| format!("{}", app.display()))?;
    let work = crate::devapp::work_dir().join(format!("install-{}-{}", std::process::id(), std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0)));
    let prep = crate::devapp::prepare(&app, &work);
    let r = prep.and_then(|p| {
        let bundle_id = bundle_id(&p.app).unwrap_or_default();
        let answer = helper(inst, &["install", &p.app.to_string_lossy()])?;
        Ok(Installed { bundle_id, answer, converted: p.converted.then_some(p) })
    });
    let _ = std::fs::remove_dir_all(&work);
    r
}

pub fn uninstall(inst: &Instance, bundle_id: &str) -> Result<String> {
    helper(inst, &["uninstall", bundle_id])
}

/// Opens an app (simctl launch); extra arguments go to the app
pub fn launch(inst: &Instance, bundle_id: &str, args: &[String]) -> Result<String> {
    launch_env(inst, bundle_id, args, &[])
}

/// `launch` with environment variables for the app (simctl launch's SIMCTL_CHILD_*, `x86sim launch --env K=V`)
pub fn launch_env(inst: &Instance, bundle_id: &str, args: &[String], env: &[(String, String)]) -> Result<String> {
    for (k, _) in env {
        anyhow::ensure!(!k.is_empty() && !k.contains('=') && !k.contains('\0'), "environment variable name {k:?}: not empty, no '='");
    }
    let kv: Vec<String> = env.iter().map(|(k, v)| format!("{k}={v}")).collect();
    let mut a = vec!["launch"];
    for e in &kv {
        a.extend(["--env", e.as_str()]);
    }
    // a bundle id that starts with '-' must not be read as an option
    a.extend(["--", bundle_id]);
    a.extend(args.iter().map(|s| s.as_str()));
    helper(inst, &a)
}

/// An app a device has, read from its files (no running phone needed)
#[derive(Clone, Debug, serde::Serialize)]
pub struct AppEntry {
    pub bundle_id: String,
    pub name: String,
    /// installed by the user (else one of Apple's in the runtime)
    pub user: bool,
}

/// The device's apps from disk: what was installed (data/Containers/Bundle/Application) first, then Apple's visible
/// apps in the runtime (RuntimeRoot/Applications: the ones with an icon, not hidden, launchable, no wallpapers), each
/// list by name
pub fn on_disk(inst: &Instance) -> Vec<AppEntry> {
    let mut plists = vec![];
    let user_root = inst.dir.join("data/Containers/Bundle/Application");
    for c in std::fs::read_dir(&user_root).into_iter().flatten().flatten() {
        for a in std::fs::read_dir(c.path()).into_iter().flatten().flatten() {
            if a.path().extension().is_some_and(|e| e == "app") {
                plists.push(("u", a.path().join("Info.plist")));
            }
        }
    }
    for a in std::fs::read_dir(inst.runtime_root.join("Applications")).into_iter().flatten().flatten() {
        if a.path().extension().is_some_and(|e| e == "app") {
            plists.push(("s", a.path().join("Info.plist")));
        }
    }
    if plists.is_empty() {
        return vec![];
    }
    const PY: &str = "import plistlib,sys\nfor a in sys.argv[1:]:\n  k,p=a.split(':',1)\n  try: d=plistlib.load(open(p,'rb'))\n  except Exception: continue\n  if k=='s' and ('hidden' in (d.get('SBAppTags') or []) or d.get('LSApplicationLaunchProhibited') or not (d.get('CFBundleIcons') or d.get('CFBundleIconFiles') or d.get('CFBundleIconName')) or 'Poster' in str(d.get('CFBundleIdentifier'))): continue\n  b=d.get('CFBundleIdentifier')\n  if b: print(k+'\\t'+b+'\\t'+str(d.get('CFBundleDisplayName') or d.get('CFBundleName') or b))";
    let out = std::process::Command::new("python3").args(["-I", "-c", PY]).args(plists.iter().map(|(k, p)| format!("{k}:{}", p.display()))).output();
    let text = out.map(|o| String::from_utf8_lossy(&o.stdout).into_owned()).unwrap_or_default();
    let mut v: Vec<AppEntry> = text
        .lines()
        .filter_map(|l| {
            let mut it = l.splitn(3, '\t');
            let (k, b, n) = (it.next()?, it.next()?, it.next()?);
            Some(AppEntry { bundle_id: b.to_string(), name: n.to_string(), user: k == "u" })
        })
        .collect();
    v.sort_by(|a, b| b.user.cmp(&a.user).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())));
    v.dedup_by(|a, b| a.bundle_id == b.bundle_id);
    v
}

/// Installed apps (simctl listapps): the helper's JSON answer
pub fn list(inst: &Instance) -> Result<String> {
    helper(inst, &["listapps"])
}

/// Stops a running app (simctl terminate)
pub fn terminate(inst: &Instance, bundle_id: &str) -> Result<String> {
    helper(inst, &["terminate", bundle_id])
}
