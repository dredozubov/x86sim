#!/usr/bin/env python3
"""x86Sim: end-to-end checks of text read from pixels (OCR) and of screenshots that point at elements, through the MCP
server (x86sim-mcp over stdio) on a running phone, with tests/apps/x86pixels and tests/ax/pixels/canvas.html (served
from this machine; the phone reaches it at 127.0.0.1).

  metal     a full-screen MTKView with no accessibility: snapshot reads its text by itself ([ocr] elements: precision
            and recall against the strings the app draws, OCR time); refs stay across snapshots; tap "Start Game" hits
            the drawn button and wait_for sees "Tapped Start Game"
  drawn     text a plain view draws (not a Metal view): not read by default; snapshot ocr=true adds it, but not the
            real button's label; tap "High Scores" finds it through OCR on its own
  canvas    a canvas game menu in Safari: the canvas is read by itself, the page's heading stays a DOM element; a tap on
            the drawn "Play Now" reaches the page's click handler
  marks     screenshot marks=true / actionable: a PNG with as many marks as elements, the refs listed beside it;
            target=@ref: a crop of that element; the browser page's screenshot with marks (a private x86sim-serve)

Usage: tests/ax/pixels_e2e.py --phone NAME [--mcp PATH] [--app PATH] [--out DIR] [--port 7441] [--only metal,drawn,...]
The app: tests/apps/build.sh x86pixels (default $X86SIM_SCRATCH/apps/x86pixels.app). Results: OUT/results.json
(per screen: precision, recall, OCR ms), the screenshots, OUT/mcp.log. Exit status: failed checks.
"""
import argparse
import base64
import functools
import http.server
import json
import os
import re
import struct
import subprocess
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BID = "com.x86sim.test.x86pixels"
MENU = ["PIXEL QUEST", "Score: 1250", "Start Game", "Options", "High Scores", "Choose an option"]
CANVAS = ["CANVAS GAME", "Level 3", "Play Now", "Settings", "Quit", "Pick one"]


class Mcp:
    def __init__(self, path, phone, log):
        self.p = subprocess.Popen([path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.phone, self.log, self.n = phone, log, 0
        self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "pixels_e2e", "version": "1"}})

    def rpc(self, method, params):
        self.n += 1
        self.p.stdin.write(json.dumps({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params}) + "\n")
        while True:
            line = self.p.stdout.readline()
            if not line:
                raise RuntimeError("x86sim-mcp exited")
            m = json.loads(line)
            if m.get("id") == self.n:
                return m

    def call(self, tool, **args):
        """(text, structured, error, images)"""
        args.setdefault("phone", self.phone)
        t0 = time.monotonic()
        r = self.rpc("tools/call", {"name": tool, "arguments": args})["result"]
        text = "\n".join(c.get("text", "") for c in r.get("content", []) if c.get("type") == "text")
        imgs = [base64.b64decode(c["data"]) for c in r.get("content", []) if c.get("type") == "image"]
        self.log.write("### %s %s (%.2f s)\n%s%s\n\n" % (tool, json.dumps(args), time.monotonic() - t0, text, "".join(" [image %d bytes]" % len(i) for i in imgs)))
        self.log.flush()
        return text, r.get("structuredContent"), bool(r.get("isError")), imgs


fails = 0
results = {}


def check(name, ok, detail=""):
    global fails
    print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail), flush=True)
    if not ok:
        fails += 1


def norm(s):
    return re.sub(r"[^0-9a-z]", "", s.lower())


def score(expected, read):
    """precision (read strings that are expected ones), recall (expected strings read), exact match on letters and
    digits (case and punctuation blind)"""
    e = {norm(x) for x in expected}
    r = [norm(x) for x in read]
    hit = [x for x in r if x in e]
    return (len(hit) / len(r) if r else 0.0), (len(e & set(r)) / len(e)), sorted(set(read))


def snap(m, **kw):
    t, s, err, _ = m.call("snapshot", json=True, **kw)
    return t, (s or {}), err


def ocr_labels(s, app=None):
    return [e.get("label", "") for e in s.get("elements", []) if e.get("ocr") and (app is None or e.get("app") == app)]


def png_size(b):
    return struct.unpack(">II", b[16:24]) if b[:8] == b"\x89PNG\r\n\x1a\n" else (0, 0)


