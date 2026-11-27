#!/usr/bin/env python3
"""x86Sim: end-to-end checks of the network capture tools (x86sim-mcp over stdio: net_capture, net_log, net_request,
net_mock; host/simnet + libsimshim's connection records, docs/protocols/NET.md) on a running phone, with
tests/apps/x86netcap talking to tests/ax/netserve.py on this machine (the phone reaches it at 127.0.0.1).

  capture   capture on with relaunch: the hook says hello; one Run press is recorded: GET JSON, POST JSON (request
            body and headers, the echoed response header), a PNG (binary body as base64), a redirect (302 with
            redirect_to, then the target), HTTPS (example.com, when the host has internet), a refused connection
            (ERR), an upload (PUT, 4096 bytes from a stream), an ephemeral session's request, a raw TCP connection
  log       net_log filters (status:3xx, method:POST, error, -word), since an id, follow_s waits for new requests
  request   net_request: headers both ways, bodies, timings, sizes
  mock      net_mock: an answer (status + JSON body), a body_file, offline / dns / timeout failures, latency on a real
            request, rules applied to the running app at once; clear restores the real answers
  share     the browser page's Network routes (a private x86sim-serve): the list, one request, mocks; a view link is
            refused (requests carry tokens and bodies)
  off       capture off: new requests are not recorded and still work

Usage: tests/ax/net_e2e.py --phone NAME [--mcp PATH] [--app PATH] [--out DIR] [--port 7431]
The app: tests/apps/build.sh x86netcap (default $X86SIM_SCRATCH/apps/x86netcap.app). Exit status: failed checks.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BID = "com.x86sim.test.x86netcap"


class Mcp:
    def __init__(self, path, phone, log):
        self.p = subprocess.Popen([path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.phone, self.log, self.n = phone, log, 0
        self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "net_e2e", "version": "1"}})

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
        """(text, structured, error)"""
        args.setdefault("phone", self.phone)
        t0 = time.monotonic()
        r = self.rpc("tools/call", {"name": tool, "arguments": args})["result"]
        text = "\n".join(c.get("text", "") for c in r.get("content", []) if c.get("type") == "text")
        self.log.write("### %s %s (%.2f s)\n%s\n\n" % (tool, json.dumps(args), time.monotonic() - t0, text))
        self.log.flush()
        return text, r.get("structuredContent"), bool(r.get("isError"))

    def ok(self, tool, **args):
        t, s, err = self.call(tool, **args)
        if err:
            raise RuntimeError("%s: %s" % (tool, t))
        return t, s

    def close(self):
        self.p.stdin.close()
        self.p.wait(10)


results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail), flush=True)


def label(m, ident):
    """the text of the element with that identifier"""
    t, s = m.ok("snapshot", json=True)
    for e in (s or {}).get("elements", []):
        if e.get("id") == ident:
            return e.get("label") or e.get("value") or ""
    return None


def run_once(m, timeout=40):
    """press Run and wait until every result is in; answers {name: text}"""
    before = label(m, "runs") or ""
    n0 = int(re.search(r"runs (\d+)", before).group(1)) if re.search(r"runs (\d+)", before) else 0
    m.ok("tap", target="id:run", after="none")
    end = time.time() + timeout
    while time.time() < end:
        t, s = m.ok("snapshot", json=True)
        got = {e["id"][2:]: e.get("label", "") for e in s.get("elements", []) if (e.get("id") or "").startswith("r-")}
        runs = next((e.get("label", "") for e in s.get("elements", []) if e.get("id") == "runs"), "")
        mm = re.search(r"runs (\d+) done (\d+)", runs)
        if mm and int(mm.group(1)) > n0 and int(mm.group(2)) >= 9:
            return got
        time.sleep(0.5)
    return got


def entries(m, **kw):
    t, s = m.ok("net_log", app=BID, json=True, limit=1000, **kw)
    return s["requests"]


def find(es, method, path_re, kind="request"):
    return [e for e in es if e["kind"] == kind and e["method"] == method and re.search(path_re, e["url"])]


def share_check(a, bindir, es):
    w = os.path.join(a.out, "serve")
    os.makedirs(os.path.join(w, "run"), mode=0o700, exist_ok=True)
    os.makedirs(os.path.join(w, "state"), exist_ok=True)
    env = dict(os.environ, XDG_RUNTIME_DIR=os.path.join(w, "run"), XDG_STATE_HOME=os.path.join(w, "state"))
    r = subprocess.run([os.path.join(bindir, "x86sim-serve"), "--bg", "--listen", "127.0.0.1:%d" % a.serve_port], env=env, capture_output=True, text=True)
    stf = os.path.join(w, "run", "x86sim-serve.json")
    if r.returncode != 0 or not os.path.exists(stf):
        return check("share.start", False, r.stdout + r.stderr)
    st = json.load(open(stf))
    port, tok, pid = st["port"], st["control_token"], st["pid"]

    def call(method, path, t=tok, body=None):
        req = urllib.request.Request("http://127.0.0.1:%d%s" % (port, path), method=method, data=json.dumps(body).encode() if body is not None else None,
                                     headers={"X-X86sim": "1", "Content-Type": "application/json", "Authorization": "Bearer " + t})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, json.loads(resp.read() or b"null")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"null")
    try:
        dev = "device-a64-" + a.phone
        code, v = call("GET", "/api/phones/%s/net/log" % dev)
        ids = [e["id"] for e in (v or {}).get("entries", [])]
        check("share.log", code == 200 and es and es[-1]["id"] in ids and BID in v.get("apps", []), "%d, %d entries" % (code, len(ids)))
        rq = next((e for e in es if e["method"] == "POST"), None)
        if rq:
            code, d = call("GET", "/api/phones/%s/net/request?id=%s" % (dev, rq["id"]))
            check("share.request", code == 200 and d.get("req_headers", {}).get("X-Test") == "netcap", str(code))
        code, d = call("POST", "/api/phones/%s/net/mock" % dev, body={"url": "/never", "status": 204, "body_file": "/etc/hostname"})
        check("share.mock", code == 200 and "body_b64" not in d and d.get("status") == 204, json.dumps(d))
        call("POST", "/api/phones/%s/net/mock" % dev, body={"clear": True})
        code, l = call("POST", "/api/links", body={"phone": dev, "role": "view", "ttl_s": 600})
        code, v = call("GET", "/api/phones/%s/net/log" % dev, t=l["token"]) if code == 200 else (0, None)
        check("share.viewlink", code == 403, str(code))
    finally:
        try:
            os.kill(pid, 15)
        except OSError:
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phone", required=True)
    ap.add_argument("--mcp", default=os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp"))
    ap.add_argument("--app", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim")), "apps/x86netcap.app"))
    ap.add_argument("--out", default=os.path.join(os.environ.get("X86SIM_SCRATCH", os.path.expanduser("~/scratch/x86sim")), "net_e2e"))
    ap.add_argument("--port", type=int, default=7431)
    ap.add_argument("--serve-port", type=int, default=7394, help="the private x86sim-serve of the share checks")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    srv = subprocess.Popen([sys.executable, os.path.join(ROOT, "tests/ax/netserve.py"), "--port", str(a.port)],
                           stderr=open(os.path.join(a.out, "netserve.log"), "w"))
    log = open(os.path.join(a.out, "mcp.log"), "w")
    m = Mcp(a.mcp, a.phone, log)
    try:
        m.ok("app_install", path=a.app)
        m.ok("net_mock", action="clear")
        m.ok("net_capture", app=BID, action="off")
        m.ok("net_log", clear=True)

        # ---- capture
        t, s = m.ok("net_capture", app=BID, action="on", relaunch=True)
        check("capture.hooked", s and s.get("hooked") is True, t)
        m.ok("wait_for", target="id:run", timeout=30)
        got = run_once(m)
        check("app.ran", got.get("json", "").startswith("json 200"), json.dumps(got))
        time.sleep(1.5)  # the connection record is written at close; the last request record a moment after
        es = entries(m)
        j = find(es, "GET", r"/json$")
        check("capture.get", j and j[-1]["status"] == 200 and j[-1]["size"] and j[-1]["duration_ms"] is not None, j and j[-1]["url"])
        p = find(es, "POST", r"/echo$")
        check("capture.post", p and p[-1]["status"] == 200, p and p[-1]["id"])
        img = find(es, "GET", r"/image\.png$")
        check("capture.image", img and img[-1]["status"] == 200 and img[-1]["size"] == 165, img and img[-1]["size"])
        red = find(es, "GET", r"/redirect$")
        tgt = find(es, "GET", r"/json\?from=redirect$")
        check("capture.redirect", red and red[-1]["status"] == 302 and tgt and tgt[-1]["status"] == 200,
              "%s / %s" % (red and red[-1]["status"], tgt and tgt[-1]["status"]))
        hs = find(es, "GET", r"^https://example\.com/")
        if got.get("https", "").startswith("https 200"):
            check("capture.https", hs and hs[-1]["status"] == 200, hs and hs[-1]["id"])
        else:
            print("SKIP capture.https (no internet from the phone: %s)" % got.get("https"))
        f = find(es, "GET", r"127\.0\.0\.1:1/")
        check("capture.fail", f and f[-1]["status"] is None and f[-1]["error"], f and f[-1]["error"])
        up = find(es, "PUT", r"/upload$")
        check("capture.upload", up and up[-1]["status"] == 200, up and up[-1]["id"])
        eph = find(es, "GET", r"session=ephemeral")
        check("capture.ephemeral", eph and eph[-1]["status"] == 200, eph and eph[-1]["id"])
        conns = [e for e in es if e["kind"] == "conn" and e["url"].endswith(":%d" % a.port)]
        check("capture.conn", conns and any(c["size"] and c["size"] > 50 for c in conns), json.dumps([c["url"] + " in=" + str(c["size"]) for c in conns[-3:]]))

        # ---- request details
        if p:
            t, _ = m.ok("net_request", id=p[-1]["id"])
            r = json.loads(t)
            check("request.post", '"hello":"world"' in r.get("req_body", "") and r.get("req_headers", {}).get("X-Test") == "netcap"
                  and r.get("resp_headers", {}).get("X-Echo-Header") == "netcap" and r.get("resp_body", "").startswith("{")
                  and r.get("timing", {}).get("total") is not None, json.dumps({k: r.get(k) for k in ("req_headers", "resp_headers", "timing", "protocol")}))
        if img:
            r = json.loads(m.ok("net_request", id=img[-1]["id"])[0])
            check("request.binary", r.get("resp_body_b64") is True and r.get("mime") == "image/png", r.get("mime"))
        if up:
            r = json.loads(m.ok("net_request", id=up[-1]["id"])[0])
            check("request.upload", r.get("req_body_size") == 4096 and '"received": 4096' in r.get("resp_body", ""), "%s %s" % (r.get("req_body_size"), r.get("resp_body")))
        if red:
            r = json.loads(m.ok("net_request", id=red[-1]["id"])[0])
            check("request.redirect", (r.get("redirect_to") or "").endswith("/json?from=redirect"), r.get("redirect_to"))

        # ---- log filters, since, follow
        t, _ = m.ok("net_log", app=BID, filter="status:3xx")
        check("log.status", t.strip() and all(" 302 " in l for l in t.strip().splitlines()), t)
        t, _ = m.ok("net_log", app=BID, filter="method:POST")
        check("log.method", t.strip() and all(" POST " in l for l in t.strip().splitlines()), t)
        t, _ = m.ok("net_log", app=BID, filter="error")
        check("log.error", "127.0.0.1:1/" in t and " 200 " not in t, t)
        t, _ = m.ok("net_log", app=BID, filter="kind:request -json")
        check("log.exclude", t.strip() and "json" not in t.lower(), t)
        last = es[-1]["id"]
        t, _ = m.ok("net_log", app=BID, since=last)
        check("log.since", "/json" not in t, t[:200])
        m.ok("tap", target="id:run", after="none")
        t0 = time.time()
        t, _ = m.ok("net_log", app=BID, since=last, follow_s=20, filter="kind:request")
        check("log.follow", "/json" in t and time.time() - t0 < 20, "%.1f s: %s" % (time.time() - t0, t[:200]))
        run_wait = time.time() + 20
        while time.time() < run_wait and "socket ok" not in (label(m, "r-socket") or ""):
            time.sleep(0.5)

        # ---- mocks
        body_file = os.path.join(a.out, "upload-mock.json")
        with open(body_file, "w") as fh:
            fh.write('{"mocked_upload": true}')
        m.ok("net_mock", url="/json", method="GET", status=503, body={"mocked": True}, headers={"X-Mock": "1"})
        m.ok("net_mock", url="*/image.png", fail="offline")
        m.ok("net_mock", url="/redirect", fail="dns")
        m.ok("net_mock", url="re:/echo$", method="POST", fail="timeout")
        m.ok("net_mock", url="/upload", method="PUT", body_file=body_file)
        m.ok("net_mock", url="session=ephemeral", latency_ms=1500)
        t, s = m.ok("net_mock", action="list")
        check("mock.list", len(s["rules"]) == 6, t)
        mark = entries(m)[-1]["id"]
        got = run_once(m)
        check("mock.answer", got.get("json", "").startswith("json 503"), got.get("json"))
        check("mock.offline", got.get("image") == "image ERR -1009", got.get("image"))
        check("mock.dns", got.get("redirect") == "redirect ERR -1003", got.get("redirect"))
        check("mock.timeout", got.get("post") == "post ERR -1001", got.get("post"))
        check("mock.body_file", (got.get("upload") or "").startswith("upload 200 23"), got.get("upload"))
        time.sleep(1)
        es2 = entries(m, since=mark)
        jm = find(es2, "GET", r"/json$")
        check("mock.logged", jm and jm[-1]["status"] == 503 and jm[-1]["mock"], jm and jm[-1].get("mock"))
        lat = find(es2, "GET", r"session=ephemeral")
        check("mock.latency", lat and lat[-1]["status"] == 200 and lat[-1]["duration_ms"] >= 1400 and not lat[-1]["mock"] is None,
              lat and lat[-1]["duration_ms"])
        if jm:
            r = json.loads(m.ok("net_request", id=jm[-1]["id"])[0])
            check("mock.request", r.get("resp_headers", {}).get("X-Mock") == "1" and '"mocked":true' in r.get("resp_body", ""), r.get("resp_body"))
        m.ok("net_mock", action="clear")
        got = run_once(m)
        check("mock.clear", got.get("json", "").startswith("json 200") and got.get("image", "").startswith("image 200"), json.dumps(got))

        # ---- share: the browser page's routes
        share_check(a, os.path.dirname(a.mcp), entries(m))

        # ---- off
        m.ok("net_capture", app=BID, action="off")
        time.sleep(0.5)
        mark = entries(m)[-1]["id"]
        got = run_once(m)
        time.sleep(1)
        new = [e for e in entries(m, since=mark) if e["kind"] == "request"]
        check("off", got.get("json", "").startswith("json 200") and not new, "%d new; %s" % (len(new), got.get("json")))
    finally:
        try:
            m.call("net_mock", action="clear")
            m.call("net_capture", app=BID, action="off")
            m.close()
        except Exception:
            pass
        srv.terminate()
    bad = [r for r in results if not r[1]]
    print("%d checks, %d failed%s" % (len(results), len(bad), (": " + ", ".join(r[0] for r in bad)) if bad else ""))
    sys.exit(len(bad))


if __name__ == "__main__":
    main()
