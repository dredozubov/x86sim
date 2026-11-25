//! Where a phone's frame ring and the host-side sockets next to it live (simhid's short socket, simax's accessibility
//! readers, webinspectord's debugger socket): the rule of cli/lib/x86config.py's run_dir, which mksimdevice.py uses to
//! write SIMFB_RING into a phone's sim.env.
//!   1. `$XDG_RUNTIME_DIR`, when it is a directory this user owns and only this user can write
//!   2. `/run/user/<uid>`, the same (a login session's, or a lingering user's)
//!   3. `/tmp/x86sim-<uid>`, made private (0700) and checked to be this user's: no login session at all (a headless
//!      server, a container, su). Not under ~/.cache: the directory must be short ([`MAX_DIR`]), and a ring on disk
//!      would be written back continuously.
//!
//! A booted phone's ring is read from its sim.env instead ([`ring_from_env`]): a phone the CLI or the MCP server
//! started, from an environment other than this one, still shows. `X86SIM_RUN_USER_BASE` (default /run/user) moves
//! step 2, for tests.
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

/// Linux's / as seen inside Darling
pub const DARLING_VIEW: &str = "/Volumes/SystemRoot";

/// The longest directory that works: the guest binds sockets there through [`DARLING_VIEW`], Darwin's sun_path holds
/// 103 bytes, and the longest name put there (simax's x86sim-ax-<UDID>-<pid>.sock, 59 bytes) leaves this much.
pub const MAX_DIR: usize = 103 - DARLING_VIEW.len() - "/x86sim-ax-".len() - 36 - "-".len() - 7 - ".sock".len();

/// The places the rule looks at, in order (taken from the environment by [`candidates`]; tests pass their own)
#[derive(Debug, Clone)]
pub struct Candidates {
    pub xdg_runtime_dir: Option<PathBuf>,
    pub run_user: PathBuf,
    pub private: PathBuf,
    pub uid: u32,
}

pub fn candidates() -> Candidates {
    // SAFETY: getuid has no preconditions
    let uid = unsafe { libc::getuid() };
    let base = std::env::var_os("X86SIM_RUN_USER_BASE").filter(|v| !v.is_empty()).map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/run/user"));
    Candidates {
        xdg_runtime_dir: std::env::var_os("XDG_RUNTIME_DIR").filter(|v| !v.is_empty()).map(PathBuf::from),
        run_user: base.join(uid.to_string()),
        private: PathBuf::from(format!("/tmp/x86sim-{uid}")),
        uid,
    }
}

fn short(d: &Path) -> bool {
    d.is_absolute() && d.as_os_str().len() <= MAX_DIR
}

/// A directory this user can create files in and nobody else can: a real directory (not a link) owned by `uid`,
/// writable by no group or other user. Writable alone was not enough: root after a plain `su` keeps the user's
/// XDG_RUNTIME_DIR, where that user could plant links for the ring's temporary file (simfb opens it O_CREAT|O_TRUNC
/// without O_NOFOLLOW); an XDG_RUNTIME_DIR of /tmp (some containers) let every user do the same.
fn usable(d: &Path, uid: u32) -> bool {
    use std::os::unix::ffi::OsStrExt;
    use std::os::unix::fs::MetadataExt;
    let Ok(c) = std::ffi::CString::new(d.as_os_str().as_bytes()) else { return false };
    let Ok(m) = std::fs::symlink_metadata(d) else { return false };
    // SAFETY: c is a valid NUL-terminated path
    short(d)
        && m.file_type().is_dir()
        && m.uid() == uid
        && m.mode() & 0o022 == 0
        && unsafe { libc::access(c.as_ptr(), libc::W_OK | libc::X_OK) } == 0
}

