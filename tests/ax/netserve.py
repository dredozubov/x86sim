#!/usr/bin/env python3
"""x86Sim: the host server tests/apps/x86netcap talks to (tests/ax/net_e2e.py starts it; the phone reaches the host's
loopback). Stdlib only.
  GET  /json          {"ok": true, "items": [1, 2, 3]}
  POST /echo          the request body back, same Content-Type, X-Echo-Header: the X-Test header
  GET  /image.png     a small PNG (binary body)
  GET  /redirect      302 -> /json
  PUT  /upload        {"received": <bytes>}
Usage: netserve.py [--port 7431]"""
import argparse, json, struct, sys, zlib
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler


def png(w=8, h=8):
    rows = b"".join(b"\0" + b"".join(bytes([(x * 32) & 255, (y * 32) & 255, 128]) for x in range(w)) for y in range(h))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


PNG = png()


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *a):
        sys.stderr.write("netserve: " + fmt % a + "\n")

    def send(self, code, body=b"", ctype="application/json", extra=()):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n:
            return self.rfile.read(n)
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            out = b""
            while True:
                size = int(self.rfile.readline().strip() or b"0", 16)
                if size == 0:
                    self.rfile.readline()
                    return out
                out += self.rfile.read(size)
                self.rfile.readline()
        return b""

    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/json":
            self.send(200, json.dumps({"ok": True, "items": [1, 2, 3], "path": self.path}).encode())
        elif p == "/image.png":
            self.send(200, PNG, "image/png")
        elif p == "/redirect":
            self.send(302, b"", "text/plain", [("Location", "/json?from=redirect")])
        else:
            self.send(404, b'{"error":"not found"}')

    def do_POST(self):
        b = self.body()
        self.log_message("POST body %d bytes (Content-Length %s)", len(b), self.headers.get("Content-Length"))
        self.send(200, b, self.headers.get("Content-Type") or "application/octet-stream", [("X-Echo-Header", self.headers.get("X-Test") or "")])

    def do_PUT(self):
        b = self.body()
        self.log_message("PUT body %d bytes (Content-Length %s)", len(b), self.headers.get("Content-Length"))
        self.send(200, json.dumps({"received": len(b)}).encode())


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=7431)
    a = ap.parse_args()
    ThreadingHTTPServer(("127.0.0.1", a.port), H).serve_forever()
