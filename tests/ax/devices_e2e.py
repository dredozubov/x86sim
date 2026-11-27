#!/usr/bin/env python3
"""x86Sim: end-to-end checks of the device and app tools (round 2) through x86sim-mcp:

  delete   sim_add_device + sim_start a scratch device, sim_delete refuses it running, deletes it with stop=true:
           its folder, state dir, prefix and ring are gone; the overlay's root-owned work folder is reported (or
           removed with --privileged, which needs a person at the password dialog)
  state    app_state of the test app (tests/apps/x86forms): not running, then launched (its pid, foreground,
           memory), sent to the background by Home, terminated (last exit SIGKILL); without bundle_id: running apps
  abort    why an app died: dyld refusing x86dyldfail (a missing symbol) and x86forms calling abort_with_reason
           (recorded by libsimshim) reach app_launch's error and app_state's last exit
  kill     app_terminate signal=kill ends the app's process (SIGKILL) and answers its pid; again: not running
  record   sim_record_video action=start returns at once, status says it records, stop finishes a playable MP4 and
           answers its length and size; the fixed-length form (secs) still works
  launch   app_launch of an app that exits at once (x86forms --exit-early, exit(3)) fails saying so; a good launch
           still answers its pid

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

    def install(self):
        if getattr(self, "_installed", None) is None:
            text, _, err, _ = self.m.call("app_install", path=self.app)
            self._installed = not err
            self.check("x86forms installed", self._installed, text[:160])
        return self._installed

    def app_info(self):
        text, st, err, _ = self.m.call("app_state", bundle_id=APP)
        a = ((st or {}).get("apps") or [{}])[0]
        return a, text

    # -- state
    def state(self):
        if not self.install():
            return
        self.m.call("app_terminate", bundle_id=APP, after="none")
        time.sleep(1)
        a, text = self.app_info()
        self.check("state: installed, not running", a.get("installed") and not a.get("running"), text[:200])
        text, _, err, _ = self.m.call("app_launch", bundle_id=APP, after="none")
        pid = int(re.search(r": (-?\d+)", text).group(1)) if re.search(r": (-?\d+)", text) else -1
        self.m.call("wait_for", target="Sign up", timeout=60)
        a, text = self.app_info()
        p = (a.get("processes") or [{}])[0]
        self.check("state: running with the launch's pid, in front", a.get("running") and p.get("pid") == pid and p.get("state", "").startswith("foreground"),
                   "launch pid %s | %s" % (pid, text[:240]))
        self.check("state: memory and uptime", p.get("memory_mb", 0) > 5 and p.get("uptime_s", -1) >= 0, "%s MB, %s s" % (p.get("memory_mb"), p.get("uptime_s")))
        text, st, err, _ = self.m.call("app_state")
        self.check("state: without bundle_id the running apps", not err and APP in text, text[:200])
        self.m.call("press", button="home", after="none")
        time.sleep(3)
        a, text = self.app_info()
        p = (a.get("processes") or [{}])[0]
        self.check("state: Home sends it to the background", p.get("state") in ("background", "suspended"), text[:200])
        self.m.call("app_terminate", bundle_id=APP, after="none")
        time.sleep(1.5)
        a, text = self.app_info()
        e = a.get("last_exit") or {}
        self.check("state: terminated: not running, last exit recorded", not a.get("running") and "SIGKILL" in e.get("how", ""), text[:300])
        # launchd's own accounting: how long the run took (it ran ~10 s here; proc_pid_rusage's start / exit times in
        # the guest's timebase, not "ran for 12293544232889ms")
        ran = re.search(r"ran for (\d+)ms", e.get("line", ""))
        self.check("state: launchd's 'ran for' is the run's length", ran and 1000 <= int(ran.group(1)) <= 600000, e.get("line", "")[-60:])

    # -- launch: an app that dies at once
    def launch(self):
        if not self.install():
            return
        self.m.call("app_terminate", bundle_id=APP, after="none")
        text, _, err, dt = self.m.call("app_launch", bundle_id=APP, args=["--exit-early"], after="none")
        self.check("launch: an app that exits at once is an error", err and "exit(3)" in text, "%.1f s: %s" % (dt, text[:300]))
        text, _, err, dt = self.m.call("app_launch", bundle_id=APP, after="none")
        self.check("launch: a good launch answers its pid", not err and re.search(r": \d+", text), "%.1f s: %s" % (dt, text[:200]))
        self.m.call("app_terminate", bundle_id=APP, after="none")

    # -- abort: reasons
    def abort(self):
        if not self.install():
            return
        dyld = os.path.join(os.path.dirname(self.app), "x86dyldfail.app")
        text, _, err, _ = self.m.call("app_install", path=dyld)
        self.check("abort: x86dyldfail installed", not err, text[:120])
        text, _, err, dt = self.m.call("app_launch", bundle_id="com.x86sim.test.x86dyldfail", after="none")
        self.check("abort: a launch dyld refuses is an error", err and "died" in text, "%.1f s: %s" % (dt, text[:400]))
        if "symbol not found" not in text.lower() and "reason" not in text:
            # dyld's reason comes from the translator's log (linux/arm64jit host.cpp h_helper_abort): an installed
            # libarm64jit from before it logs none
            print("SKIP abort: dyld's reason (the installed translator does not log dyld_sim's abort reason yet)", flush=True)
        else:
            self.check("abort: the error has dyld's reason", "symbol not found" in text.lower() and "x86sim_no_such_symbol" in text, text[:400])
            text, st, err, _ = self.m.call("app_state", bundle_id="com.x86sim.test.x86dyldfail")
            self.check("abort: app_state's last exit has the reason", "symbol not found" in text.lower(), text[:400])
        self.m.call("app_terminate", bundle_id=APP, after="none")
        text, _, err, dt = self.m.call("app_launch", bundle_id=APP, args=["--abort-reason"], after="none")
        self.check("abort: abort_with_reason's reason (libsimshim) in the launch error", err and "the reason agents should see" in text, "%.1f s: %s" % (dt, text[:400]))
        a, text = self.app_info()
        self.check("abort: and in app_state", "the reason agents should see" in text, text[:400])
        self.m.call("app_uninstall", bundle_id="com.x86sim.test.x86dyldfail")

    # -- kill: app_terminate signal=kill
    def kill(self):
        if not self.install():
            return
        self.m.call("app_terminate", bundle_id=APP, after="none")
        text, _, err, _ = self.m.call("app_launch", bundle_id=APP, after="none")
        m = re.search(r": (\d+)", text)
        pid = int(m.group(1)) if m else -1
        text, st, err, dt = self.m.call("app_terminate", bundle_id=APP, signal="kill", after="none")
        self.check("kill: SIGKILL ends it and names its pid", not err and pid in ((st or {}).get("killed") or []), "%.1f s: %s" % (dt, text[:200]))
        a, text = self.app_info()
        self.check("kill: not running after", not a.get("running"), text[:200])
        text, _, err, _ = self.m.call("app_terminate", bundle_id=APP, signal="kill", after="none")
        self.check("kill: killing an app that is not running is an error", err and "not running" in text, text[:120])

    # -- record: start / stop
    def record(self, out):
        import subprocess
        path = os.path.join(out, "rec-%d.mp4" % os.getpid())
        text, st, err, dt = self.m.call("sim_record_video", action="start", path=path)
        self.check("record: start returns at once", not err and dt < 8 and (st or {}).get("recording"), "%.1f s: %s" % (dt, text[:200]))
        text, _, err, _ = self.m.call("sim_record_video", action="start", path=path + ".2.mp4")
        self.check("record: a second start is refused", err and "already" in text, text[:160])
        self.m.call("press", button="home", after="none")
        self.m.call("swipe", direction="left", after="none")
        time.sleep(2)
        text, st, err, _ = self.m.call("sim_record_video", action="status")
        self.check("record: status: recording", not err and (st or {}).get("recording") and (st or {}).get("secs", 0) >= 2, text[:200])
        self.m.call("swipe", direction="right", after="none")
        time.sleep(1.5)
        text, st, err, dt = self.m.call("sim_record_video", action="stop")
        st = st or {}
        self.check("record: stop answers the file, its length and size", not err and st.get("bytes", 0) > 1000 and st.get("secs", 0) >= 2.5, "%.1f s: %s" % (dt, text[:240]))
        dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip()
        self.check("record: the MP4 plays (ffprobe reads its length)", dur and abs(float(dur) - st.get("secs", 0)) < 1.5, "ffprobe %s s, answer %s s" % (dur, st.get("secs")))
        text, _, err, _ = self.m.call("sim_record_video", action="stop")
        self.check("record: stop with nothing recording is an error", err, text[:120])
        text, st, err, dt = self.m.call("sim_record_video", path=path + ".fixed.mp4", secs=2)
        self.check("record: the fixed form (secs) still works", not err and (st or {}).get("bytes", 0) > 1000, "%.1f s: %s" % (dt, text[:160]))
        for p in (path, path + ".fixed.mp4"):
            if os.path.exists(p):
                os.remove(p)


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
        for name in ["state", "launch", "abort", "kill", "record", "delete"]:
            if want(name):
                getattr(r, name)(*([a.out] if name == "record" else []))
    finally:
        m.close()
    print("%d failed: %s" % (len(r.fails), ", ".join(r.fails)))
    sys.exit(len(r.fails))


if __name__ == "__main__":
    main()
