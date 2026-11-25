//! x86Sim in the desktop's app menu, for the AppImage: a freedesktop.org desktop entry and its icon under
//! $XDG_DATA_HOME (~/.local/share/applications/x86sim.desktop, after the window's app id so docks match the window to
//! it). GNOME, KDE, Xfce and launchers such as Walker, rofi or fuzzel list it.
//!
//! The entry runs a link in the data dir, `<data>/x86sim.AppImage`, not the AppImage itself: a self-update names a
//! versioned AppImage after the new release and deletes the old file (update.rs), which would leave an entry pointing
//! at it broken. The link follows: AppRun re-points it at each start ($APPIMAGE) and update::install after a swap.
//! An x86sim.desktop that this did not write (a distro package, a hand-made one) is left alone.
//!
//! `x86sim.AppImage install-desktop` / `uninstall-desktop` (AppRun), or the setup page.
use anyhow::{bail, Context, Result};
use std::path::{Path, PathBuf};

/// The line that marks an entry as ours
pub const MARK: &str = "X-X86Sim-Managed=true";
const TEMPLATE: &str = include_str!("../../../../build/release/x86sim.desktop");
const ICON: &[u8] = include_bytes!("../../../../build/release/x86sim.png");

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum State {
    /// no x86sim.desktop
    Absent,
    /// ours
    Installed,
    /// an x86sim.desktop we did not write
    Foreign,
}

fn data_home() -> PathBuf {
    std::env::var_os("XDG_DATA_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| std::env::var_os("HOME").map(PathBuf::from).unwrap_or_default().join(".local/share"))
}

pub fn entry_path() -> PathBuf {
    data_home().join("applications/x86sim.desktop")
}

pub fn icon_path() -> PathBuf {
    data_home().join("icons/hicolor/256x256/apps/x86sim.png")
}

/// The link the entry runs (in the data dir, AppRun's X86SIM_ROOT)
pub fn link_path() -> PathBuf {
    crate::aot::repo_root().join("x86sim.AppImage")
}

/// The running AppImage file, when there is one to put in the menu
pub fn appimage() -> Option<PathBuf> {
    crate::update::running_appimage()
}

fn is_ours(text: &str) -> bool {
    text.lines().any(|l| l.trim() == MARK)
}

pub fn state() -> State {
    match std::fs::read_to_string(entry_path()) {
        Ok(t) if is_ours(&t) => State::Installed,
        Ok(_) => State::Foreign,
        Err(_) if entry_path().symlink_metadata().is_ok() => State::Foreign,
        Err(_) => State::Absent,
    }
}

/// The entry for `exec`: the AppImage's own (build/release/x86sim.desktop) with Exec and TryExec naming it, and the mark
pub fn render(exec: &Path) -> Result<String> {
    let e = exec.to_str().context("the path is not UTF-8")?;
    // Exec takes the path quoted; the spec's escapes inside quotes are not worth carrying for paths that need them
    if !exec.is_absolute() || e.contains(['"', '`', '$', '\\', '%', '\n']) {
        bail!("can't name {e} in a desktop entry (it must be absolute, without \" ` $ \\ %)");
    }
    let mut out = String::new();
    let mut group = "";
    let mut added = false;
    let ours = |out: &mut String, added: &mut bool| {
        if !*added {
            out.push_str(&format!("Exec=\"{e}\"\nTryExec={e}\n{MARK}\n"));
            *added = true;
        }
    };
    for l in TEMPLATE.lines() {
        if l.starts_with('[') {
            if group == "[Desktop Entry]" {
                ours(&mut out, &mut added);
            }
            group = l.trim();
        } else if group == "[Desktop Entry]" && (l.starts_with("Exec=") || l.starts_with("TryExec=") || l.starts_with("X-X86Sim-")) {
            continue;
        }
        out.push_str(l);
        out.push('\n');
    }
    ours(&mut out, &mut added);
    Ok(out)
}

/// Atomic write: a temp file menus ignore (no .desktop suffix), renamed over
fn put(path: &Path, bytes: &[u8]) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    let dir = path.parent().context("no folder")?;
    std::fs::create_dir_all(dir).with_context(|| format!("creating {}", dir.display()))?;
    let tmp = dir.join(format!(".{}.new", path.file_name().unwrap_or_default().to_string_lossy()));
    std::fs::write(&tmp, bytes).with_context(|| format!("writing {}", tmp.display()))?;
    std::fs::set_permissions(&tmp, std::fs::Permissions::from_mode(0o644))?;
    std::fs::rename(&tmp, path).with_context(|| format!("writing {}", path.display()))
}

