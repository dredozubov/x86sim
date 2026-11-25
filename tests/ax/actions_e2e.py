#!/usr/bin/env python3
"""x86Sim: end-to-end checks of the agent tools' actions (round 2) through x86sim-mcp on a running phone, with the
test app tests/apps/x86forms (tests/apps/build.sh x86forms):

  focus    type target= waits for the tapped field: two fields typed back to back with no pause between, each gets
           its own text (the second used to race the focus move); typing into a button (no field) is an error
  fill     a sign-up form in one call: fields by placeholder ("Email"), by the label beside them ("Name", "City"), a
           secure field, a field far down (scrolled into view), then a tap on Sign Up; again with Return as submit
  controls set_value on a slider (number, percentage), switch, stepper, segmented control, wheel picker, date and
           time pickers: the app's bindings see each value; a value a control does not take is an error naming them
  drag     a list row dragged by its reorder handle to another place; an item dragged (held to lift) onto a drop box
  batch    a log-in-like flow in one call (relaunch, wait, type, expect, screenshot): one line per step, the image,
           the screen once at the end; stop_on_error stops at a failing expect, and false runs on
  expect   pass / fail on label, value (a field found by the label beside it), contains, enabled, focused, count,
           gone; a failure names what is there or the nearest text; a timeout waits for the app; wait_for value=

Usage: tests/ax/actions_e2e.py --phone NAME [--mcp PATH] [--only focus,...] [--out DIR] [--app PATH]
Exit status: failed checks. Use a phone of your own: the checks install, launch and terminate apps.
"""
import argparse
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_e2e import Mcp, els  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
APP = "com.x86sim.test.x86forms"


