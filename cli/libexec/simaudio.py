#!/usr/bin/env python3
"""x86Sim: the host side of the simulator's audio (the Mac's coreaudiod on a Linux host).

host/simaudio/libsimaudio.dylib (in every simulator process) presents an output and an input device and connects
here for each running stream: a 16-byte header ("x86A", u32 direction 0=output/1=input, u32 rate, u32 channels),
then float32 interleaved PCM. With X86SIM_AUDIO_PLAYBACK=1 (boot-a64.sh: X86SIM_AUDIO=1) output streams are played
with `pw-cat --playback` (PipeWire, or PulseAudio through pipewire-pulse), one PipeWire stream per simulator stream,
so PipeWire mixes them, and input streams get the default source through `pw-cat --record`; otherwise input streams
get silence. pw-cat's raw mode (-a) is PipeWire 1.4 and later; an older pw-cat (Ubuntu 24.04: 1.0.5) refuses it, and
then `pacat`/`parec --raw` (PulseAudio's tools, through pipewire-pulse) play and record instead. A player that fails
(its stderr goes to this log) leaves its stream connected: output is consumed and dropped, input gets silence, so a
simulator stream never reconnects in a loop.

The tap (SOCKET's folder/simaudio-tap.sock): a second consumer, x86sim-serve (tools/launcher/core/src/share/audio.rs),
which mixes the phone's output for a browser and feeds a browser's microphone back. Messages both ways: u8 op,
u32 stream id, u32 payload length (little endian), payload.
  to the tap:   1 open (u32 rate, u32 channels)   2 data (float32 interleaved)   3 close
  from the tap: 4 microphone (float32 mono 48 kHz; while frames arrive they replace the input streams' source)
                5 microphone off
A tap that falls behind loses data (its queue is bounded); it never slows a simulator stream.

usage: simaudio.py SOCKET     env: X86SIM_AUDIO_PLAYBACK (1: PipeWire, default 1), X86SIM_AUDIO_VOLUME (0..1,
                                   default 0.5), X86SIM_AUDIO_MIC=0 (no host microphone: input streams get silence),
                                   X86SIM_AUDIO_PLAYER (pw-cat | pacat; default: pw-cat when it has raw mode)
"""
import array, os, queue, socket, struct, subprocess, sys, threading, time

VOLUME = os.environ.get("X86SIM_AUDIO_VOLUME", "0.5")
PLAYBACK = os.environ.get("X86SIM_AUDIO_PLAYBACK", "1") != "0"
MIC = os.environ.get("X86SIM_AUDIO_MIC", "1") != "0" and PLAYBACK

OPEN, DATA, CLOSE, MIC_DATA, MIC_OFF = 1, 2, 3, 4, 5
TAP_HDR = struct.Struct("<BII")


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def pick_player():
    """pw-cat when it has raw mode (-a, --raw: PipeWire 1.4+), else pacat/parec (pipewire-pulse), else none"""
    want = os.environ.get("X86SIM_AUDIO_PLAYER", "")
    if want in ("pw-cat", "pacat"):
        return want
    try:
        h = subprocess.run(["pw-cat", "--help"], capture_output=True, text=True, timeout=5)
        if "--raw" in h.stdout + h.stderr:
            return "pw-cat"
    except (OSError, subprocess.SubprocessError):
        pass
    for tool in ("pacat", "parec"):
        if subprocess.run(["sh", "-c", "command -v " + tool], capture_output=True).returncode:
            log("no audio player: pw-cat has no raw mode (PipeWire < 1.4) and %s is missing" % tool)
            return None
    return "pacat"


def player(output, rate, ch, name):
    """the command that plays (output) or records float32 interleaved PCM on stdin/stdout"""
    if PLAYER == "pw-cat":
        cmd = ["pw-cat", "--playback" if output else "--record", "-a", "--format", "f32", "--rate", str(rate),
               "--channels", str(ch), "--latency", "40ms",
               "-P", "{ node.name = \"%s\" media.name = \"iOS Simulator\" application.name = \"x86sim\" }" % name]
        return cmd + (["--volume", VOLUME, "-"] if output else ["-"])
    cmd = ["pacat" if output else "parec", "--raw", "--format=float32le", "--rate=%d" % rate, "--channels=%d" % ch,
           "--latency-msec=40", "--client-name=x86sim", "--stream-name=iOS Simulator", "--property=node.name=" + name,
           "--property=state.restore-props=false"]
    if output:
        # the volume goes into the samples (serve(), GAIN), the stream's own is 100% and opts out of WirePlumber's
        # stream restore: that keeps a stream volume per application.name (x86sim) and puts it on later streams, so
        # pw-cat's --volume would land on pacat's too (twice the attenuation) and a pacat --volume on pw-cat's
        cmd.append("--volume=65536")
    return cmd


