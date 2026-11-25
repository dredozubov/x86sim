"""x86Sim: the same configuration as cli/lib/config.sh, for the Python tools (it runs config.sh and reads the result)."""
import os
import subprocess

ROOT = os.environ.get("X86SIM_ROOT") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_cfg = None


def load():
    global _cfg
    if _cfg is None:
        env = dict(os.environ, X86SIM_ROOT=ROOT)
        out = subprocess.run(["sh", "-c", '. "$1" >/dev/null 2>&1; env -0', "sh", os.path.join(ROOT, "cli/lib/config.sh")],
                             env=env, capture_output=True, check=True).stdout
        _cfg = dict(kv.split("=", 1) for kv in out.decode().split("\0") if "=" in kv)
    return _cfg


def get(key):
    return load()[key]


def device():
    return get("X86SIM_DEVICE")


def data():
    return os.path.join(device(), "data")


# Where a phone's frame ring and the host-side sockets next to it live (simhid's short socket, simax's accessibility
# readers, webinspectord's debugger socket). The launcher picks the same (tools/launcher/core/src/rundir.rs) but reads a
# booted phone's actual ring from its sim.env (SIMFB_RING), so a phone started from another environment still shows.
#   1. $XDG_RUNTIME_DIR, when it is a directory this user can write
#   2. /run/user/<uid>, the same (a login session's, or a lingering user's)
#   3. /tmp/x86sim-<uid>, made private (0700) and checked to be this user's: no login session at all (a headless
#      server, a container, su). Not under ~/.cache: the directory must be short (see RUN_DIR_MAX), and a ring on disk
#      would be written back continuously.
# The guest binds those sockets through Darling's /Volumes/SystemRoot, and Darwin's sun_path holds 103 bytes: the
# longest name put there (simax's x86sim-ax-<UDID>-<pid>.sock, 59 bytes) leaves RUN_DIR_MAX for the directory.
# X86SIM_RUN_USER_BASE (default /run/user) moves step 2, for tests.
RUN_DIR_MAX = 103 - len("/Volumes/SystemRoot") - len("/x86sim-ax-") - 36 - len("-") - 7 - len(".sock")
_run_dir = None


def _usable_dir(d):
    return bool(d) and os.path.isabs(d) and len(d) <= RUN_DIR_MAX and os.path.isdir(d) and \
        os.access(d, os.W_OK | os.X_OK)


def _private_dir(d):
    import stat
    if len(d) > RUN_DIR_MAX:
        return False
    try:
        os.mkdir(d, 0o700)
    except FileExistsError:
        pass
    except OSError:
        return False
    st = os.lstat(d)
    if not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid():
        return False
    if st.st_mode & 0o077:
        os.chmod(d, 0o700)
    return True


def run_dir():
    global _run_dir
    if _run_dir is None:
        uid = os.getuid()
        for d in (os.environ.get("XDG_RUNTIME_DIR", ""),
                  os.path.join(os.environ.get("X86SIM_RUN_USER_BASE") or "/run/user", str(uid))):
            if _usable_dir(d):
                _run_dir = d
                break
        else:
            d = "/tmp/x86sim-%d" % uid
            if not _private_dir(d):
                raise SystemExit("x86sim: no directory for the frame ring: XDG_RUNTIME_DIR and /run/user/%d are "
                                 "missing and %s is not this user's" % (uid, d))
            _run_dir = d
    return _run_dir