/// Makes `d` (in a world-writable /tmp) a directory only `uid` can use: created 0700, or an existing one kept only if
/// it is a real directory (not a link) owned by `uid`, its mode then tightened to 0700.
fn private(d: &Path, uid: u32) -> bool {
    use std::os::unix::fs::{DirBuilderExt, MetadataExt, PermissionsExt};
    if !short(d) {
        return false;
    }
    if let Err(e) = std::fs::DirBuilder::new().mode(0o700).create(d) {
        if e.kind() != std::io::ErrorKind::AlreadyExists {
            return false;
        }
    }
    let Ok(m) = std::fs::symlink_metadata(d) else { return false };
    if !m.file_type().is_dir() || m.uid() != uid {
        return false;
    }
    m.mode() & 0o077 == 0 || std::fs::set_permissions(d, std::fs::Permissions::from_mode(0o700)).is_ok()
}

/// The rule (module docs) over the given places; None when none works (the private directory is someone else's).
pub fn pick(c: &Candidates) -> Option<PathBuf> {
    if let Some(x) = c.xdg_runtime_dir.as_ref().filter(|x| usable(x, c.uid)) {
        return Some(x.clone());
    }
    if usable(&c.run_user, c.uid) {
        return Some(c.run_user.clone());
    }
    private(&c.private, c.uid).then(|| c.private.clone())
}

/// This process's run directory (decided once): [`pick`] over [`candidates`], else /run/user/<uid> (nothing better;
/// a boot reports the problem)
pub fn run_dir() -> &'static Path {
    static DIR: OnceLock<PathBuf> = OnceLock::new();
    DIR.get_or_init(|| {
        let c = candidates();
        pick(&c).unwrap_or(c.run_user)
    })
}

/// A ring file's name for a phone: device-a64 -> x86sim-a64-simfb.ring, device-a64-b -> x86sim-a64-b-simfb.ring
pub fn ring_name(id: &str) -> String {
    format!("x86sim-{}-simfb.ring", id.strip_prefix("device-").unwrap_or(id))
}

