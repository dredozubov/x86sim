#!/usr/bin/env python3
"""x86Sim: end-to-end checks of what the snapshot reads from game engines (host/simax/simax_engines.m,
simax_unity.m; docs/protocols/SIMAX.md "Engines"), driven through x86sim-mcp over stdio on a running phone.

  sprite   SpriteKit (tests/apps/x86games): named nodes are `node` elements; hidden, off-view and unnamed nodes are
           not; a moving node keeps its ref; tap reaches a node; wait_for gone sees a removed one
  scene    SceneKit (the same app): named nodes with geometry are elements; covered, behind-the-camera and
           geometry-less (camera, light) nodes are not; a moving node keeps its ref; tap reaches a node
  vo       the screen-reader switch (tests/apps/x86vo: a stand-in engine as Frameworks/Flutter.framework): once the
           snapshot read the app, the engine's UIAccessibilityIsVoiceOverRunning() says yes and it was notified; the
           app's own code still sees VoiceOver off
  unityfake  the Unity reader against tests/apps/x86unity (a stand-in UnityFramework exporting IL2CPP's API over a small
           uGUI scene, not Unity): button, toggle, slider, input field, text and a game object are listed with keys;
           tap reaches a button; type goes into the focused input field through the component (onValueChanged,
           onEndEdit); the same with the object lookups stripped (X86UNITY_STRIPPED=1: the scene walk)
  flutter  a Flutter app (--flutter-app PATH --flutter-bundle ID; a device build goes through app_install's
           conversion): its semantics tree shows (buttons, text fields); --flutter-tap LABEL is tapped and
           --flutter-field LABEL typed into (--flutter-wait / -tapped / -typed: texts that say it worked). For
           tests/apps/flutter_demo (build.sh: a device .ipa): --flutter-app $X86SIM_SCRATCH/apps/flutter_demo.ipa
           --flutter-bundle com.x86sim.test.flutterDemo --flutter-wait "Taps: 0" --flutter-tap id:tap-button
           --flutter-tapped "Taps: 1" --flutter-field "Your name" --flutter-typed "Typed: x86sim"
  unity    a Unity IL2CPP game (--unity-app PATH --unity-bundle ID, the same -tap / -field / -wait options): elements
           from the IL2CPP reader (or the game's own accessibility), taps, typing through the component; --unity-submit
           presses Return after typing (Unity's keyboard bar covers the game until Done). The real game: the dev
           toolchain's shells/samples/unity-hello, exported and built on Linux (shells/unity/build.sh):
           --unity-bundle com.x86sim.dev.unityhello --unity-wait "Score: 0" --unity-tap Play --unity-tapped "Score: 1"
           --unity-field "Your name" --unity-typed "Name: x86sim" --unity-submit

Usage: tests/ax/games_e2e.py --phone NAME [--mcp PATH] [--only sprite,scene,vo,unityfake,...] [--out DIR] [--games-app PATH]
       [--vo-app PATH] [--unityfake-app PATH]
       (tests/apps/build.sh x86games; tests/apps/x86vo/build-vo.sh; tests/apps/x86unity/build-unity.sh)
flutter / unity run only when their app is given. Exit status: failed checks. Use a phone of your own.
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_e2e import ROOT, Mcp, Run, els  # noqa: E402

GAMES = "com.x86sim.test.x86games"
VO = "com.x86sim.test.x86vo"
UNITY = "com.x86sim.test.x86unity"


class Games(Run):
    def launch(self, path, bundle, wait, env=None):
        if path and not getattr(self, "_inst_" + bundle.replace(".", "_"), False):
            text, _, err, _ = self.m.call("app_install", path=path)
            self.check("%s installed" % bundle, not err, text[:200])
            if err:
                return False
            setattr(self, "_inst_" + bundle.replace(".", "_"), True)
        self.m.call("app_terminate", bundle_id=bundle, after="none")
        self.m.call("app_launch", bundle_id=bundle, env=env or {}, after="none")
        if wait:
            return not self.m.call("wait_for", target=wait, timeout=90)[2]
        time.sleep(8)
        return True

    def nodes(self, s, prefix):
        return [e for e in s["elements"] if e.get("role") == "node" and (e.get("key") or "").startswith(prefix)]

    def sprite(self, app):
        if not self.launch(app, GAMES, "sprite taps:"):
            self.check("sprite: app up", False)
            return
        self.m.call("wait_for", target="Player", timeout=20)
        s1, _ = self.m.snap()
        n = {e.get("label"): e for e in self.nodes(s1, "sk:")}
        self.check("sprite: named nodes listed", {"Player", "Enemy", "Coin"} <= set(n), sorted(n))
        self.check("sprite: hidden / off-view nodes left out", not ({"Secret", "Far"} & set(n)), sorted(n))
        self.check("sprite: keys", n.get("Player", {}).get("key") == "sk:Player#0", n.get("Player", {}).get("key"))
        e1 = n.get("Enemy")
        time.sleep(0.8)
        s2, _ = self.m.snap()
        e2 = {e.get("label"): e for e in self.nodes(s2, "sk:")}.get("Enemy")
        moved = bool(e1 and e2) and abs(e1["frame"][0] - e2["frame"][0]) > 2
        self.check("sprite: Enemy moves and keeps its ref", moved and e1["ref"] == e2["ref"],
                   "%s -> %s" % (e1 and (e1["ref"], e1["frame"]), e2 and (e2["ref"], e2["frame"])))
        self.m.call("tap", target="Player", after="none")
        self.check("sprite: tap Player reaches it", not self.m.call("wait_for", target="sprite taps: Player=1", timeout=10)[2])
        if e2:
            # (it moves about 90 pt/s: the ref's frame is looked up again at the tap)
            self.m.call("tap", target="@" + e2["ref"], after="none")
            ok = not self.m.call("wait_for", target="sprite taps: Enemy=1", timeout=10)[2]
            self.check("sprite: tap the moving Enemy by ref", ok)
        self.m.call("tap", target="Coin", after="none")
        ok = not self.m.call("wait_for", target="Coin", gone=True, timeout=10)[2]
        self.check("sprite: wait_for Coin gone after it was taken", ok)

    def scene(self, app):
        if not self.launch(app, GAMES, "scene taps:"):
            self.check("scene: app up", False)
            return
        self.m.call("wait_for", target="Crate", timeout=30)
        s1, _ = self.m.snap()
        n = {e.get("label"): e for e in self.nodes(s1, "scn:")}
        self.check("scene: named nodes listed", {"Crate", "Ball", "Wall"} <= set(n), sorted(n))
        self.check("scene: covered / behind / no-geometry nodes left out",
                   not ({"Hidden Box", "Behind", "camera", "light"} & set(n)), sorted(n))
        b1 = n.get("Ball")
        time.sleep(0.8)
        s2, _ = self.m.snap()
        b2 = {e.get("label"): e for e in self.nodes(s2, "scn:")}.get("Ball")
        moved = bool(b1 and b2) and abs(b1["frame"][0] - b2["frame"][0]) > 2
        self.check("scene: Ball moves and keeps its ref", moved and b1["ref"] == b2["ref"],
                   "%s -> %s" % (b1 and (b1["ref"], b1["frame"]), b2 and (b2["ref"], b2["frame"])))
        self.m.call("tap", target="Crate", after="none")
        self.check("scene: tap Crate reaches it", not self.m.call("wait_for", target="scene taps: Crate=1", timeout=10)[2])

    def vo(self, app):
        if not self.launch(app, VO, "engine voiceover:"):
            self.check("vo: app up", False)
            return
        ok = not self.m.call("wait_for", target="engine voiceover: on", timeout=15)[2]
        s, _ = self.m.snap()
        line = (els(s, id="^vo-line$") or [{}])[0].get("label") or ""
        self.check("vo: the engine sees VoiceOver on after the first snapshot", ok, line)
        self.check("vo: the engine was told (status notification)", "notified: 0" not in line and "notified:" in line, line)
        self.check("vo: the app's own code still sees it off", "app voiceover: off" in line, line)

    def unityfake(self, app, stripped):
        tag = "unityfake%s" % (" stripped" if stripped else "")
        if not self.launch(app, UNITY, "Score: 0", {"X86UNITY_STRIPPED": "1"} if stripped else None):
            self.check("%s: app up (the reader lists Score: 0)" % tag, False)
            return
        s, _ = self.m.snap()
        mine = [e for e in s["elements"] if e.get("app") == UNITY]
        got = {(e.get("role"), e.get("label"), e.get("value")) for e in mine}
        want = {("button", "Play", None), ("switch", "Sound", "1"), ("adjustable", "Volume", "0.25"),
                ("textfield", "Your name", None), ("text", "Score: 0", None), ("node", "Player", None)}
        self.check("%s: uGUI controls, text and game objects listed" % tag, want <= got, sorted(map(str, got)))
        self.check("%s: inactive objects and controls' own text left out" % tag,
                   not any(l in ("Ghost", "Play") and r in ("node", "text") for r, l, _ in got), sorted(map(str, got)))
        self.check("%s: keys are instance ids" % tag, all((e.get("key") or "").startswith("unity:") for e in mine),
                   [e.get("key") for e in mine][:8])
        self.m.call("tap", target="Play", after="none")
        self.check("%s: tap Play reaches the button" % tag, not self.m.call("wait_for", target="Score: 1", timeout=10)[2])
        self.m.call("tap", target="Your name", after="none")
        time.sleep(1)
        text, _, err, _ = self.m.call("type", text="Ada", after="none")
        ok = not err and not self.m.call("wait_for", target="Name: Ada ended 1", timeout=10)[2]
        self.check("%s: type into the focused input field (set_text, onEndEdit)" % tag, ok, text[:200])
        s, _ = self.m.snap()
        f = [e for e in s["elements"] if e.get("app") == UNITY and e.get("role") == "textfield"]
        self.check("%s: the field's value" % tag, bool(f) and f[0].get("value") == "Ada", f and str(f[0]))
        # with a target: the tap's focus is the engine's (no UIKit first responder behind it)
        text, _, err, dt = self.m.call("type", target="Your name", text="Bo", clear=True, after="none")
        ok = not err and not self.m.call("wait_for", target="Name: Bo", timeout=10)[2]
        self.check("%s: type target= into the input field" % tag, ok and dt < 5, "%.1f s: %s" % (dt, text[:200]))
        text, _, err, _ = self.m.call("fill", fields=[{"target": "Your name", "text": "Cy"}], after="none")
        ok = not err and not self.m.call("wait_for", target="Name: Cy", timeout=10)[2]
        self.check("%s: fill the input field" % tag, ok, text[:200])

    def engine_app(self, name, app, bundle, tap, field, wait=None, tapped=None, typed=None, submit=False):
        if not self.launch(app, bundle, None):
            return
        # the first snapshot is the first tree request: the screen-reader switch turns on then; the tree comes after
        s0, _ = self.m.snap()
        first = len([e for e in s0["elements"] if e.get("app") == bundle])
        if wait:
            self.m.call("wait_for", target=wait, timeout=30)
        s, _ = self.m.snap()
        mine = [e for e in s["elements"] if e.get("app") == bundle]
        roles = sorted({e.get("role") for e in mine})
        self.check("%s: elements from the app" % name, len(mine) >= 2,
                   "%d elements at the first snapshot, %d after; roles %s" % (first, len(mine), roles))
        if tap:
            text, _, err, _ = self.m.call("tap", target=tap)
            self.check("%s: tap %r" % (name, tap), not err, text[:200])
            if tapped:
                ok = not self.m.call("wait_for", target=tapped, timeout=10)[2]
                self.check("%s: the tap reached the app (%r)" % (name, tapped), ok)
        if field:
            self.m.call("tap", target=field, after="none")
            time.sleep(1.5)
            text, _, err, _ = self.m.call("type", text="x86sim", **({"submit": True} if submit else {}))
            self.check("%s: type into %r" % (name, field), not err and "x86sim" in text, text[:300])
            if typed:
                ok = not self.m.call("wait_for", target=typed, timeout=10)[2]
                self.check("%s: the app got the text (%r)" % (name, typed), ok)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.expanduser("~/scratch/x86sim/ax-e2e"))
    sc = os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim"))
    ap.add_argument("--games-app", default=os.path.join(sc, "apps/x86games.app"))
    ap.add_argument("--vo-app", default=os.path.join(sc, "apps/x86vo.app"))
    ap.add_argument("--unityfake-app", default=os.path.join(sc, "apps/x86unity.app"))
    for e in ("flutter", "unity"):
        ap.add_argument("--%s-app" % e)
        ap.add_argument("--%s-bundle" % e)
        ap.add_argument("--%s-tap" % e)
        ap.add_argument("--%s-field" % e)
        ap.add_argument("--%s-wait" % e, help="text to wait for once the app is up")
        ap.add_argument("--%s-tapped" % e, help="text the app shows after the tap")
        ap.add_argument("--%s-typed" % e, help="text the app shows after typing x86sim")
        ap.add_argument("--%s-submit" % e, action="store_true",
                        help="press Return after typing (Unity's iOS keyboard bar covers the game until Done)")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    m = Mcp(a.mcp, a.phone, open(os.path.join(a.out, "games-%s.log" % a.phone), "w"))
    r = Games(m, a.out)
    only = set(filter(None, a.only.split(",")))
    want = lambda n: (not only or n in only)
    try:
        if want("sprite"):
            r.sprite(a.games_app)
        if want("scene"):
            r.scene(a.games_app)
        if want("vo"):
            r.vo(a.vo_app)
        if want("unityfake"):
            r.unityfake(a.unityfake_app, False)
            r.unityfake(a.unityfake_app, True)
        if want("flutter") and a.flutter_bundle:
            r.engine_app("flutter", a.flutter_app, a.flutter_bundle, a.flutter_tap, a.flutter_field, a.flutter_wait,
                         a.flutter_tapped, a.flutter_typed)
        if want("unity") and a.unity_bundle:
            r.engine_app("unity", a.unity_app, a.unity_bundle, a.unity_tap, a.unity_field, a.unity_wait, a.unity_tapped,
                         a.unity_typed, a.unity_submit)
    finally:
        m.close()
    print("%d failed: %s" % (len(r.fails), ", ".join(r.fails)))
    sys.exit(len(r.fails))


if __name__ == "__main__":
    main()
