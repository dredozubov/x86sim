#!/usr/bin/env python3
"""x86Sim dev check: apps that use other iOS build setups, built only on Linux, run on an x86Sim phone.

Each setup has one real open-source sample, cloned at a pinned commit into WORK and run by dev_run through MCP, which
sees the setup and runs its steps before Swift Build builds the Xcode project (x86sim dev / devgen.rs):
  carthage   demolaf/movies-uikit (MIT): a Cartfile with Alamofire, SDWebImage, realm-swift (built from their Xcode
             projects by `carthage bootstrap --use-xcframeworks`), RxSwift and rive-ios (their prebuilt xcframeworks)
  xcodegen   HelioMesquita/Swiftmazing (MIT): project.yml with two local Swift packages and a remote one; XcodeGen
             (built on Linux) generates the Xcode project
  bazel      bazelbuild/rules_apple 5.4.0's examples: not buildable on Linux yet; dev_build must name the reason
             (ui / tap are replaced by one check, "blocked": the error points at the dev toolchain's bazel/README.md)
  tuist      kiliankoe/MensaDresden (MIT): a Tuist Project.swift (iOS app embedding a watchOS app, seven remote Swift
             packages, an Icon Composer icon), evaluated with Tuist's ProjectDescription built for Linux
Then, on the phone:
  ui     the app's first screen is in the snapshot (carthage: "Watch Movies")
  tap    one tap changes it (carthage: the TV Shows tab, with its Search button;
         xcodegen: a repository's detail, with its "See repository" button; tuist: the Settings tab)

Usage: tests/dev/deps_e2e.py SETUP [--phone at2-deps] [--model "iPhone 17"] [--work DIR] [--mcp PATH] [--keep]
       [--explore] (print the snapshot after launch instead of the checks)
The toolchain pieces must be installed (x86sim dev setup swiftbuild, carthage, ...). Exit status: failed checks.
"""
import argparse
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mcp_dev  # noqa: E402


def carthage_setup(work):
    # The app reads its TMDB keys from a .env its scheme's pre-action copies into an xcconfig (README: "Setting up
    # Environment config"); placeholders are enough for its first screens.
    with open(os.path.join(work, ".env"), "w") as f:
        f.write("API_KEY = x86sim-placeholder\nAUTH_TOKEN = x86sim-placeholder\n")
    # realm-swift 10.45 picks IPHONEOS_DEPLOYMENT_TARGET by Xcode major version and has none past Xcode 15: with
    # Xcode 27 (on a Mac as here) it defaults to the SDK's 27.2 unless the build is given one, as Carthage users do
    xc = os.path.join(work, "Carthage-Xcode27.xcconfig")
    with open(xc, "w") as f:
        f.write("IPHONEOS_DEPLOYMENT_TARGET_2700 = 12.0\n")
    return {"XCODE_XCCONFIG_FILE": xc}


SAMPLES = {
    "carthage": {
        "repo": "https://github.com/demolaf/movies-uikit",
        "commit": "4493b1b93c7ccb7d1a6c782b7e8168627ce17a54",
        "setup": carthage_setup,
        "bundle": "com.aob.movies-uikit",
        "ui": "Watch Movies",
        "tap": "TV Shows",
        "after": "Search",
    },
    "xcodegen": {
        "repo": "https://github.com/HelioMesquita/Swiftmazing",
        "commit": "4ba29c688ef40b37499d925dea5aec4d50efb225",
        "bundle": "com.swiftmazing",
        # its feed is GitHub's search API (api.github.com): the phone needs the network
        "ui": "BEST REPOSITORIES",
        "tap": "awesome-ios",
        "after": "See repository",
    },
    "tuist": {
        "repo": "https://github.com/kiliankoe/MensaDresden",
        "commit": "6e72de6439a77faedd30c0ae621ec8285076858a",
        "bundle": "io.kilian.MensaDresden",
        # its canteen list comes from the Studentenwerk's API: the phone needs the network
        "ui": "Canteens",
        "tap": "Settings",
        "after": "Ingredients & Allergens",
    },
    # not buildable on Linux yet (external/omarchy-apple-dev/bazel/README.md): dev_build must say so
    "bazel": {
        "repo": "https://github.com/bazelbuild/rules_apple",
        "commit": "45c497b7261659a51574aae7e6c2338a18ba190a",
        "blocked": "bazel/README.md",
    },
}


def prepare(s, work):
    if not os.path.isdir(os.path.join(work, ".git")):
        subprocess.run(["git", "clone", "-q", s["repo"], work], check=True)
    subprocess.run(["git", "-C", work, "-c", "advice.detachedHead=false", "checkout", "-q", s["commit"]], check=True)
    return s["setup"](work) if s.get("setup") else {}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("setup", choices=sorted(SAMPLES))
    ap.add_argument("--phone", default="at2-deps")
    ap.add_argument("--model", default="iPhone 17")
    ap.add_argument("--work")
    ap.add_argument("--mcp", default=mcp_dev.default_mcp())
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--explore", action="store_true")
    a = ap.parse_args()
    s = SAMPLES[a.setup]
    work = a.work or os.path.expanduser("~/scratch/deps-e2e/%s" % a.setup)
    os.makedirs(os.path.dirname(work), exist_ok=True)
    os.environ.update(prepare(s, work))

    log = open(os.path.join(os.path.dirname(work), "%s_e2e.log" % a.setup), "w")
    m = mcp_dev.Mcp(a.mcp, a.phone, log)
    failed = []

    def check(name, ok, detail=""):
        print("%s %s %s" % ("ok  " if ok else "FAIL", name, detail), flush=True)
        if not ok:
            failed.append(name)

    if s.get("blocked"):
        text, err = m.call("dev_build", project=work)
        check("blocked", err and s["blocked"] in text, text.strip()[-300:])
        m.close()
        return len(failed)
    mcp_dev.ensure_phone(m, a.phone, a.model)
    with mcp_dev.phone_slot() as slot:
        print("slot %s, phone %s" % (slot, a.phone), flush=True)
        try:
            m.must("sim_start")
            print("home screen after %.0f s" % mcp_dev.wait_home(m), flush=True)
            t0 = time.monotonic()
            m.must("dev_run", project=work)
            print("built / installed / launched in %.0f s" % (time.monotonic() - t0), flush=True)
            if a.explore:
                time.sleep(5)
                print(m.must("snapshot"))
            else:
                text, err = m.call("wait_for", target=s["ui"], timeout=90)
                check("ui", not err, "" if not err else text.strip()[-300:])
                if not err:
                    text, err = m.call("tap", target=s["tap"])
                    text2, err2 = m.call("wait_for", target=s["after"], timeout=30)
                    check("tap", not err and not err2, "" if not (err or err2) else (text + text2).strip()[-300:])
            m.screenshot(os.path.join(os.path.dirname(work), "%s_e2e.png" % a.setup))
        finally:
            if not a.keep:
                m.call("sim_stop")
    m.close()
    print("log: %s" % log.name)
    return len(failed)


if __name__ == "__main__":
    sys.exit(main())
