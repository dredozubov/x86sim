#!/usr/bin/env python3
"""x86Sim: checks of the agent tools' MCP layer (x86sim-mcp over stdio): what every tool shares, before any one tool's
own work. Most need no running phone; `shot` needs one.

  schema   tools/list: every tool has a description and an object schema, its required arguments are among its
           properties, no name twice; serverInfo names the version
  args     an argument a tool does not have is an error naming the ones it has (screenshot path= used to be ignored
           and the call looked done); also in a batch step; a required argument left out is an error before the tool
           runs; phone / device are taken by every tool
  device   an unknown device name is an error listing the devices
  off      on a device that is off, snapshot / tap / wait_for / expect / type / app_launch answer at once that it is
           off (wait_for used to wait its whole timeout and say "no app answers")
  sweep    every tool that is safe to call on an off device answers (an error is fine) within its time, and the server
           is still up after each: no hang, no panic, no exit
  shot     (--phone, a running phone) screenshot path= writes the PNG it answers; the file is that image

Usage: tests/ax/tools_e2e.py [--phone NAME] [--off NAME] [--mcp PATH] [--only schema,args,...] [--out DIR]
--off: a device that is off (default: the first off one). Without --phone, shot is skipped.
Exit status: failed checks.
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_e2e import Mcp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Tools left out of the sweep: they start, change or delete things even on an off device (or on the host), or take a
# long time by design. Every other tool is called with only phone=<the off device>.
NOT_SWEPT = {
    "sim_start", "sim_restart", "sim_erase", "sim_delete", "sim_clone", "sim_add_device", "sim_keychain_reset",
    "runtime_delete", "share_start", "share_stop", "dev_setup", "dev_setup_cancel", "dev_new", "dev_ship",
    "dev_reload", "phone_take", "phone_release", "xctest_run", "features_preset", "feature_set", "sim_privacy",
    "sim_locale", "sim_timezone", "sim_status_bar", "sim_gpu", "sim_fidelity", "net_mock", "batch",
}


class Run:
    def __init__(self, m, args):
        self.m, self.a, self.fails = m, args, []

    def check(self, name, ok, detail=""):
        print("%s %s %s" % ("PASS" if ok else "FAIL", name, str(detail).replace("\n", " | ")[:300]), flush=True)
        if not ok:
            self.fails.append(name)

    def tools(self):
        return self.m.rpc("tools/list", {})["result"]["tools"]

    def schema(self):
        tl = self.tools()
        names = [t["name"] for t in tl]
        self.check("schema: tools listed", len(tl) > 50, "%d tools" % len(tl))
        self.check("schema: no name twice", len(names) == len(set(names)), sorted(n for n in set(names) if names.count(n) > 1))
        bad = [t["name"] for t in tl if not t.get("description") or t.get("inputSchema", {}).get("type") != "object"]
        self.check("schema: each has a description and an object schema", not bad, bad)
        bad = [(t["name"], r) for t in tl for r in t["inputSchema"].get("required", []) if r not in t["inputSchema"].get("properties", {})]
        self.check("schema: required arguments are properties", not bad, bad)
        bad = [t["name"] for t in tl if "`device`" in t.get("description", "")]
        self.check("schema: descriptions call the device argument phone", not bad, bad)
        info = self.m.init.get("serverInfo", {})
        self.check("schema: serverInfo names x86sim and a version", info.get("name") == "x86sim" and info.get("version"), info)

    def args(self):
        off = self.a.off
        text, _, err, _ = self.m.call("snapshot", phone=off, path="/tmp/never.png")
        self.check("args: an unknown argument is an error naming the ones there are",
                   err and "no argument" in text and "takes:" in text and "diff" in text, text)
        text, _, err, _ = self.m.call("wait_for", phone=off, target="X", timeout_s=1)
        self.check("args: a misspelt one too (timeout_s)", err and '"timeout_s"' in text and "timeout" in text, text)
        text, _, err, _ = self.m.call("batch", phone=off, steps=[{"tool": "tap", "target": "A", "hold": 3}])
        self.check("args: in a batch step, naming the step", err and "batch step 1" in text and '"hold"' in text, text)
        text, _, err, _ = self.m.call("app_launch", phone=off)
        self.check("args: a required argument left out is an error", err and '"bundle_id"' in text and "required" in text, text)
        text, _, err, _ = self.m.call("app_launch", phone=off, bundle_id=None)
        self.check("args: null counts as left out", err and "required" in text, text)
        text, _, err, _ = self.m.call("phone_release")
        self.check("args: phone required where the schema says so", err and '"phone"' in text and "required" in text, text)
        text, _, err, _ = self.m.call("snapshot", device=off)
        self.check("args: device is taken as phone", err and "is off" in text, text)

    def device(self):
        text, _, err, _ = self.m.call("snapshot", phone="no-such-device-x")
        self.check("device: an unknown name is an error listing the devices", err and "no device" in text and "devices:" in text, text)

    def off(self):
        off = self.a.off
        for tool, args in [("snapshot", {}), ("tap", {"target": "Settings"}), ("wait_for", {"target": "Settings", "timeout": 30}),
                           ("expect", {"target": "Settings", "timeout": 30}), ("type", {"text": "x", "target": "Search"}),
                           ("screenshot", {}), ("app_launch", {"bundle_id": "com.apple.Preferences"}),
                           ("app_list", {}), ("app_state", {}), ("open_url", {"url": "https://example.com"})]:
            t0 = time.monotonic()
            text, _, err, _ = self.m.call(tool, phone=off, **args)
            dt = time.monotonic() - t0
            self.check("off: %s fails at once" % tool, err and dt < 5, "%.1f s: %s" % (dt, text))
            if tool in ("snapshot", "wait_for", "tap"):
                self.check("off: %s says the device is off" % tool, "is off" in text, text)

    def sweep(self):
        off = self.a.off
        hung, died = [], []
        n = 0
        for t in self.tools():
            name = t["name"]
            if name in NOT_SWEPT or t["inputSchema"].get("required"):
                continue
            n += 1
            t0 = time.monotonic()
            try:
                text, _, err, _ = self.m.call(name, phone=off)
            except Exception as e:  # the server exited
                died.append("%s: %s" % (name, e))
                self.m = self.m.restart()
                continue
            dt = time.monotonic() - t0
            if dt > 20:
                hung.append("%s %.0f s" % (name, dt))
            if "internal error (panic" in text:
                died.append("%s: %s" % (name, text[:120]))
        self.check("sweep: every tool answered in time", not hung, "%d tools; slow: %s" % (n, hung))
        self.check("sweep: no panic, the server stayed up", not died, died)
        r = self.m.rpc("ping", {})
        self.check("sweep: still answers ping after", "result" in r, r)

    def shot(self):
        if not self.a.phone:
            print("SKIP shot: no --phone", flush=True)
            return
        path = os.path.join(self.a.out, "shot.png")
        if os.path.exists(path):
            os.unlink(path)
        r = self.m.rpc("tools/call", {"name": "screenshot", "arguments": {"phone": self.a.phone, "path": path}})["result"]
        img = next((c for c in r.get("content", []) if c.get("type") == "image"), None)
        cap = " ".join(c.get("text", "") for c in r.get("content", []) if c.get("type") == "text")
        self.check("shot: answers the image and names the file", img and not r.get("isError") and path in cap, cap)
        self.check("shot: the file is that image", os.path.exists(path) and img and open(path, "rb").read() == base64.b64decode(img["data"]),
                   "%s bytes" % (os.path.getsize(path) if os.path.exists(path) else "no file"))
        sub = os.path.join(self.a.out, "deeper", "dir", "el.png")
        text, _, err, _ = self.m.call("screenshot", phone=self.a.phone, path=sub, scale=3)
        self.check("shot: folders are made", not err and os.path.exists(sub) and open(sub, "rb").read(8) == b"\x89PNG\r\n\x1a\n", text)


class Server(Mcp):
    def __init__(self, path, log):
        self.path, self._log = path, log
        Mcp.__init__(self, path, None, log)
        self.init = self.last_init

    def rpc(self, method, params):
        m = Mcp.rpc(self, method, params)
        if method == "initialize":
            self.last_init = m.get("result", {})
        return m

    def call(self, tool, **args):
        # no default phone: each check names its own
        self.n += 1
        t0 = time.monotonic()
        r = self.rpc("tools/call", {"name": tool, "arguments": args})["result"]
        text = "\n".join(c.get("text", "") for c in r.get("content", []) if c.get("type") == "text")
        self._log.write("### %s %s (%.2f s)\n%s\n\n" % (tool, json.dumps(args), time.monotonic() - t0, text))
        self._log.flush()
        return text, r.get("structuredContent"), bool(r.get("isError")), time.monotonic() - t0

    def restart(self):
        try:
            self.p.kill()
        except Exception:
            pass
        return Server(self.path, self._log)


def first_off(mcp):
    m = Server(mcp, open(os.devnull, "w"))
    _, st, _, _ = m.call("phones_list")
    m.p.kill()
    return next((p["name"] for p in (st or {}).get("phones", []) if p.get("state") == "off" and p.get("installed")), None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone")
    ap.add_argument("--off")
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim")), "tools_e2e"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    a.off = a.off or first_off(a.mcp)
    if not a.off:
        sys.exit("no device that is off: pass --off NAME")
    print("off device: %s" % a.off, flush=True)
    log = open(os.path.join(a.out, "mcp.log"), "w")
    r = Run(Server(a.mcp, log), a)
    for name in ["schema", "args", "device", "off", "sweep", "shot"]:
        if not a.only or name in a.only.split(","):
            try:
                getattr(r, name)()
            except Exception as e:
                r.check("%s: ran" % name, False, repr(e))
    print("%d failed%s" % (len(r.fails), ": " + ", ".join(r.fails) if r.fails else ""), flush=True)
    sys.exit(len(r.fails))


if __name__ == "__main__":
    main()
