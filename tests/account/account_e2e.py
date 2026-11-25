#!/usr/bin/env python3
"""x86Sim: end-to-end checks of `x86sim account` (the Apple Account sign-in; no MCP tool on purpose: agents never get
the user's credentials, so this drives the CLI).

    tests/account/account_e2e.py [--offline]

- status --offline --json: the fields the launcher's Settings > Apple Account shows
- login with a made-up Apple ID (example.com) and password: Apple's SRP sign-in runs to the end and fails with
  "wrong Apple ID or password" (needs the network; --offline skips it). It runs with XDG_CONFIG_HOME in a temporary
  directory, so a real session in the keyring is neither used nor touched (the keyring item is only written on success).
- verify-xip: with X86SIM_XIP=Xcode.xip, Apple's signature and checksums check out; a copy with one byte of its
  content changed is refused (the copy goes next to the .xip: about 3 GB for a moment)
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BIN = os.path.join(ROOT, "tools/launcher/target/release/x86sim-account")
fails = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (": " + detail if detail else ""))
    if not ok:
        fails.append(name)


def run(args, env=None, stdin=None):
    p = subprocess.run([BIN] + args, capture_output=True, text=True, env=env, input=stdin, timeout=180)
    return p.returncode, p.stdout + p.stderr


def main():
    offline = "--offline" in sys.argv
    if not os.access(BIN, os.X_OK):
        sys.exit(f"{BIN} not built (cd tools/launcher && cargo build --release)")
    rc, out = run(["status", "--offline", "--json"])
    try:
        st = json.loads(out[out.index("{"):])
        keys = {"signed_in", "apple_id", "store", "downloads", "signing", "renew", "trusted_until"}
        check("status --json fields", keys <= set(st), ", ".join(sorted(keys - set(st))) or f"signed_in={st['signed_in']}")
    except ValueError:
        check("status --json fields", False, out.strip()[:200])
    if offline:
        return
    with tempfile.TemporaryDirectory() as d:
        pw = os.path.join(d, "pw")
        with open(pw, "w") as f:
            f.write("not-the-password\n")
        os.chmod(pw, 0o600)
        env = dict(os.environ, XDG_CONFIG_HOME=d)
        rc, out = run(["login", "nobody.x86sim.test@example.com", "--password-file", pw], env=env, stdin="")
        check("wrong password is reported", rc == 1 and "wrong Apple ID or password" in out, out.strip().splitlines()[-1] if out.strip() else "")
        check("nothing kept after a failed sign-in", not os.path.exists(os.path.join(d, "x86sim/apple-account.json")))
    xip = os.environ.get("X86SIM_XIP")
    if xip:
        rc, out = run(["verify-xip", xip])
        check("verify-xip: Apple's signature", rc == 0 and "signature: ok" in out, out.strip().splitlines()[-1])
        bad = xip + ".damaged-test"
        try:
            subprocess.run(["cp", "--reflink=auto", xip, bad], check=True)
            with open(bad, "r+b") as f:
                f.seek(os.path.getsize(bad) // 2)
                b = f.read(1)
                f.seek(-1, 1)
                f.write(bytes([b[0] ^ 0xFF]))
            rc, out = run(["verify-xip", bad])
            check("verify-xip: a damaged copy is refused", rc != 0 and "doesn't match its checksum" in out, out.strip().splitlines()[-1])
        finally:
            if os.path.exists(bad):
                os.remove(bad)


main()
sys.exit(1 if fails else 0)