def spawn(n, output, rate, ch):
    """start the player for connection n, its stderr copied to this log; None when there is none or it can't start"""
    if not PLAYER:
        return None
    cmd = player(output, rate, ch, "x86sim-%s-%d" % ("out" if output else "in", n))
    try:
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE if output else subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL if output else subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as e:
        log("conn %d: %s: %s" % (n, cmd[0], e))
        return None

    def errors():
        for line in p.stderr:
            log("conn %d: %s: %s" % (n, cmd[0], line.decode(errors="replace").rstrip()))
        p.stderr.close()

    threading.Thread(target=errors, daemon=True).start()
    return p


def ended(n, p, what):
    """log a player that stopped while its stream still ran (once a connection)"""
    try:
        rc = p.wait(timeout=1)
    except subprocess.TimeoutExpired:
        rc = None
    log("conn %d: %s stopped (exit %s); the stream goes on without it" % (n, what, rc))


# ---- the tap: output streams out, a browser's microphone in ----
class Taps:
    def __init__(self):
        self.lock = threading.Lock()
        self.taps = []          # queues, one a tap
        self.streams = {}       # output stream id -> (rate, ch): told to a tap that connects later

    def send(self, op, sid, payload=b""):
        msg = TAP_HDR.pack(op, sid, len(payload)) + payload
        with self.lock:
            if op == OPEN:
                self.streams[sid] = payload
            elif op == CLOSE:
                self.streams.pop(sid, None)
            taps = list(self.taps)
        for q in taps:
            try:
                q.put_nowait(msg)
            except queue.Full:
                pass

    def add(self, conn):
        q = queue.Queue(maxsize=400)
        with self.lock:
            for sid, p in self.streams.items():
                q.put_nowait(TAP_HDR.pack(OPEN, sid, len(p)) + p)
            self.taps.append(q)
        log("tap connected")

        def writer():
            try:
                while True:
                    m = q.get()
                    if m is None:
                        break
                    conn.sendall(m)
            except OSError:
                pass

        w = threading.Thread(target=writer, daemon=True)
        w.start()
        try:
            hdr = b""
            while True:
                b = conn.recv(65536)
                if not b:
                    break
                hdr += b
                while len(hdr) >= TAP_HDR.size:
                    op, _, n = TAP_HDR.unpack_from(hdr)
                    if len(hdr) < TAP_HDR.size + n:
                        break
                    payload = hdr[TAP_HDR.size:TAP_HDR.size + n]
                    hdr = hdr[TAP_HDR.size + n:]
                    if op == MIC_DATA:
                        MICFEED.write(payload)
                    elif op == MIC_OFF:
                        MICFEED.off()
        except OSError:
            pass
        finally:
            MICFEED.off()
            with self.lock:
                self.taps.remove(q)
            q.put(None)
            conn.close()
            log("tap gone")