/// Points `link` at `target` (atomically: a new link renamed over the old)
fn relink(link: &Path, target: &Path) -> Result<()> {
    let tmp = link.with_extension("AppImage.new");
    let _ = std::fs::remove_file(&tmp);
    std::os::unix::fs::symlink(target, &tmp).with_context(|| format!("linking {}", tmp.display()))?;
    std::fs::rename(&tmp, link).with_context(|| format!("linking {}", link.display()))
}

/// After an AppImage moved (a self-update's new name): the menu's link follows, if the menu entry is ours
pub fn follow(appimage: &Path) {
    if state() == State::Installed && link_path().symlink_metadata().is_ok() {
        let _ = relink(&link_path(), appimage);
    }
}

/// Let menus that cache entries see a change now rather than at the next login (both tools optional)
fn refresh_menus() {
    let q = |cmd: &str, args: &[&std::ffi::OsStr]| {
        let _ = std::process::Command::new(cmd).args(args).stdout(std::process::Stdio::null()).stderr(std::process::Stdio::null()).status();
    };
    let apps = data_home().join("applications");
    q("update-desktop-database", &[std::ffi::OsStr::new("-q"), apps.as_os_str()]);
    // an icon cache only exists if something made one; a stale one would hide the new icon
    let hicolor = data_home().join("icons/hicolor");
    if hicolor.join("icon-theme.cache").exists() {
        q("gtk-update-icon-cache", &[std::ffi::OsStr::new("-q"), std::ffi::OsStr::new("-f"), std::ffi::OsStr::new("-t"), hicolor.as_os_str()]);
    }
}

/// Adds x86Sim to the app menu for `appimage` (the running AppImage file). Returns the entry's path.
pub fn install(appimage: &Path) -> Result<PathBuf> {
    if state() == State::Foreign {
        bail!("{} exists and x86Sim did not write it; left as it is", entry_path().display());
    }
    anyhow::ensure!(appimage.is_file(), "no AppImage at {}", appimage.display());
    let link = link_path();
    let text = render(&link)?;
    relink(&link, appimage)?;
    put(&icon_path(), ICON)?;
    put(&entry_path(), text.as_bytes())?;
    refresh_menus();
    Ok(entry_path())
}

/// Takes x86Sim out of the app menu (only an entry it wrote). Returns whether there was one.
pub fn uninstall() -> Result<bool> {
    if state() != State::Installed {
        return Ok(false);
    }
    std::fs::remove_file(entry_path()).with_context(|| format!("removing {}", entry_path().display()))?;
    let _ = std::fs::remove_file(icon_path());
    if link_path().symlink_metadata().is_ok_and(|m| m.file_type().is_symlink()) {
        let _ = std::fs::remove_file(link_path());
    }
    refresh_menus();
    Ok(true)
}

/// `x86sim-launcher install-desktop|uninstall-desktop` (AppRun's commands of the same names): prints what happened.
/// None: not one of these.
pub fn command(arg: &str) -> Option<Result<String>> {
    Some(match arg {
        "install-desktop" => appimage()
            .context("not running from the x86Sim AppImage ($APPIMAGE): nothing to put in the menu")
            .and_then(|a| install(&a))
            .map(|p| format!("x86Sim is in the app menu ({}); it starts {}", p.display(), link_path().display())),
        "uninstall-desktop" => uninstall().map(|was| {
            if was {
                format!("removed {}", entry_path().display())
            } else if state() == State::Foreign {
                format!("{} was not written by x86Sim; left as it is", entry_path().display())
            } else {
                "x86Sim is not in the app menu".into()
            }
        }),
        _ => return None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn entry_names_the_link() {
        let t = render(Path::new("/home/a b/.local/share/x86sim/x86sim.AppImage")).unwrap();
        assert!(t.starts_with("[Desktop Entry]\n"));
        assert!(t.contains("\nExec=\"/home/a b/.local/share/x86sim/x86sim.AppImage\"\n"));
        assert!(t.contains("\nTryExec=/home/a b/.local/share/x86sim/x86sim.AppImage\n"));
        assert!(t.contains("\nIcon=x86sim\n") && t.contains("\nStartupWMClass=x86sim\n"));
        assert_eq!(t.matches("Exec=").count(), 2, "one Exec and one TryExec: {t}");
        assert!(is_ours(&t));
        assert!(!is_ours(TEMPLATE));
        assert!(render(Path::new("/x/$HOME/a")).is_err());
        assert!(render(Path::new("x86sim.AppImage")).is_err());
    }
}