class Run:
    def __init__(self, m, app):
        self.m, self.app, self.fails, self._installed = m, app, [], None

    def check(self, name, ok, detail=""):
        print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail), flush=True)
        if not ok:
            self.fails.append(name)

    def launch(self, *args, wait="Sign up"):
        if self._installed is None:
            text, _, err, _ = self.m.call("app_install", path=self.app)
            self._installed = not err
            self.check("x86forms installed", self._installed, text[:200])
        if not self._installed:
            return False
        self.m.call("app_terminate", bundle_id=APP, after="none")
        text, _, err, _ = self.m.call("app_launch", bundle_id=APP, args=list(args), after="none")
        if err:
            self.check("x86forms launched %s" % " ".join(args), False, text[:300])
            return False
        return not self.m.call("wait_for", target=wait, timeout=60)[2]

    def state(self, ident):
        s, _ = self.m.snap()
        e = els(s, id="^%s$" % re.escape(ident))
        return (e[0].get("label") or e[0].get("value") or "") if e else ""

    # -- focus: type target= waits for the tapped field
    def focus(self):
        if not self.launch():
            return
        t1, _, e1, _ = self.m.call("type", target="Email", text="ann@example.com", after="none")
        t2, _, e2, _ = self.m.call("type", target="Password", text="hunter22", after="none")
        t3, _, e3, _ = self.m.call("type", target="id:name-field", text="Ann Lee", after="none")
        self.check("focus: three fields typed back to back", not (e1 or e2 or e3), " | ".join(t.split("\n")[0] for t in (t1, t2, t3)))
        self.check("focus: the answer names the field and its value", "ann@example.com" in t1 and "Email" in t1, t1.split("\n")[0])
        self.check("focus: a secure field's text is not echoed", "hunter22" not in t2 and "8 characters" in t2, t2.split("\n")[0])
        st = self.state("form-state")
        self.check("focus: each field got its own text", st == "name=Ann Lee email=ann@example.com password=8 city=", st)
        # a second type into the same field adds to it (no tap that would move the caret)
        t4, _, e4, _ = self.m.call("type", target="Email", text=".uk", after="none")
        st = self.state("form-state")
        self.check("focus: typing again into the focused field appends", not e4 and "email=ann@example.com.uk" in st, st)
        # a target that is not a text field: an error, nothing typed
        t5, _, e5, _ = self.m.call("type", target="Sign up", text="zzz", after="none")
        self.check("focus: a target that takes no focus is an error", e5 and "focus" in t5, t5.split("\n")[0])
        st = self.state("form-state")
        self.check("focus: nothing typed after the error", "zzz" not in st, st)

    # -- fill: a form in one call
    def fill(self):
        if not self.launch():
            return
        fields = [{"target": "Name", "text": "Bo Diaz"}, {"target": "Email", "text": "bo@example.com"},
                  {"target": "Password", "text": "s3cret!"}, {"target": "City", "text": "Lyon"},
                  {"target": "Notes", "text": "far down"}]
        text, _, err, dt = self.m.call("fill", fields=fields, submit="Sign Up", after="diff")
        self.check("fill: five fields and a submit tap", not err, "%.1f s: %s" % (dt, text[:600].replace("\n", " | ")))
        sub = self.state("submitted")
        self.check("fill: the app got every field", sub == "submitted: name=Bo Diaz email=bo@example.com password=7 city=Lyon notes=far down", sub)
        # filled again: fields are emptied first (no "Bo DiazBo Diaz"), Return submits the last one
        text, _, err, _ = self.m.call("fill", fields=[{"target": "Notes", "text": "again"}], submit=True, after="none")
        self.check("fill: Return as submit", not err and "Return pressed" in text, text[:300].replace("\n", " | "))
        # a field that does not exist: an error naming it
        text, _, err, _ = self.m.call("fill", fields=[{"target": "Email", "text": "x@y.z"}, {"target": "No such field", "text": "x"}], after="none")
        self.check("fill: a missing field is an error after the ones before it", err and "No such field" in text and "filled before it" in text, text[:300].replace("\n", " | "))

    # -- controls: set_value
    def controls(self):
        if not self.launch("controls", wait="volume="):
            return
        s, _ = self.m.snap()
        print("  controls: " + ", ".join("%s %s %s" % (e["ref"], e["role"], e.get("label") or e.get("id") or "") for e in s["elements"] if e.get("layer") == "app")[:900])
        # SwiftUI gives a wheel picker's columns no identifier: find them by what set_value info says they are
        wheels = {}
        for e in els(s, role="^adjustable$"):
            t = self.m.call("set_value", target="@" + e["ref"], info=True)[0]
            kind = re.search(r'"kind": "(\w+)"', t)
            mode = re.search(r'"mode": "(\w+)"', t)
            k = (kind.group(1) if kind else "") + (":" + mode.group(1) if mode else "")
            wheels.setdefault(k, "@" + e["ref"])
        print("  wheels: %s" % wheels)
        wheel_above = lambda ident: {"fruit-state": wheels.get("picker"), "day-state": wheels.get("datepicker:date"),
                                     "alarm-state": wheels.get("datepicker:time")}.get(ident) or "@none"
        cases = [("id:volume", "75%", "volume-state", "volume=75"), ("id:volume", "0.5", "volume-state", "volume=50"),
                 ("Wi-Fi", "on", "wifi-state", "wifi=on"), ("Count", 7, "count-state", "count=7"),
                 ("Count", "-2", "count-state", "count=5"), ("Medium", "Large", "size-state", "size=Large"),
                 (wheel_above("fruit-state"), "Mango", "fruit-state", "fruit=Mango"),
                 (wheel_above("day-state"), "2026-05-01", "day-state", "day=2026-05-01"),
                 (wheel_above("alarm-state"), "14:45", "alarm-state", "alarm=14:45"),
                 ("Wi-Fi", False, "wifi-state", "wifi=off")]
        for target, value, ident, want in cases:
            text, _, err, _ = self.m.call("set_value", target=target, value=value, after="none")
            got = self.state(ident)
            self.check("controls: %s = %r" % (target, value), not err and got == want, "%s | %s" % (text.split("\n")[0], got))
        text, _, err, _ = self.m.call("set_value", target="id:volume", value=75, after="none")
        self.check("controls: SwiftUI slider: a number outside 0..1 asks for a percentage", err and "%" in text, text.split("\n")[0])
        text, _, err, _ = self.m.call("set_value", target=wheel_above("fruit-state"), value="Kiwi", after="none")
        self.check("controls: a wheel without the row lists its rows", err and "Mango" in text and "Kiwi" in text, text.split("\n")[0][:200])
        self.check("controls: and stays where it was", self.state("fruit-state") == "fruit=Mango", self.state("fruit-state"))
        text, _, err, _ = self.m.call("set_value", target="Large", value="Huge", after="none")
        self.check("controls: a value it does not take names the ones it does", err and "Small" in text and "Large" in text, text.split("\n")[0])
        text, _, err, _ = self.m.call("set_value", target="id:volume", info=True)
        self.check("controls: info names the range", not err and '"max"' in text and "slider" in text, text.replace("\n", " ")[:200])

    # -- drag: reorder a list row, drag and drop
    def drag(self):
        if not self.launch("list", wait="order="):
            return
        s, _ = self.m.snap()
        app = [e for e in s["elements"] if e.get("layer") == "app"]
        print("  list: " + ", ".join("%s %s %s %s" % (e["ref"], e["role"], e.get("label") or e.get("id") or "", e["frame"]) for e in app)[:1200])
        # the reorder handle of Alpha's row (UIKit's reorder control: "Reorder Alpha"), else the row's right end
        alpha = els(s, label="^Alpha$")
        delta = els(s, label="^Delta$")
        handle = els(s, label="(?i)reorder.*alpha")
        if not alpha or not delta:
            self.check("drag: rows listed", False, "")
            return
        src = "@" + handle[0]["ref"] if handle else "%d,%d" % (s["screen"][0] - 30, alpha[0]["frame"][1] + alpha[0]["frame"][3] / 2)
        dy = delta[0]["frame"][1] + delta[0]["frame"][3] * 0.75
        dst = "%d,%d" % ((handle[0]["frame"][0] + handle[0]["frame"][2] / 2) if handle else s["screen"][0] - 30, dy)
        text, _, err, _ = self.m.call("drag", **{"from": src, "to": dst, "hold_ms": 300, "after": "none"})
        got = self.state("order-state")
        self.check("drag: Alpha moved below Delta", not err and got.startswith("order=Bravo,Charlie,Delta,Alpha"), "%s | %s" % (text.split("\n")[0], got))
        text, _, err, _ = self.m.call("drag", **{"from": "Parcel", "to": "id:dropbox", "after": "none"})
        got = self.state("dropbox")
        print("  first drop: %s" % got)
        if "nothing" in got:
            # the drag service (druid) starts on demand with the first drag: a second one finds it up
            text, _, err, _ = self.m.call("drag", **{"from": "Parcel", "to": "id:dropbox", "after": "none"})
            got = self.state("dropbox")
        self.check("drag: an item held and dropped on the drop box", not err and "Parcel" in got and "nothing" not in got, "%s | %s" % (text.split("\n")[0], got))

    # -- expect
    def expect(self):
        if not self.launch():
            return
        self.m.call("type", target="Name", text="Ann", after="none")
        ok = lambda **kw: not self.m.call("expect", **kw)[2]
        self.check("expect: the field beside \"Name\" has value Ann and the focus", ok(target="Name", value="Ann", focused=True))
        self.check("expect: contains", ok(target="id:form-state", contains="name=Ann"))
        self.check("expect: a button enabled", ok(target="Sign up", exists=True) and ok(target="Email", enabled=True))
        self.check("expect: gone", ok(target="Welcome back", exists=False))
        self.check("expect: count", ok(target="Sign up", count=1))
        text, _, err, _ = self.m.call("expect", target="Name", value="Bob")
        self.check("expect: a wrong value fails saying the value there", err and "FAIL" in text and "Ann" in text, text.split("\n")[0])
        text, _, err, _ = self.m.call("expect", target="Sigm up")
        self.check("expect: a missing element fails with the nearest by text", err and "nearest" in text and "Sign up" in text, text.split("\n")[0])
        # timeout: the app changes a moment later (Sign Up's result; fill moves the button clear of the keyboard)
        self.m.call("fill", fields=[{"target": "City", "text": "Oslo"}], submit="Sign Up", after="none")
        text, _, err, _ = self.m.call("expect", target="id:submitted", contains="name=Ann", timeout=10)
        self.check("expect: waits for the app with a timeout", not err, text.split("\n")[0])
        text, _, err, _ = self.m.call("wait_for", target="id:submitted", contains="nobody", timeout=1.5)
        self.check("wait_for: a condition that never holds times out as an error", err and "FAIL" in text, text.split("\n")[0])

    # -- batch
    def batch(self):
        if not self.launch():
            return
        steps = [{"tool": "app_terminate", "bundle_id": APP}, {"tool": "app_launch", "bundle_id": APP},
                 {"tool": "wait_for", "target": "Sign up", "timeout": 60},
                 {"tool": "type", "target": "Email", "text": "batch@example.com"},
                 {"tool": "expect", "target": "Email", "value": "batch@example.com"},
                 {"tool": "screenshot"}]
        r = self.m.rpc("tools/call", {"name": "batch", "arguments": {"phone": self.m.phone, "steps": steps}})["result"]
        text = "\n".join(c.get("text", "") for c in r.get("content", []) if c.get("type") == "text")
        imgs = [c for c in r.get("content", []) if c.get("type") == "image"]
        self.m.log.write("### batch\n%s\n\n" % text)
        lines = [l for l in text.split("\n") if re.match(r"^\d+\. ", l)]
        self.check("batch: six steps, no error", not r.get("isError") and len(lines) == 6 and "0 failed" in text, text.split("\n")[0])
        self.check("batch: the screenshot step's image is in the answer", len(imgs) == 1, str(len(imgs)))
        self.check("batch: the screen once, after the last step", text.count("device at2") <= 1 and "batch@example.com" in text.split("\n6. ")[-1], "")
        steps2 = [{"tool": "expect", "target": "Email", "value": "nobody"}, {"tool": "type", "target": "Email", "text": "zzz"}]
        text, _, err, _ = self.m.call("batch", steps=steps2)
        self.check("batch: stop_on_error stops at a failing expect", err and "stopped" in text and "2. type" not in text, text.split("\n")[0])
        text, _, err, _ = self.m.call("batch", steps=steps2, stop_on_error=False, after="none")
        self.check("batch: stop_on_error=false runs on", not err and "2. type" in text and "1 failed" in text, text.split("\n")[0])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.expanduser("~/scratch/x86sim/ax-actions"))
    ap.add_argument("--app", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim")), "apps/x86forms.app"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    log = open(os.path.join(a.out, "mcp-%s.log" % a.phone), "w")
    m = Mcp(a.mcp, a.phone, log)
    r = Run(m, a.app)
    only = set(filter(None, a.only.split(",")))
    want = lambda n: (not only or n in only)
    try:
        for name in ["focus", "fill", "controls", "drag", "expect", "batch"]:
            if want(name):
                getattr(r, name)()
    finally:
        m.call("app_terminate", bundle_id=APP, after="none")
        m.close()
    print("%d failed: %s" % (len(r.fails), ", ".join(r.fails)))
    sys.exit(len(r.fails))


if __name__ == "__main__":
    main()