class MicFeed:
    """A browser's microphone: float32 mono 48 kHz, kept for half a second; each input stream reads at its own place"""
    KEEP = 24000

    def __init__(self):
        self.lock = threading.Lock()
        self.buf = array.array("f")
        self.end = 0            # samples ever written
        self.last = 0.0         # when the last frames came

    def write(self, b):
        a = array.array("f")
        a.frombytes(b[:len(b) // 4 * 4])
        with self.lock:
            self.buf.extend(a)
            self.end += len(a)
            if len(self.buf) > self.KEEP:
                del self.buf[:len(self.buf) - self.KEEP]
            self.last = time.monotonic()

    def off(self):
        with self.lock:
            self.last = 0.0

    def active(self):
        return time.monotonic() - self.last < 0.5

    def read(self, pos, n):
        """n samples from `pos` (None: start near the newest); returns (samples, new pos). Latency stays bounded:
        a reader more than 60 ms behind skips ahead to 20 ms behind"""
        with self.lock:
            start = self.end - len(self.buf)
            if pos is None or pos < start or self.end - pos > 2880:
                pos = max(start, self.end - 960)
            i = pos - start
            got = self.buf[i:i + n]
        out = array.array("f", got)
        if len(out) < n:
            out.extend([0.0] * (n - len(out)))
        return out, pos + len(got)


TAPS = Taps()
MICFEED = MicFeed()
PLAYER = pick_player() if PLAYBACK else None
try:
    GAIN = max(0.0, min(1.0, float(VOLUME)))    # pacat: the volume, applied to the samples (pw-cat: --volume)
except ValueError:
    GAIN = 0.5


def mic_frames(pos, rate, ch, nframes):
    """nframes of the browser's microphone at the stream's rate and channels (float32 bytes) and the new read place"""
    need = nframes if rate == 48000 else int(nframes * 48000 / rate + 0.5)
    m, pos = MICFEED.read(pos, need)
    if rate != 48000:
        m = array.array("f", (m[min(need - 1, int(i * need / nframes))] for i in range(nframes)))
    if ch == 2:
        s = array.array("f", bytes(8 * nframes))
        s[0::2] = m
        s[1::2] = m
        m = s
    return m.tobytes(), pos


def serve(conn, n):
    try:
        hdr = b""
        while len(hdr) < 16:
            b = conn.recv(16 - len(hdr))
            if not b:
                return
            hdr += b
        magic, direction, rate, ch = hdr[:4], *struct.unpack("<III", hdr[4:])
        if magic != b"x86A" or ch not in (1, 2) or rate not in (44100, 48000):
            log("conn %d: bad header %r" % (n, hdr))
            return
        log("conn %d: %s %d Hz %d ch" % (n, "input" if direction else "output", rate, ch))
        if direction == 0:
            p = spawn(n, True, rate, ch) if PLAYBACK else None
            TAPS.send(OPEN, n, struct.pack("<II", rate, ch))
            frame = 4 * ch
            rest = b""
            total = 0
            scale = PLAYER == "pacat" and GAIN != 1.0
            odd = b""
            while True:
                b = conn.recv(65536)
                if not b:
                    break
                total += len(b)
                if p:
                    out = b
                    if scale:
                        out = odd + b
                        cut = len(out) // 4 * 4
                        odd = out[cut:]
                        a = array.array("f")
                        a.frombytes(out[:cut])
                        out = array.array("f", map(GAIN.__mul__, a)).tobytes()
                    try:
                        p.stdin.write(out)
                        p.stdin.flush()
                    except (BrokenPipeError, ValueError):
                        ended(n, p, "player")
                        try:
                            p.stdin.close()
                        except OSError:
                            pass        # what it still buffered goes nowhere
                        p = None
                # the tap gets whole frames only
                b = rest + b
                cut = len(b) // frame * frame
                rest = b[cut:]
                if cut:
                    TAPS.send(DATA, n, b[:cut])
            TAPS.send(CLOSE, n)
            log("conn %d: output ended (%.1f s)" % (n, total / (4 * ch * rate)))
            if p:
                try:
                    p.stdin.close()
                except Exception:
                    pass
                p.terminate()
        else:
            # 10 ms blocks: the browser's microphone while it sends, else the host's (the recorder), else silence
            block = rate // 100
            pos = None
            p = spawn(n, False, rate, ch) if MIC else None
            try:
                if p:
                    while True:
                        b = p.stdout.read1(4096)
                        if not b:
                            # the recorder failed or quit: silence from here (closing would have the simulator
                            # reconnect at once, and again, many times a second)
                            ended(n, p, "recorder")
                            break
                        if MICFEED.active():
                            b, pos = mic_frames(pos, rate, ch, len(b) // (4 * ch))
                        else:
                            pos = None
                        conn.sendall(b)
                silence = bytes(4 * ch * block)
                t = time.monotonic()
                while True:
                    if MICFEED.active():
                        b, pos = mic_frames(pos, rate, ch, block)
                    else:
                        b, pos = silence, None
                    conn.sendall(b)
                    t += 0.01
                    time.sleep(max(0.0, t - time.monotonic()))
            except (BrokenPipeError, ConnectionResetError):
                pass
            log("conn %d: input ended" % n)
            if p:
                p.terminate()
    except (BrokenPipeError, ConnectionResetError):
        pass
    finally:
        conn.close()


def listen(path):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(path)
    os.chmod(path, 0o777)
    s.listen(16)
    return s


def main():
    path = sys.argv[1]
    s = listen(path)
    tap_path = os.path.join(os.path.dirname(os.path.abspath(path)), "simaudio-tap.sock")
    t = listen(tap_path)
    os.chmod(tap_path, 0o700)

    def taps():
        while True:
            c, _ = t.accept()
            threading.Thread(target=TAPS.add, args=(c,), daemon=True).start()

    threading.Thread(target=taps, daemon=True).start()
    log("listening on", path, "tap", tap_path, "playback", PLAYBACK, "player", PLAYER, "volume", VOLUME, "mic", MIC)
    n = 0
    while True:
        c, _ = s.accept()
        n += 1
        threading.Thread(target=serve, args=(c, n), daemon=True).start()


if __name__ == "__main__":
    main()