def t_metal(m, a):
    m.call("app_terminate", bundle_id=BID, after="none")
    m.call("app_launch", bundle_id=BID, after="none")
    time.sleep(4)
    t, s, err = snap(m)
    labels = ocr_labels(s, BID)
    p, r, got = score(MENU, labels)
    o = s.get("ocr") or {}
    results["metal"] = {"precision": p, "recall": r, "ocr_ms": o.get("ms"), "read": got, "views": o.get("views")}
    check("metal-front", (s.get("front") or [""])[0] == BID, str(s.get("front")))
    check("metal-auto-ocr", r >= 5 / 6 and p >= 0.8, "precision %.2f recall %.2f %s ms: %s" % (p, r, o.get("ms"), got))
    check("metal-tag", "[ocr]" in t, "")
    refs = {e["label"]: e["ref"] for e in s.get("elements", []) if e.get("ocr")}
    _, s2, _ = snap(m)
    refs2 = {e["label"]: e["ref"] for e in s2.get("elements", []) if e.get("ocr")}
    check("metal-refs-stable", refs and all(refs2.get(k) == v for k, v in refs.items()), "%s / %s" % (refs, refs2))
    check("metal-cached", (s2.get("ocr") or {}).get("cached") is True, str(s2.get("ocr")))
    t, _, err, _ = m.call("tap", target="Start Game")
    check("metal-tap", not err and "Start Game" in t.split("\n")[0], t.split("\n")[0])
    t, _, err, _ = m.call("wait_for", target="Tapped Start Game", timeout=8)
    check("metal-wait-for", not err, t.split("\n")[0])


def t_drawn(m, a):
    m.call("app_terminate", bundle_id=BID, after="none")
    m.call("app_launch", bundle_id=BID, args=["cg"], after="none")
    time.sleep(4)
    _, s, _ = snap(m)
    check("drawn-not-automatic", not ocr_labels(s, BID), str(ocr_labels(s, BID)))
    check("drawn-real-button", any(e.get("label") == "Real Button" and not e.get("ocr") for e in s.get("elements", [])), "")
    _, s, _ = snap(m, ocr=True)
    labels = ocr_labels(s)
    p, r, got = score(MENU, labels)
    o = s.get("ocr") or {}
    results["drawn"] = {"precision": p, "recall": r, "ocr_ms": o.get("ms"), "read": got}
    check("drawn-ocr-true", r >= 5 / 6 and p >= 0.8, "precision %.2f recall %.2f %s ms: %s" % (p, r, o.get("ms"), got))
    check("drawn-no-duplicate", "realbutton" not in [norm(x) for x in labels], "")
    m.call("snapshot")  # a plain snapshot: the OCR text is not in it; tap must find it again by itself
    t, _, err, _ = m.call("tap", target="High Scores")
    check("drawn-tap-by-text", not err and "High Scores" in t.split("\n")[0], t.split("\n")[0])
    t, _, err, _ = m.call("wait_for", target="Tapped High Scores", timeout=8)
    check("drawn-wait-for", not err, t.split("\n")[0])


def serve(port):
    h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=os.path.join(ROOT, "tests/ax/pixels"))
    h.log_message = lambda *x: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), h)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def t_canvas(m, a):
    srv = serve(a.port)
    try:
        m.call("open_url", url="http://127.0.0.1:%d/canvas.html?%d" % (a.port, int(time.time())))
        m.call("wait_for", target="Canvas page", timeout=20)
        time.sleep(1.5)
        _, s, _ = snap(m)
        labels = ocr_labels(s)
        p, r, got = score(CANVAS, labels)
        o = s.get("ocr") or {}
        results["canvas"] = {"precision": p, "recall": r, "ocr_ms": o.get("ms"), "read": got, "views": o.get("views")}
        check("canvas-auto-ocr", r >= 5 / 6 and p >= 0.8, "precision %.2f recall %.2f %s ms: %s" % (p, r, o.get("ms"), got))
        check("canvas-heading-is-dom", any(e.get("label") == "Canvas page" and e.get("web") and not e.get("ocr") for e in s.get("elements", [])), "")
        check("canvas-no-element", not any(e.get("role") == "canvas" for e in s.get("elements", [])), "")
        t, _, err, _ = m.call("tap", target="Play Now")
        check("canvas-tap", not err, t.split("\n")[0])
        t, _, err, _ = m.call("wait_for", target="Clicked Play Now", timeout=8)
        check("canvas-click-reached", not err, t.split("\n")[0])
    finally:
        srv.shutdown()


