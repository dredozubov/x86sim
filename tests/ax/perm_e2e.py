#!/usr/bin/env python3
"""x86Sim: a permission prompt whose app goes away, through the MCP server (x86sim-mcp over stdio) on a running phone,
with tests/apps/x86perm (asks for location, or contacts with the launch argument "contacts", and shows the status).

Apple's own simulator (iOS 27.2, checked with this app on the Mac, 2026-11-25): the prompt STAYS on screen after its app
is terminated (simctl terminate) or SIGKILLed, over the home screen, for location and for contacts; the status stays
"not determined" and the next launch shows the same prompt again. Mach death notifications do reach SpringBoard and
tccd (tests/arm64/deadname.c); keeping the prompt is the system's choice. So this check asserts Apple's behaviour:

  term      location: the app is terminated while the prompt is up; the prompt is still there 2 s later and after 6 s
            (Apple), the status stays 0; the relaunch shows the prompt (one, not two) and status 0; "Don't Allow" then
            answers it and the app sees 2 (denied)
  kill      the same with SIGKILL (x86sim spawn kill -9 inside the device) instead of a terminate
  contacts  contacts prompt, terminated: stays, as on Apple

Usage: tests/ax/perm_e2e.py --phone NAME [--device DIR] [--mcp PATH] [--app PATH] [--out DIR] [--only term,kill,contacts]
Exit status: failed checks. OUT/mcp.log has every call and answer.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixels_e2e import Mcp  # noqa: E402  (the stdio JSON-RPC client)

BID = "com.x86sim.test.x86perm"
LOC = "to use your location"
CON = "to access your contacts"
fails = 0


def check(name, ok, detail=""):
    global fails
    print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail), flush=True)
    if not ok:
        fails += 1


def screen(m):
    t, s, _, _ = m.call("snapshot", json=True)
    return t, (s or {})


def has(t, what):
    return what.lower() in re.sub(r"[“”\"]", "", t).lower().replace("x86perm ", "")


def until(m, pred, timeout):
    """polls snapshots (wait_for matches whole labels; these are parts of one) until pred(text); (ok, text)"""
    end = time.monotonic() + timeout
    while True:
        t, _ = screen(m)
        if pred(t) or time.monotonic() > end:
            return pred(t), t
        time.sleep(0.5)


def prompts(t, prompt):
    return len(re.findall(re.escape(prompt), re.sub(r"[\u201c\u201d\"]", "", t).replace("x86perm ", "")))


def status(t, key):
    v = re.findall(key + r"=(\d+)", t)
    return int(v[-1]) if v else None


def kill9(a, pid):
    xr = os.environ.get("X86SIM_ROOT", ROOT)
    dev = a.device or os.path.join(xr, "var", "device-a64-" + a.phone)
    r = subprocess.run([os.path.join(xr, "cli/x86sim"), "spawn", "--timeout", "20", "/bin/kill", "-9", str(pid)],
                       env=dict(os.environ, X86SIM_DEVICE=dev), capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).strip()


def launch(m, args=()):
    t, s, err, _ = m.call("app_launch", bundle_id=BID, args=list(args), after="none")
    pid = (s or {}).get("pid") or (re.findall(r":\s*(\d+)\s*$", t.split("\n")[0]) or [None])[0]
    return pid, err


def round_(m, a, name, how, prompt, key, args=()):
    m.call("app_terminate", bundle_id=BID, after="none")
    m.call("sim_privacy", action="reset", service="all", bundle_id=BID)
    pid, err = launch(m, args)
    check(name + "-launch", not err and pid, "pid %s" % pid)
    ok, t = until(m, lambda t: has(t, prompt), 30)
    check(name + "-prompt", ok, "")
    t0 = time.monotonic()
    if how == "kill":
        rc, out = kill9(a, pid)
        check(name + "-sigkill", rc == 0, out[-200:])
    else:
        m.call("app_terminate", bundle_id=BID, after="none")
    time.sleep(max(0, 2 - (time.monotonic() - t0)))
    t, _ = screen(m)
    check(name + "-prompt-stays-2s (Apple)", has(t, prompt), "")
    check(name + "-app-gone", status(t, key) is None, "app's label still on screen" if status(t, key) is not None else "")
    time.sleep(4)
    t, _ = screen(m)
    check(name + "-prompt-stays-6s (Apple)", has(t, prompt), "")
    # the next launch: the same prompt again, the status still not determined
    launch(m, args)
    ok, t = until(m, lambda t: status(t, key) is not None, 30)
    check(name + "-relaunch-not-determined (Apple)", status(t, key) == 0, "%s=%s" % (key, status(t, key)))
    n = prompts(t, prompt)
    check(name + "-relaunch-one-prompt (Apple)", n == 1, "%d prompts" % n)
    t, _, err, _ = m.call("tap", target="Don’t Allow")
    if err:
        t, _, err, _ = m.call("tap", target="Don't Allow")
    check(name + "-deny-tap", not err, t.split("\n")[0])
    ok, t = until(m, lambda t: status(t, key) == 2, 15)
    check(name + "-denied-seen", ok, "%s=%s" % (key, status(t, key)))
    ok, t = until(m, lambda t: not has(t, prompt), 5)
    check(name + "-prompt-gone-after-answer", ok, "")
    m.call("app_terminate", bundle_id=BID, after="none")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--app", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim")), "apps/x86perm.app"))
    ap.add_argument("--out", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim")), "perm-e2e"))
    ap.add_argument("--device", default="", help="the phone's folder, for x86sim spawn (default $X86SIM_ROOT/var/device-a64-PHONE)")
    ap.add_argument("--only", default="term,kill,contacts")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    m = Mcp(a.mcp, a.phone, open(os.path.join(a.out, "mcp.log"), "w"))
    _, _, err, _ = m.call("app_install", path=a.app)
    check("install", not err)
    plan = {"term": ("terminate", LOC, "location", ()), "kill": ("kill", LOC, "location", ()),
            "contacts": ("terminate", CON, "contacts", ("contacts",))}
    for name in a.only.split(","):
        how, prompt, key, args = plan[name]
        try:
            round_(m, a, name, how, prompt, key, args)
        except Exception as e:
            check(name, False, "exception %r" % e)
    print("%d failed" % fails)
    sys.exit(min(fails, 100))


if __name__ == "__main__":
    main()