/// The ring a phone's last boot wrote (its sim.env SIMFB_RING, a Linux path under [`DARLING_VIEW`]), when that is this
/// phone's own ring (named after it), else `default`. A ring named after another phone is a sim.env copied from it:
/// passing that on at start had one phone drawing into another's ring.
pub fn ring_from_env(id: &str, env: &HashMap<String, String>, default: PathBuf) -> PathBuf {
    let name = ring_name(id);
    env.get("SIMFB_RING")
        .and_then(|r| r.strip_prefix(DARLING_VIEW))
        .map(PathBuf::from)
        .filter(|p| p.is_absolute() && p.file_name().is_some_and(|n| n.to_str() == Some(&name)))
        .unwrap_or(default)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::{MetadataExt, PermissionsExt};

    /// A fresh short directory under /tmp (the rule's paths must stay within MAX_DIR)
    fn scratch(tag: &str) -> PathBuf {
        let d = PathBuf::from(format!("/tmp/xrd-{}-{tag}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    fn me() -> u32 {
        unsafe { libc::getuid() }
    }

    #[test]
    fn max_dir_fits_run_user() {
        assert_eq!(MAX_DIR, 24);
        assert!(short(Path::new("/run/user/4294967295")));
        assert!(short(Path::new("/tmp/x86sim-4294967295")));
    }

    #[test]
    fn xdg_runtime_dir_first() {
        let s = scratch("a");
        let (x, r) = (s.join("x"), s.join("r"));
        std::fs::create_dir_all(&x).unwrap();
        std::fs::create_dir_all(&r).unwrap();
        let c = Candidates { xdg_runtime_dir: Some(x.clone()), run_user: r.clone(), private: s.join("p"), uid: me() };
        assert_eq!(pick(&c), Some(x));
        // unset, or not a directory: /run/user/<uid>
        assert_eq!(pick(&Candidates { xdg_runtime_dir: None, ..c.clone() }), Some(r.clone()));
        assert_eq!(pick(&Candidates { xdg_runtime_dir: Some(s.join("gone")), ..c.clone() }), Some(r));
        std::fs::remove_dir_all(&s).unwrap();
    }

    #[test]
    fn private_dir_when_nothing_else() {
        let s = scratch("b");
        let p = s.join("p");
        let c = Candidates { xdg_runtime_dir: None, run_user: s.join("no-run-user"), private: p.clone(), uid: me() };
        assert_eq!(pick(&c), Some(p.clone()));
        assert_eq!(std::fs::metadata(&p).unwrap().mode() & 0o777, 0o700);
        // an existing one too open is tightened
        std::fs::set_permissions(&p, std::fs::Permissions::from_mode(0o755)).unwrap();
        assert_eq!(pick(&c), Some(p.clone()));
        assert_eq!(std::fs::metadata(&p).unwrap().mode() & 0o777, 0o700);
        std::fs::remove_dir_all(&s).unwrap();
    }

    #[test]
    fn private_dir_refuses_links_and_strangers() {
        let s = scratch("c");
        let target = s.join("t");
        std::fs::create_dir_all(&target).unwrap();
        let link = s.join("l");
        std::os::unix::fs::symlink(&target, &link).unwrap();
        let c = Candidates { xdg_runtime_dir: None, run_user: s.join("none"), private: link, uid: me() };
        assert_eq!(pick(&c), None);
        // owned by someone else
        let c = Candidates { private: target, uid: me().wrapping_add(1), ..c };
        assert_eq!(pick(&c), None);
        std::fs::remove_dir_all(&s).unwrap();
    }

    #[test]
    fn shared_or_foreign_runtime_dir_skipped() {
        let s = scratch("e");
        let (x, r) = (s.join("x"), s.join("r"));
        std::fs::create_dir_all(&x).unwrap();
        std::fs::create_dir_all(&r).unwrap();
        // writable by others (an XDG_RUNTIME_DIR of /tmp): skipped
        std::fs::set_permissions(&x, std::fs::Permissions::from_mode(0o1777)).unwrap();
        let c = Candidates { xdg_runtime_dir: Some(x.clone()), run_user: r.clone(), private: s.join("p"), uid: me() };
        assert_eq!(pick(&c), Some(r.clone()));
        // another user's (root after su keeps the user's XDG_RUNTIME_DIR): skipped, down to the private one
        std::fs::set_permissions(&x, std::fs::Permissions::from_mode(0o700)).unwrap();
        let other = Candidates { uid: me().wrapping_add(1), private: s.join("q"), ..c.clone() };
        assert!(!usable(&x, other.uid) && !usable(&r, other.uid));
        // a link to a good directory: skipped
        let link = s.join("l");
        std::os::unix::fs::symlink(&r, &link).unwrap();
        assert!(!usable(&link, me()));
        std::fs::remove_dir_all(&s).unwrap();
    }

    #[test]
    fn too_long_skipped() {
        let s = scratch("d");
        let long = s.join("a-directory-name-too-long-for-sockets");
        std::fs::create_dir_all(&long).unwrap();
        let c = Candidates { xdg_runtime_dir: Some(long), run_user: s.join("none"), private: s.join("p"), uid: me() };
        assert_eq!(pick(&c), Some(s.join("p")));
        std::fs::remove_dir_all(&s).unwrap();
    }

    #[test]
    fn ring_from_sim_env() {
        let env = |v: &str| HashMap::from([("SIMFB_RING".to_string(), v.to_string())]);
        let def = PathBuf::from("/run/user/1/x86sim-a64-b-simfb.ring");
        assert_eq!(ring_name("device-a64-b"), "x86sim-a64-b-simfb.ring");
        // this phone's ring wherever its boot put it
        assert_eq!(ring_from_env("device-a64-b", &env("/Volumes/SystemRoot/tmp/x86sim-1/x86sim-a64-b-simfb.ring"), def.clone()), PathBuf::from("/tmp/x86sim-1/x86sim-a64-b-simfb.ring"));
        // another phone's (a copied sim.env), a guest path, or none: the default
        assert_eq!(ring_from_env("device-a64-b", &env("/Volumes/SystemRoot/run/user/1/x86sim-a64-simfb.ring"), def.clone()), def);
        assert_eq!(ring_from_env("device-a64-b", &env("/run/user/1/x86sim-a64-b-simfb.ring"), def.clone()), def);
        assert_eq!(ring_from_env("device-a64-b", &HashMap::new(), def.clone()), def);
    }
}
