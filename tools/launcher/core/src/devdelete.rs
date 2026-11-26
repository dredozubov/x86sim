//! Deleting a device from the CLI and the MCP server (`x86sim device delete NAME [--stop]`, `sim_delete`): what
//! instance::delete removes (the device folder, its own Darling prefix, state dir, frame ring, boot log) plus the
//! prefix's overlay work folder next to it (`a64prefix-<name>.workdir`). The kernel's overlayfs leaves a root-owned
//! `private/work` folder in there that the user cannot remove: it goes through pkexec, the privileged helper the
//! launcher's setup uses, only when asked (`privileged`: a password dialog on the user's desktop), else it is reported
//! with the command that removes it.
use crate::aot::scratch;
use crate::instance::{self, Instance, Phase};
use anyhow::{bail, Context, Result};
use serde::Serialize;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Serialize)]
pub struct Deleted {
    pub name: String,
    pub stopped: bool,
    pub removed: Vec<PathBuf>,
    pub freed_bytes: u64,
    /// what could not go (the root-owned overlay work folder without `privileged`), with how to remove it
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub left: Vec<String>,
}

/// The prefix's overlay work folder (darling.c setupWorkdir: `<prefix>.workdir`), when the prefix is this phone's own
pub fn workdir(inst: &Instance) -> Option<PathBuf> {
    let plan = instance::delete_plan(inst);
    let pre = plan.iter().find(|p| p.file_name().is_some_and(|n| n.to_string_lossy().starts_with("a64prefix")))?;
    let w = PathBuf::from(format!("{}.workdir", pre.display()));
    w.symlink_metadata().is_ok().then_some(w)
}

/// What `delete` would remove
pub fn plan(inst: &Instance) -> Vec<PathBuf> {
    let mut v = instance::delete_plan(inst);
    if inst.is_default {
        return v;
    }
    // the prefix may be gone already (a delete that stopped at the work folder): its work folder alone
    let sfx = inst.id.strip_prefix("device-a64").unwrap_or("");
    let own = scratch().join(format!("a64prefix{}.workdir", if sfx.starts_with('-') { sfx.to_string() } else { format!("-{sfx}") }));
    match workdir(inst) {
        Some(w) => v.push(w),
        None if !sfx.is_empty() && own.symlink_metadata().is_ok() => v.push(own),
        None => {}
    }
    v
}

fn size(p: &Path) -> u64 {
    match p.symlink_metadata() {
        Ok(m) if m.is_dir() => crate::host::dir_size(p),
        Ok(m) => m.len(),
        Err(_) => 0,
    }
}

/// A work folder this module may remove as root: `<scratch>/a64prefix-<name>.workdir`, a real folder (no symlink)
fn safe_workdir(p: &Path) -> bool {
    let name = p.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    p.parent() == Some(scratch().as_path())
        && name.starts_with("a64prefix-")
        && name.ends_with(".workdir")
        && !name.contains('/')
        && p.symlink_metadata().is_ok_and(|m| m.is_dir() && !m.file_type().is_symlink())
}

/// Removes the work folder: as the user, then (only `privileged`) as root through pkexec
fn remove_workdir(w: &Path, privileged: bool) -> Result<()> {
    if std::fs::remove_dir_all(w).is_ok() || w.symlink_metadata().is_err() {
        return Ok(());
    }
    anyhow::ensure!(safe_workdir(w), "refusing to remove {} as root: not a prefix work folder in {}", w.display(), scratch().display());
    if !privileged {
        bail!("{} holds a root-owned folder (overlayfs's work dir): remove it with `pkexec rm -rf --one-file-system -- {}` (or pass privileged / --privileged)", w.display(), w.display());
    }
    let out = Command::new("pkexec").args(["rm", "-rf", "--one-file-system", "--"]).arg(w).stdin(Stdio::null()).output().context("pkexec")?;
    match out.status.code() {
        Some(0) => Ok(()),
        Some(126) | Some(127) => bail!("not authorized (the password dialog was cancelled or refused): {} is still there", w.display()),
        _ => bail!("pkexec rm failed: {}", String::from_utf8_lossy(&out.stderr).trim()),
    }
}

/// The phone's state, freshly polled
fn status(inst: &Instance) -> Option<instance::Status> {
    instance::Monitor::default().poll(std::slice::from_ref(inst)).into_iter().next()
}

/// Deletes a device: refuses the default device, and a running one unless `stop` (then it is stopped first and
/// waited for, up to a minute).
pub fn delete(inst: &Instance, stop: bool, privileged: bool) -> Result<Deleted> {
    anyhow::ensure!(!inst.is_default, "{} is the default device: it is never deleted", inst.name);
    let mut st = status(inst);
    let mut stopped = false;
    if st.as_ref().is_some_and(|s| s.phase != Phase::Off || s.launchd_pid.is_some()) {
        if !stop {
            bail!("{} is running: stop it first, or pass stop (--stop) to stop and delete it", inst.name);
        }
        crate::sim::stop(&inst.dir).with_context(|| format!("stopping {}", inst.name))?;
        stopped = true;
        let t0 = Instant::now();
        loop {
            st = status(inst);
            if st.as_ref().is_none_or(|s| s.phase == Phase::Off && s.launchd_pid.is_none()) {
                break;
            }
            anyhow::ensure!(t0.elapsed() < Duration::from_secs(60), "{} did not stop within 60 s", inst.name);
            std::thread::sleep(Duration::from_millis(500));
        }
    }
    let all = plan(inst);
    let freed_before: u64 = all.iter().map(|p| size(p)).sum();
    let w = all.iter().find(|p| p.to_string_lossy().ends_with(".workdir")).cloned();
    if inst.dir.exists() {
        instance::delete(inst, st.as_ref())?;
    }
    let mut left = vec![];
    if let Some(w) = &w {
        if let Err(e) = remove_workdir(w, privileged) {
            left.push(format!("{e:#}"));
        }
    }
    let removed: Vec<PathBuf> = all.into_iter().filter(|p| p.symlink_metadata().is_err()).collect();
    let freed = freed_before.saturating_sub(w.as_ref().filter(|w| w.exists()).map(|w| size(w)).unwrap_or(0));
    Ok(Deleted { name: inst.name.clone(), stopped, removed, freed_bytes: freed, left })
}

impl Deleted {
    pub fn text(&self) -> String {
        let mut s = format!("deleted {}{}: {} path(s), {:.1} MB freed\n", self.name, if self.stopped { " (stopped first)" } else { "" }, self.removed.len(), self.freed_bytes as f64 / 1e6);
        for p in &self.removed {
            s += &format!("  {}\n", p.display());
        }
        for l in &self.left {
            s += &format!("left: {l}\n");
        }
        s
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_prefix_work_folders_go_as_root() {
        let sc = scratch();
        assert!(!safe_workdir(&sc.join("a64prefix-x.workdir/..")));
        assert!(!safe_workdir(Path::new("/")));
        assert!(!safe_workdir(&sc.join("a64prefix-x")));
        assert!(!safe_workdir(&sc.join("jc-24B8117.workdir")));
        // a missing folder is not one either (nothing to run pkexec for)
        assert!(!safe_workdir(&sc.join("a64prefix-does-not-exist-zz.workdir")));
    }
}
