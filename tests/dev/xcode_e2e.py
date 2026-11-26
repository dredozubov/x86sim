#!/usr/bin/env python3
"""x86Sim: real Xcode projects built on Linux (x86sim dev + the dev toolchain's Swift Build and xcodebuild), checked
end to end through x86sim-mcp on a phone. One app per project shape, each from its unchanged checkout:

  objc     RDVTabBarController's example (Objective-C only, storyboard launch screen)     github.com/robbdimitrov/RDVTabBarController
  mixed    Charts' iOS demo (workspace: Swift framework project + Objective-C/Swift app, bridging header, 26 xibs)
                                                                                           github.com/ChartsOrg/Charts
  multi    NextSunnyDay (SwiftUI app, widget, watch app with its own widget, 19 local packages)
                                                                                           github.com/naipaka/NextSunnyDay-iOS
  spm      Cronica (app, watch app, widget, share extension, local + 4 remote packages: Sentry, Nuke, Pow, YouTubePlayerKit)
                                                                                           github.com/infera/cronica
           (needs Config/Secrets.xcconfig: cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig)

For each: dev_run builds it (Swift Build), installs and launches it; the snapshot shows the app's own elements; one
tap changes the screen (objc / mixed predate scenes: iOS 27's UIKit stops them after launch, as on Apple's simulator,
so the check is that exit). multi / spm also check the bundle holds the extensions and the watch app. --fastlane DIR
runs the lane in DIR/fastlane/Fastfile (gym archive + scan tests on the phone) with the dev toolchain's linux-bin first
on PATH, and checks both ran.

Usage: tests/dev/xcode_e2e.py --phone NAME [--objc DIR] [--mixed DIR] [--multi DIR] [--spm DIR] [--fastlane DIR]
                              [--mcp PATH] [--log FILE]
Needs `x86sim dev setup swiftbuild`. Exit status: failed checks.
"""
import argparse
import glob
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tests/ax"))
from mcp_e2e import Mcp  # noqa: E402

# shape -> (scheme, text its first screen shows, what to tap, text after the tap, bundle parts that must exist)
# objc / mixed: apps from before scenes (no UIApplicationSceneManifest). iOS 27's UIKit stops them right after launch
# (SIGTRAP), on Apple's simulator too (Xcode 27.2: RDVTabBarController), so the check is that exit.
APPS = {
    "objc": (None, None, None, None, []),
    "mixed": ("ChartsDemo-iOS", None, None, None, ["Frameworks/DGCharts.framework", "BarChartViewController.nib"]),
    "multi": ("NextSunnyDay", "Next Sunny Day", "Search for a Region", None,
              ["PlugIns/*Widget*.appex", "Watch/*.app", "Watch/*.app/PlugIns/*.appex"]),
    "spm": ("Cronica (EN-US)", None, None, None,
            ["PlugIns/*Widget*.appex", "PlugIns/*Share*.appex", "Watch/*.app", "Frameworks/Sentry.framework"]),
}


class Run:
    def __init__(self, m):
        self.m, self.fails = m, []

    def check(self, name, ok, detail=""):
        print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail[:400]), flush=True)
        if not ok:
            self.fails.append(name)
        return ok

    def app(self, shape, d):
        # scheme: what x86sim dev picks by itself (named like the project, else the first), checked below
        scheme, first, tap, after, parts = APPS[shape]
        t0 = time.monotonic()
        text, st, err, _ = self.m.call("dev_run", project=d, start=True)
        if not self.check(f"{shape}: dev_run built, installed and launched it", not err, "%.0f s: %s" % (time.monotonic() - t0, text[-300:])):
            return
        res = (st or {}).get("result") or {}
        app, bid = res.get("app") or "", res.get("bundle_id") or ""
        # the launch returns before the app's first frame: wait until it is in front
        for _ in range(30):
            front, _, _, _ = self.m.call("snapshot")
            if f"front {bid}" in front:
                break
            time.sleep(2)
        missing = [p for p in parts if not glob.glob(os.path.join(app, p))]
        if parts:
            self.check(f"{shape}: the bundle holds {', '.join(parts)}", not missing, f"missing: {missing}")
        if first:
            text, _, err, _ = self.m.call("wait_for", target=first, timeout=60)
            self.check(f"{shape}: the snapshot shows its first screen ({first!r})", not err, text[-300:])
        if shape in ("objc", "mixed"):
            text, st2, err, _ = self.m.call("app_state", bundle_id=bid)
            # Apple's simulator (Xcode 27.2, iOS 27.2) stops such an app the same way: EXC_BREAKPOINT in
            # UIKit's _UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption
            self.check(f"{shape}: it launched and UIKit stopped it for having no scene lifecycle, as on Apple's simulator",
                       not err and "SIGTRAP" in text, text[:300])
            return
        before, _, _, _ = self.m.call("snapshot")
        own = [l for l in before.splitlines() if l.startswith("@e")]
        self.check(f"{shape}: the snapshot shows the app's UI ({bid} in front, {len(own)} elements)",
                   f"front {bid}" in before and len(own) >= 2, before[:300])
        target = tap or next((l.split('"')[1] for l in own if " button " in l or " tab " in l), None)
        if not target:
            self.check(f"{shape}: something to tap", False, before[:300])
            return
        text, _, err, _ = self.m.call("tap", target=target)
        time.sleep(2)
        after_snap, _, _, _ = self.m.call("snapshot")
        ok = not err and after_snap != before and (after is None or after in after_snap)
        self.check(f"{shape}: a tap on {target!r} changes the screen", ok, after_snap[:300])

    def fastlane(self, d, phone):
        fork = os.path.join(ROOT, "external/omarchy-apple-dev")
        env = dict(os.environ, PATH=os.path.join(fork, "linux-bin") + os.pathsep + os.environ.get("PATH", ""),
                   XCODEBUILD_PHONE=phone, FASTLANE_OPT_OUT_USAGE="1", FASTLANE_HIDE_CHANGELOG="1",
                   LANG=os.environ.get("LANG", "C.UTF-8"))
        t0 = time.monotonic()
        r = subprocess.run(["fastlane", "ci"], cwd=d, env=env, capture_output=True, text=True)
        out = r.stdout + r.stderr
        self.check("fastlane: the lane ran (gym + scan)", r.returncode == 0, "%.0f s: %s" % (time.monotonic() - t0, out[-600:]))
        self.check("fastlane: gym stored the archive", "Successfully stored the archive" in out, "")
        self.check("fastlane: scan ran the tests on the phone", "** TEST SUCCEEDED **" in out or "Test Succeeded" in out, "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    for k in APPS:
        ap.add_argument("--" + k)
    ap.add_argument("--fastlane")
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--log", default="xcode_e2e.log")
    a = ap.parse_args()
    m = Mcp(a.mcp, a.phone, open(a.log, "a"))
    r = Run(m)
    try:
        for shape in APPS:
            d = getattr(a, shape)
            if d:
                r.app(shape, os.path.abspath(d))
        if a.fastlane:
            r.fastlane(os.path.abspath(a.fastlane), a.phone)
    finally:
        m.close()
    print("%d failed: %s" % (len(r.fails), ", ".join(r.fails)) if r.fails else "all passed")
    return len(r.fails)


if __name__ == "__main__":
    sys.exit(main())
