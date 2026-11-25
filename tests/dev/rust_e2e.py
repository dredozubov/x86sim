#!/usr/bin/env python3
"""x86Sim: Rust iOS apps built on Linux (the dev toolchain's rust/), run on a phone and driven through x86sim-mcp.

Each check: dev_run builds the sample with cargo for aarch64-apple-ios-sim (rust/build.py: the Darwin SDK, ld64.lld,
the .app around the binary), installs and launches it; then the app's UI is read and tapped through MCP.

  hello    rust/samples/hello-uikit: UIKit from Rust (objc2). The snapshot shows "Hello from Rust"; tapping
           "Tap me" turns "Taps: 0" into "Taps: 1".
  tauri    rust/samples/tauri-hello: Tauri 2 (tao + WKWebView, Tauri's Swift half built with Linux Swift). The page's
           heading is in the snapshot; tapping "Greet" calls the Rust command, whose answer appears on the page.
  dioxus   rust/samples/dioxus-hello: Dioxus mobile (tao + WKWebView, no dx). "Dioxus on x86Sim" in the snapshot; a
           tap on "Count" turns "Count: 0" into "Count: 1".

Usage: tests/dev/rust_e2e.py --phone NAME [--start] [--mcp PATH] [--only hello,...] [--out DIR]
  --start boots the phone when it is off and stops it at the end. X86SIM_OAD picks the dev toolchain checkout (default: external/omarchy-apple-dev).
Exit status: failed checks.
"""
import argparse
import json
import os
import re
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tests/ax"))
from mcp_e2e import Mcp  # noqa: E402

OAD = os.environ.get("X86SIM_OAD") or os.path.join(ROOT, "external/omarchy-apple-dev")

# name: (sample dir, text that shows the UI is up, what to tap, the text the tap brings, use OCR)
SAMPLES = {
    "hello": ("rust/samples/hello-uikit", "Hello from Rust", "Tap me", "Taps: 1", False),
    "tauri": ("rust/samples/tauri-hello", "Tauri on x86Sim", "Greet", "Hello from Rust, x86Sim!", False),
    "dioxus": ("rust/samples/dioxus-hello", "Dioxus on x86Sim", "Count", "Count: 1", False),
}


class Run:
    def __init__(self, m):
        self.m, self.fails = m, []

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
        proj = os.path.join(OAD, rel)
        t0 = time.monotonic()
        text, st, err, dt = self.m.call("dev_run", project=proj)
        if not self.check(f"{name}: built on Linux, installed and launched", not err, "%.0f s: %s" % (dt, text[-600:].replace("\n", " | "))):
            return
        self.m.call("wait_for", target=up, timeout=120)
        snap, lab = self.labels(ocr)
        self.check(f"{name}: the snapshot shows its UI", any(up in l for l in lab), "%r in %s" % (up, [l for l in lab if l.strip()][:12]))
        text, _, err, _ = self.m.call("tap", target=tap)
        self.check(f"{name}: tap {tap!r}", not err, text[:200].replace("\n", " | "))
        text, _, err, _ = self.m.call("wait_for", target=after, timeout=30)
        if err:
            _, lab = self.labels(ocr)
            err = not any(after in l for l in lab)
        self.check(f"{name}: the tap changed the app ({after!r})", not err, "%.0f s total" % (time.monotonic() - t0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--start", action="store_true", help="boot the phone if it is off, and stop it at the end")
    ap.add_argument("--only", default=",".join(SAMPLES))
    ap.add_argument("--out", default=os.path.expanduser("~/scratch/rust_e2e"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    log = open(os.path.join(a.out, "mcp.log"), "w")
    m = Mcp(a.mcp, a.phone, log)
    r = Run(m)
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