def t_marks(m, a):
    m.call("app_terminate", bundle_id=BID, after="none")
    m.call("app_launch", bundle_id=BID, args=["cg"], after="none")
    time.sleep(3)
    _, s, _ = snap(m)
    n_all = len([e for e in s["elements"] if not e.get("offscreen") and e.get("layer") != "status" and e["frame"][2] * e["frame"][3] < 0.9 * s["screen"][0] * s["screen"][1]])
    t, _, err, imgs = m.call("screenshot", marks=True)
    ok = not err and imgs and png_size(imgs[0])[0] > 0
    if ok:
        open(os.path.join(a.out, "marks-drawn.png"), "wb").write(imgs[0])
    n = int((re.search(r"(\d+) marks", t) or [0, -1])[1])
    check("marks-all", ok and n == n_all and "@e" in t, "%d marks for %d elements" % (n, n_all))
    t, _, err, imgs = m.call("screenshot", marks="actionable", ocr=True)
    if imgs:
        open(os.path.join(a.out, "marks-drawn-actionable-ocr.png"), "wb").write(imgs[0])
    n2 = int((re.search(r"(\d+) marks", t) or [0, -1])[1])
    check("marks-actionable-ocr", not err and n2 >= 5, "%d marks (Real Button + the [ocr] menu)" % n2)
    ref = next((e["ref"] for e in s["elements"] if e.get("label") == "Real Button"), None)
    t, _, err, imgs = m.call("screenshot", target="@%s" % ref)
    w, h = png_size(imgs[0]) if imgs else (0, 0)
    if imgs:
        open(os.path.join(a.out, "target-real-button.png"), "wb").write(imgs[0])
    check("target-crop", not err and 0 < w < 300 and 0 < h < 150, "%s: %dx%d" % (ref, w, h))
    t, _, err, imgs = m.call("screenshot", target="Start Game")
    check("target-ocr-text", not err and imgs, t)
    # the browser page's screenshot with marks: a private share server
    if a.serve:
        port = a.port + 1
        rt = os.path.join(a.out, "serve")
        env = dict(os.environ, XDG_RUNTIME_DIR=rt + "/rt", XDG_STATE_HOME=rt + "/state")
        os.makedirs(rt + "/rt", mode=0o700, exist_ok=True)
        p = subprocess.Popen([a.serve, "--listen", "127.0.0.1:%d" % port], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            import urllib.request
            st = None
            for _ in range(40):
                try:
                    st = json.load(urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:%d/api/phones" % port, headers={"X-X86sim": "1"}), timeout=3))
                    break
                except Exception:
                    time.sleep(0.5)
            pid = next((x["id"] for x in st or [] if x.get("name") == a.phone), None)
            b = urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:%d/api/phones/%s/screenshot.png?marks=all" % (port, pid), headers={"X-X86sim": "1"}), timeout=60).read()
            open(os.path.join(a.out, "share-marks.png"), "wb").write(b)
            check("share-marks", png_size(b)[0] > 0, "%dx%d" % png_size(b))
        except Exception as e:
            check("share-marks", False, repr(e))
        finally:
            p.terminate()
            p.wait(10)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--serve", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-serve"), help="x86sim-serve for the share check ('' to skip)")
    ap.add_argument("--app", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch")), "apps/x86pixels.app"))
    ap.add_argument("--out", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch")), "pixels-e2e"))
    ap.add_argument("--port", type=int, default=7441)
    ap.add_argument("--only", default="metal,drawn,canvas,marks")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    m = Mcp(a.mcp, a.phone, open(os.path.join(a.out, "mcp.log"), "w"))
    _, _, err, _ = m.call("app_install", path=a.app)
    check("install", not err)
    for t in a.only.split(","):
        try:
            globals()["t_" + t](m, a)
        except Exception as e:
            check(t, False, "exception %r" % e)
    m.call("app_terminate", bundle_id=BID, after="none")
    json.dump(results, open(os.path.join(a.out, "results.json"), "w"), indent=1)
    print(json.dumps(results, indent=1))
    print("%d failed" % fails)
    sys.exit(min(fails, 100))


if __name__ == "__main__":
    main()
