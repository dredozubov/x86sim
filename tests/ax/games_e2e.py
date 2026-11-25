#!/usr/bin/env python3
"""x86Sim: end-to-end checks of what the snapshot reads from game engines (host/simax/simax_engines.m,
simax_unity.m; docs/protocols/SIMAX.md "Engines"), driven through x86sim-mcp over stdio on a running phone.

  sprite   SpriteKit (tests/apps/x86games): named nodes are `node` elements; hidden, off-view and unnamed nodes are
           not; a moving node keeps its ref; tap reaches a node; wait_for gone sees a removed one
  scene    SceneKit (the same app): named nodes with geometry are elements; covered, behind-the-camera and
           geometry-less (camera, light) nodes are not; a moving node keeps its ref; tap reaches a node

Usage: tests/ax/games_e2e.py --phone NAME [--mcp PATH] [--only sprite,scene] [--out DIR] [--games-app PATH]  (tests/apps/build.sh x86games)
Exit status: failed checks. Use a phone of your own.
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_e2e import ROOT, Mcp, Run, els  # noqa: E402

GAMES = "com.x86sim.test.x86games"


class Games(Run):
    def launch(self, path, bundle, wait):
        if path and not getattr(self, "_inst_" + bundle.replace(".", "_"), False):
            text, _, err, _ = self.m.call("app_install", path=path)
            self.check("%s installed" % bundle, not err, text[:200])
            if err:
                return False
            setattr(self, "_inst_" + bundle.replace(".", "_"), True)
        self.m.call("app_terminate", bundle_id=bundle, after="none")
        self.m.call("app_launch", bundle_id=bundle, after="none")
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
            # (it moves about 90 pt/s: a touch that comes late can miss it at a turn; up to three tries)
            for tries in range(1, 4):
                self.m.call("tap", target="@" + e2["ref"], after="none")
                ok = not self.m.call("wait_for", target="Enemy=", timeout=5)[2]
                if ok:
                    break
            self.check("sprite: tap the moving Enemy by ref", ok, "%d tries" % tries)
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.expanduser("~/scratch/x86sim/ax-e2e"))
    sc = os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim"))
    ap.add_argument("--games-app", default=os.path.join(sc, "apps/x86games.app"))
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
    finally:
        m.close()
    print("%d failed: %s" % (len(r.fails), ", ".join(r.fails)))
    sys.exit(len(r.fails))


if __name__ == "__main__":
    main()
