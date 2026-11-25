"""x86Sim dev checks (tests/dev/*): the MCP client and the phone session they share.

A check drives x86sim-mcp over stdio JSON-RPC, as an agent does. The phone is the check's own (created when missing),
booted while this process holds one of the two phone slot locks (~/scratch/phone-slot-{1,2}.lock, or $X86SIM_PHONE_SLOTS,
colon separated) and stopped before the lock is let go.
"""
import contextlib
import fcntl
import json
import os
import subprocess
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class Mcp:
    def __init__(self, path, phone, log):
        self.p = subprocess.Popen([path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.phone, self.log, self.n = phone, log, 0
        self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "dev_e2e", "version": "1"}})

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
        """(text, error)"""
        if self.phone and tool not in ("sim_add_device", "phones_list"):
            args.setdefault("phone", self.phone)
        t0 = time.monotonic()
        r = self.rpc("tools/call", {"name": tool, "arguments": args})["result"]
        text = "\n".join(c.get("text", "") for c in r.get("content", []) if c.get("type") == "text")
        self.log.write("### %s %s (%.1f s)\n%s\n\n" % (tool, json.dumps(args), time.monotonic() - t0, text))
        self.log.flush()
        return text, bool(r.get("isError"))

    def must(self, tool, **args):
        text, err = self.call(tool, **args)
        if err:
            raise RuntimeError("%s: %s" % (tool, text.strip()[-800:]))
        return text

    def screenshot(self, path):
        """The screen as PNG into PATH (the screenshot tool's image)"""
        import base64
        r = self.rpc("tools/call", {"name": "screenshot", "arguments": {"phone": self.phone}})["result"]
        for c in r.get("content", []):
            if c.get("type") == "image":
                with open(path, "wb") as f:
                    f.write(base64.b64decode(c["data"]))
                return path
        return None

    def close(self):
        self.p.stdin.close()
        self.p.wait(10)


def default_mcp():
    return os.path.join(ROOT, "tools/launcher/target/release/x86sim-mcp")


@contextlib.contextmanager
def phone_slot():
    """One of the shared phone slots, held by this process (flock), waited for when both are taken"""
    slots = os.environ.get("X86SIM_PHONE_SLOTS") or ":".join(os.path.expanduser("~/scratch/phone-slot-%d.lock" % i) for i in (1, 2))
    files = [open(p, "w") for p in slots.split(":")]
    held = None
    try:
        while held is None:
            for f in files:
                try:
                    fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    held = f
                    break
                except BlockingIOError:
                    pass
            if held is None:
                time.sleep(5)
        yield held.name
    finally:
        if held is not None:
            fcntl.flock(held, fcntl.LOCK_UN)
        for f in files:
            f.close()


def phone(m, name):
    """The phones_list entry of NAME, or None"""
    return next((p for p in json.loads(m.must("phones_list"))["phones"] if p["name"] == name), None)


def ensure_phone(m, name, model):
    if phone(m, name) is None:
        m.must("sim_add_device", model=model, name=name)


def wait_home(m, timeout=1200):
    t0 = time.monotonic()
    while time.monotonic() - t0 < timeout:
        p = phone(m, m.phone) or {}
        if p.get("state") == "running" and p.get("home"):
            return time.monotonic() - t0
        time.sleep(5)
    raise RuntimeError("%s not on its home screen after %d s" % (m.phone, timeout))
