#!/usr/bin/env python3
"""x86Sim: React Native and Expo apps built on Linux (x86sim dev + omarchy-apple-dev's CocoaPods support), checked
end to end through x86sim-mcp on a phone:

  expo   a fresh create-expo-app project: dev_run (npm install if needed, expo prebuild, pod install, the CocoaPods
         workspace built on Linux, install, launch, Metro) shows "Welcome to Expo"; a tap on the Explore tab shows
         its page; an edit of src/app/index.tsx reaches the app by Fast Refresh
  bare   a bare React Native app (@react-native-community/cli init): its App.tsx is replaced by a counter; dev_run
         shows it; a tap on the button counts; an edit of the label reaches the app by Fast Refresh with the count
         kept; dev_reload reloads the JavaScript (the count starts over)

Each app is built once and run once. The apps are not made here (npm downloads ~600 MB each):
  npx create-expo-app@latest expoapp --yes
  npx @react-native-community/cli@latest init BareRN --install-pods false
Needs CocoaPods (x86sim dev setup cocoapods), ninja and rsync. Edited files are restored at the end, Metro stopped.

Usage: tests/dev/rn_e2e.py --phone NAME [--expo DIR] [--bare DIR] [--mcp PATH] [--log FILE]
  --phone: a phone of yours (booted by dev_run start=true when it is off; left running).
Exit status: failed checks.
"""
import argparse
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tests/ax"))
from mcp_e2e import Mcp  # noqa: E402

COUNTER = """import React, {useState} from 'react';
import {Pressable, SafeAreaView, Text} from 'react-native';

export default function App() {
  const [count, setCount] = useState(0);
  return (
    <SafeAreaView style={{flex: 1, alignItems: 'center', justifyContent: 'center'}}>
      <Text>Counter from Linux</Text>
      <Text>Count: {count}</Text>
      <Pressable accessibilityRole="button" onPress={() => setCount(count + 1)} style={{padding: 16}}>
        <Text>Add one</Text>
      </Pressable>
    </SafeAreaView>
  );
}
"""


class Run:
    def __init__(self, m):
        self.m, self.fails = m, []

    def check(self, name, ok, detail=""):
        print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail[:300]), flush=True)
        if not ok:
            self.fails.append(name)
        return ok

    def wait(self, target, timeout=60):
        text, _, err, _ = self.m.call("wait_for", target=target, timeout=timeout)
        return not err, text

    def run_app(self, name, project):
        t0 = time.monotonic()
        text, st, err, _ = self.m.call("dev_run", project=project, start=True)
        return self.check(f"{name}: dev_run built, installed and launched it", not err, "%.0f s: %s" % (time.monotonic() - t0, text[-300:]))

    def edit(self, path, old, new):
        s = open(path).read()
        open(path, "w").write(s.replace(old, new, 1))

    def expo(self, d):
        f = os.path.join(d, "src/app/index.tsx")
        keep = open(f).read()
        try:
            if not self.run_app("expo", d):
                return
            ok, text = self.wait("Welcome to", 180)
            self.check("expo: the snapshot shows the welcome screen", ok, text[-200:])
            self.m.call("tap", target="Explore")
            ok, text = self.wait("This starter app includes", 30)
            self.check("expo: a tap on Explore shows its page", ok, text[-200:])
            self.m.call("tap", target="Home")
            self.edit(f, "Welcome to&nbsp;Expo", "Edited on Linux")
            ok, text = self.wait("Edited on Linux", 60)
            self.check("expo: a JavaScript edit reaches the app (Fast Refresh)", ok, text[-200:])
        finally:
            open(f, "w").write(keep)

    def bare(self, d):
        f = os.path.join(d, "App.tsx")
        keep = open(f).read()
        try:
            open(f, "w").write(COUNTER)
            if not self.run_app("bare", d):
                return
            ok, text = self.wait("Count: 0", 180)
            self.check("bare: the snapshot shows the app", ok, text[-200:])
            self.m.call("tap", target="Add one")
            ok, text = self.wait("Count: 1", 30)
            self.check("bare: a tap changes its state", ok, text[-200:])
            self.edit(f, "Counter from Linux", "Counter edited")
            ok, text = self.wait("Counter edited", 60)
            ok2, _ = self.wait("Count: 1", 5)
            self.check("bare: a JavaScript edit reaches the app, state kept (Fast Refresh)", ok and ok2, text[-200:])
            text, _, err, _ = self.m.call("dev_reload")
            ok, text = self.wait("Count: 0", 60)
            self.check("bare: dev_reload reloads the JavaScript", not err and ok, text[-200:])
        finally:
            open(f, "w").write(keep)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--expo")
    ap.add_argument("--bare")
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--log", default="rn_e2e.log")
    a = ap.parse_args()
    dev = os.path.join(os.path.dirname(a.mcp), "x86sim-dev")
    log = open(a.log, "a")
    m = Mcp(a.mcp, a.phone, log)
    r = Run(m)
    try:
        for kind, d in (("expo", a.expo), ("bare", a.bare)):
            if not d:
                continue
            d = os.path.abspath(d)
            try:
                getattr(r, kind)(d)
            finally:
                # one Metro on 8081 at a time: stop this app's before the next
                if os.path.exists(dev):
                    subprocess.run([dev, "metro", d, "--stop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    time.sleep(2)
    finally:
        m.close()
    print("%d failed: %s" % (len(r.fails), ", ".join(r.fails)) if r.fails else "all passed")
    return len(r.fails)


if __name__ == "__main__":
    sys.exit(main())
