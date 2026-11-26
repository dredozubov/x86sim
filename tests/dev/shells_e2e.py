#!/usr/bin/env python3
"""x86Sim: cross-platform app shells built on Linux (x86sim dev's devweb.rs: the shell's own CLI writes the Xcode
project, Swift Build builds it), run on a phone and driven through x86sim-mcp.

Each check copies the dev toolchain's sample (shells/samples/<name>) to OUT/work/<name>, then dev_run installs its
packages, runs the shell's iOS step, builds the Xcode project with Swift Build, installs and launches the app; the
snapshot must show the app's UI and one tap must change it.

  capacitor  shells/samples/capacitor-hello: Capacitor 8 (Swift-package template). `npx cap add/sync ios` on Linux.
             "Capacitor on x86Sim" in the snapshot (WKWebView content); "Tap me" turns "Taps: 0" into "Taps: 1".

Usage: tests/dev/shells_e2e.py --phone NAME [--start] [--mcp PATH] [--only capacitor,...] [--out DIR]
  --start boots the phone when it is off and stops it at the end. X86SIM_OAD picks the dev toolchain checkout (default:
  external/omarchy-apple-dev). Needs `x86sim dev setup swiftbuild` and node / npm.
Exit status: failed checks.
"""
import argparse
import json
import os
import shutil
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tests/ax"))
from mcp_e2e import Mcp  # noqa: E402

OAD = os.environ.get("X86SIM_OAD") or os.path.join(ROOT, "external/omarchy-apple-dev")

# name: (sample dir, text that shows the UI is up, what to tap, the text the tap brings, use OCR)
SAMPLES = {
    "capacitor": ("shells/samples/capacitor-hello", "Capacitor on x86Sim", "Tap me", "Taps: 1", False),
}
# what a copy of a sample leaves out (each run starts from the sources)
GENERATED = ("node_modules", "ios", "platforms", "plugins", "build", ".godot", "package-lock.json")


class Run:
    def __init__(self, m, out):
        self.m, self.out, self.fails = m, out, []

    def check(self, name, ok, detail=""):
        print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail), flush=True)
        if not ok:
            self.fails.append(name)
        return ok

    def phone_state(self):
        for p in json.loads(self.m.call("phones_list")[0])["phones"]:
            if p.get("name") == self.m.phone:
                return p
        return None

    def labels(self, ocr):
        text, st, err, _ = self.m.call("snapshot", json=True, ocr=ocr)
        if err:
            return text, []
        return text, [(e.get("label") or "") + " " + (e.get("value") or "") for e in (st or {}).get("elements", [])]

    def sample(self, name):
        rel, up, tap, after, ocr = SAMPLES[name]
        proj = os.path.join(self.out, "work", name)
        shutil.rmtree(proj, ignore_errors=True)
        shutil.copytree(os.path.join(OAD, rel), proj, ignore=shutil.ignore_patterns(*GENERATED))
        t0 = time.monotonic()
        text, st, err, dt = self.m.call("dev_run", project=proj, start=True)
        if not self.check(f"{name}: built on Linux, installed and launched", not err, "%.0f s: %s" % (dt, text[-600:].replace("\n", " | "))):
            return
        self.m.call("wait_for", target=up, timeout=120)
        snap, lab = self.labels(ocr)
        seen = (lambda l: up.lower() in l.lower()) if ocr else (lambda l: up in l)
        self.check(f"{name}: the snapshot shows its UI", any(seen(l) for l in lab), "%r in %s" % (up, [l for l in lab if l.strip()][:12]))
        # a web view lists the page's elements before its touch handling is up (first launch after an install: the
        # first tap can go nowhere); give it a moment, and tap once more if the first did nothing (said)
        time.sleep(5)
        for attempt in (1, 2):
            text, _, err, _ = self.m.call("tap", target=tap)
            self.check(f"{name}: tap {tap!r}", not err, text[:200].replace("\n", " | "))
            text, _, err, _ = self.m.call("wait_for", target=after, timeout=20)
            if err:
                _, lab = self.labels(ocr)
                err = not any(after in l for l in lab)
            if not err:
                break
            print(f"note {name}: the tap changed nothing; tapping again", flush=True)
        self.check(f"{name}: the tap changed the app ({after!r})", not err, "%.0f s total" % (time.monotonic() - t0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--start", action="store_true", help="boot the phone if it is off, and stop it at the end")
    ap.add_argument("--only", default=",".join(SAMPLES))
    ap.add_argument("--out", default=os.path.expanduser("~/scratch/shells_e2e"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    m = Mcp(a.mcp, a.phone, open(os.path.join(a.out, "mcp.log"), "w"))
    r = Run(m, a.out)
    started = False
    if a.start and (r.phone_state() or {}).get("state") != "running":
        m.call("sim_start")
        started = True
        t0 = time.monotonic()
        while time.monotonic() - t0 < 900 and (r.phone_state() or {}).get("state") != "running":
            time.sleep(5)
        print("phone %s: %s after %.0f s" % (a.phone, (r.phone_state() or {}).get("state"), time.monotonic() - t0), flush=True)
    try:
        for n in a.only.split(","):
            if n not in SAMPLES:
                sys.exit(f"unknown check {n}: {', '.join(SAMPLES)}")
            r.sample(n)
    finally:
        if started:
            m.call("sim_stop")
        m.close()
    print("%d failed%s" % (len(r.fails), (": " + ", ".join(r.fails)) if r.fails else ""))
    sys.exit(len(r.fails))


if __name__ == "__main__":
    main()
