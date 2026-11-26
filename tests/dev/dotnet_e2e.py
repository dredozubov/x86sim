#!/usr/bin/env python3
"""x86Sim dev check: a .NET for iOS app built only on Linux runs on an x86Sim phone.

tests/dev/dotnet/HelloCounter (UIKit in C#: a label and a button) is copied to WORK and built by dev_run through MCP:
x86sim dev sees its net10.0-ios .csproj and builds it with omarchy-apple-dev's dotnet/build.sh (the iOS workload's
MSBuild tasks against the Darwin SDK, NativeAOT for iossimulator-arm64, clang + ld64.lld). Then, on the phone:
  ui     the app's UI is in the snapshot ("Count: 0", the "Add one" button)
  tap    tapping "Add one" makes it "Count: 1"

Needs dotnet/setup.sh run once (OAD_DOTNET, as for build.sh).
Usage: tests/dev/dotnet_e2e.py [--phone at2-kmp] [--model "iPhone 17"] [--work DIR] [--mcp PATH] [--app PATH.app]
       [--keep]
Run it under `systemd-run --user --scope -p MemoryMax=5G` (MSBuild and ILCompiler). Exit status: failed checks.
"""
import argparse
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mcp_dev  # noqa: E402

SAMPLE = os.path.join(mcp_dev.ROOT, "tests/dev/dotnet/HelloCounter")
BUNDLE = "sim.x86.HelloCounter"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--phone", default="at2-kmp")
    ap.add_argument("--model", default="iPhone 17")
    ap.add_argument("--work", default=os.path.expanduser("~/scratch/dotnet-e2e"))
    ap.add_argument("--mcp", default=mcp_dev.default_mcp())
    ap.add_argument("--app")
    ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()

    proj = os.path.join(a.work, "HelloCounter")
    if not a.app:
        shutil.rmtree(proj, ignore_errors=True)
        shutil.copytree(SAMPLE, proj)
    os.makedirs(a.work, exist_ok=True)
    log = open(os.path.join(a.work, "dotnet_e2e.log"), "w")
    m = mcp_dev.Mcp(a.mcp, a.phone, log)
    failed = []

    def check(name, ok, detail=""):
        print("%s %s %s" % ("ok  " if ok else "FAIL", name, detail), flush=True)
        if not ok:
            failed.append(name)

    mcp_dev.ensure_phone(m, a.phone, a.model)
    with mcp_dev.phone_slot() as slot:
        print("slot %s, phone %s" % (slot, a.phone), flush=True)
        try:
            m.must("sim_start")
            print("home screen after %.0f s" % mcp_dev.wait_home(m), flush=True)
            t0 = time.monotonic()
            if a.app:
                m.must("app_install", path=a.app)
                m.must("app_launch", bundle_id=BUNDLE, after="none")
            else:
                m.must("dev_run", project=proj)
            print("built / installed / launched in %.0f s" % (time.monotonic() - t0), flush=True)
            text, err = m.call("wait_for", target="Count: 0", timeout=60)
            check("ui", not err and "Add one" in text, "" if not err else text.strip()[-300:])
            if not err:
                text, err = m.call("tap", target="Add one")
                text2, err2 = m.call("wait_for", target="Count: 1", timeout=20)
                check("tap", not err and not err2, "" if not err2 else text2.strip()[-300:])
            m.screenshot(os.path.join(a.work, "dotnet_e2e.png"))
        finally:
            if not a.keep:
                m.call("sim_stop")
    m.close()
    print("log: %s" % log.name)
    return len(failed)


if __name__ == "__main__":
    sys.exit(main())
