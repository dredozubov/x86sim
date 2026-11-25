#!/usr/bin/env python3
"""x86Sim dev check: a Compose Multiplatform app built only on Linux runs on an x86Sim phone.

tests/dev/kmp/ComposeCounter (a shared Kotlin module with a Compose UI, in a SwiftUI app) is copied to WORK, given a
Gradle wrapper, and built by dev_run through MCP: x86sim dev sees KMP_GRADLE_ROOT in the app's xtool.env and builds with
omarchy-apple-dev's kmp/build-app.sh (Gradle builds the klibs, Kotlin/Native links Shared.framework for
ios_simulator_arm64 with the Darwin SDK and ld64.lld, ship.sh builds the app). Then, on the phone:
  ui     the Compose UI is in the snapshot ("Count: 0", the "Add one" button)
  tap    tapping "Add one" makes it "Count: 1" (Compose's state and its accessibility tree update)

Usage: tests/dev/kmp_e2e.py [--phone at2-kmp] [--model "iPhone 17"] [--work DIR] [--gradle DIR] [--mcp PATH]
       [--app PATH.app] (install a build instead of dev_run) [--keep] (leave the phone, else it is stopped)
--gradle is an unpacked Gradle distribution (for the wrapper; default: `gradle` on the PATH). Gradle, Kotlin and the
link are memory hungry: run it under `systemd-run --user --scope -p MemoryMax=6G`. Exit status: failed checks.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mcp_dev  # noqa: E402

SAMPLE = os.path.join(mcp_dev.ROOT, "tests/dev/kmp/ComposeCounter")
BUNDLE = "sim.x86.ComposeCounter"


def prepare(work, gradle):
    """The sample in WORK with a Gradle wrapper (kept across runs: Gradle's and the link's outputs are reused)"""
    os.makedirs(work, exist_ok=True)
    subprocess.run(["rsync", "-a", "--exclude", "build", "--exclude", ".gradle", SAMPLE + "/", work + "/"], check=True)
    if not os.path.exists(os.path.join(work, "gradlew")):
        g = os.path.join(gradle, "bin/gradle") if gradle else shutil.which("gradle")
        if not g:
            raise SystemExit("no Gradle for the wrapper: --gradle DIR (an unpacked gradle-9.x-bin.zip)")
        subprocess.run([g, "-q", "wrapper", "--gradle-version", "9.9.2"], cwd=work, check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--phone", default="at2-kmp")
    ap.add_argument("--model", default="iPhone 17")
    ap.add_argument("--work", default=os.path.expanduser("~/scratch/kmp-e2e"))
    ap.add_argument("--gradle")
    ap.add_argument("--mcp", default=mcp_dev.default_mcp())
    ap.add_argument("--app")
    ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()

    if not a.app:
        prepare(a.work, a.gradle)
    os.makedirs(a.work, exist_ok=True)
    log = open(os.path.join(a.work, "kmp_e2e.log"), "w")
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
                m.must("dev_run", project=os.path.join(a.work, "iosApp"))
            print("built / installed / launched in %.0f s" % (time.monotonic() - t0), flush=True)
            text, err = m.call("wait_for", target="Count: 0", timeout=60)
            check("ui", not err and "Add one" in text, "" if not err else text.strip()[-300:])
            if not err:
                text, err = m.call("tap", target="Add one")
                text2, err2 = m.call("wait_for", target="Count: 1", timeout=20)
                check("tap", not err and not err2, "" if not err2 else text2.strip()[-300:])
            m.screenshot(os.path.join(a.work, "kmp_e2e.png"))
        finally:
            if not a.keep:
                m.call("sim_stop")
    m.close()
    print("log: %s" % log.name)
    return len(failed)


if __name__ == "__main__":
    sys.exit(main())
