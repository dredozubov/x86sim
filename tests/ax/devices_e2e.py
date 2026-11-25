#!/usr/bin/env python3
"""x86Sim: end-to-end checks of the device and app tools (round 2) through x86sim-mcp:

  delete   sim_add_device + sim_start a scratch device, sim_delete refuses it running, deletes it with stop=true:
           its folder, state dir, prefix and ring are gone; the overlay's root-owned work folder is reported (or
           removed with --privileged, which needs a person at the password dialog)

Usage: tests/ax/devices_e2e.py --phone NAME [--mcp PATH] [--only delete,...] [--out DIR] [--app PATH]
  --phone: a running phone of yours for the app checks; delete makes and deletes <phone>-del itself.
Exit status: failed checks.
"""
import argparse
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_e2e import Mcp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
APP = "com.x86sim.test.x86forms"


class Run:
    def __init__(self, m, app):
        self.m, self.app, self.fails = m, app, []

    def check(self, name, ok, detail=""):
        print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail), flush=True)
        if not ok:
            self.fails.append(name)

    def phone_state(self, name):
        for p in json.loads(self.m.call("phones_list")[0])["phones"]:
            if p.get("name") == name:
                return p
        return None

    # -- delete
    def delete(self):
        name = self.m.phone + "-del"
        if self.phone_state(name):
            self.m.call("sim_delete", phone=name, stop=True)
        text, st, err, _ = self.m.call("sim_add_device", model="iPhone 17 Pro", name=name)
        self.check("delete: scratch device made", not err, text[:200])
        if err:
            return
        dev = (st or {}).get("device") or ""
        text, _, err, _ = self.m.call("sim_start", phone=name)
        t0 = time.monotonic()
        while time.monotonic() - t0 < 400:
            p = self.phone_state(name) or {}
            if p.get("state") == "running":
                break
            time.sleep(3)
        self.check("delete: it runs", (self.phone_state(name) or {}).get("state") == "running", "")
        text, _, err, _ = self.m.call("sim_delete", phone=name)
        self.check("delete: a running device is refused without stop", err and "stop" in text, text[:200])
        self.check("delete: and still there", self.phone_state(name) is not None)
        text, st, err, dt = self.m.call("sim_delete", phone=name, stop=True)
        self.check("delete: stop=true stops and deletes it", not err and st and st.get("stopped"), "%.1f s: %s" % (dt, (st or {}).get("text", text)[:400]))
        self.check("delete: gone from the device list", self.phone_state(name) is None)
        removed = (st or {}).get("removed") or []
        left = (st or {}).get("left") or []
        dirs = [p for p in removed if re.search(r"device-a64-|run-a64-|a64prefix-[^/]*$", p)]
        self.check("delete: folder, state dir and prefix removed", len(dirs) >= 3 and not any(os.path.exists(p) for p in removed), " ".join(dirs))
        self.check("delete: the root-owned work folder removed or reported with its command",
                   all("pkexec rm" in l for l in left), "; ".join(left)[:300])
        text, _, err, _ = self.m.call("sim_delete", phone=name)
        self.check("delete: a device that is not there is an error", err, text[:120])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.expanduser("~/scratch/x86sim/ax-devices"))
    ap.add_argument("--app", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim")), "apps/x86forms.app"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    log = open(os.path.join(a.out, "mcp-%s.log" % a.phone), "w")
    m = Mcp(a.mcp, a.phone, log)
    r = Run(m, a.app)
    only = set(filter(None, a.only.split(",")))
    want = lambda n: (not only or n in only)
    try:
        for name in ["delete"]:
            if want(name):
                getattr(r, name)()
    finally:
        m.close()
    print("%d failed: %s" % (len(r.fails), ", ".join(r.fails)))
    sys.exit(len(r.fails))


if __name__ == "__main__":
    main()
