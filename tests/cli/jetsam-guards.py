#!/usr/bin/env python3
"""x86Sim: cli/libexec/jetsam.py's app guards, on a fake device (no phone needed): one sweep with the processes,
RunningBoard marks and openurl answers mocked. Issue #60 and its audit:
  - a background app is reclaimed after X86SIM_JETSAM_APP s (the normal case still works)
  - while a UI test's runner (<Target>-Runner.app with PlugIns/*.xctest) is alive, no app is reclaimed
  - an app LLDB attached to (its debug socket newer than the process) is not reclaimed
  - an app with the audio background mode is not reclaimed while it streams output (simaudio-out/<pid>)
  - without a fresh openurl answer right before the kill, RunningBoard's old view alone kills nothing
  - openurl's "dump" lines are parsed per pid
    tests/cli/jetsam-guards.py"""
import os, plistlib, shutil, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
T = tempfile.mkdtemp(prefix="jetsam-guards.", dir=os.path.expanduser("~/scratch") if os.path.isdir(os.path.expanduser("~/scratch")) else None)
DEV, PREFIX, STATE, DBG = (os.path.join(T, x) for x in ("device", "prefix", "state", "dbg"))
for d in (DEV + "/data/tmp", PREFIX, STATE + "/simaudio-out", DBG):
    os.makedirs(d)
open(os.path.join(DEV, "sim.env"), "w").write("SIMULATOR_UDID=UDID1\nX86SIM_A64_DEBUG_DIR=%s\n" % DBG)
os.environ.update(X86SIM_DEVICE=DEV, X86SIM_DPREFIX=PREFIX, X86SIM_STATE=STATE, X86SIM_JETSAM_APP="10",
                  X86SIM_JETSAM_LAST="10", X86SIM_JETSAM_WARN="0", X86SIM_A64_SLIM_PARK="")
sys.path.insert(0, os.path.join(ROOT, "cli/libexec"))
import jetsam as j  # noqa: E402


def app(name, bid, modes=(), xctest=False):
    d = os.path.join(T, "apps", name + ".app")
    os.makedirs(d)
    info = {"CFBundleIdentifier": bid}
    if modes:
        info["UIBackgroundModes"] = list(modes)
    plistlib.dump(info, open(os.path.join(d, "Info.plist"), "wb"))
    if xctest:
        os.makedirs(os.path.join(d, "PlugIns", name.replace("-Runner", "") + ".xctest"))
    return os.path.join(d, name)


UNDER_TEST = app("Demo", "com.example.demo")
PLAYER = app("Player", "com.example.player", modes=("audio",))
RUNNER = app("DemoUITests-Runner", "com.example.demo.xctrunner", xctest=True)
START = time.time() - 600
procs = {}         # dpid -> (lpid, exe, start, cpu)
answers = {}       # dpid -> (visible, task, scenes)
fresh_ok = [True]
killed = []
j.darling_pids = lambda: dict(procs)
j.marks = lambda d: {}
j.ask_front = lambda pids, now, dumps=(): now
j.front_state = lambda newer_than=0.0: {"front": None, "layout": None, "pids": dict(answers), "dumps": {}}
j.wait_front = lambda pids, timeout=4.0, dumps=(): j.front_state() if fresh_ok[0] else None
j._start_of = lambda lpid: START
j.os.kill = lambda pid, sig: killed.append(pid)


def sweeps(n=2, gap=11):
    """n sweeps gap s apart (time faked); returns the Linux pids killed"""
    del killed[:]
    real = time.time
    base = real()
    try:
        for i in range(n):
            j.time.time = lambda i=i: base + i * gap
            j.sweep()
    finally:
        j.time.time = real
    return set(killed)


fail = 0


def check(what, ok):
    global fail
    print("%-4s %s" % ("ok" if ok else "FAIL", what))
    fail += not ok


def reset():
    procs.clear(); answers.clear(); j._seen.clear(); j._kills.clear(); j._killed_at.clear(); fresh_ok[0] = True
    for d in (DBG, STATE + "/simaudio-out"):
        for x in os.listdir(d):
            os.unlink(os.path.join(d, x))


BG = (1, 4, 0)   # visible endowment, running, no visible scene: what #60's app read
# 1. the normal case: an app with no visible scene for longer than APP is reclaimed
reset(); procs[101] = (5101, UNDER_TEST, START, 0.0); answers[101] = BG
check("background app reclaimed", sweeps() == {5101})
# 2. #60: the same app while a UI test runner is alive: kept
reset(); procs[101] = (5101, UNDER_TEST, START, 0.0); procs[102] = (5102, RUNNER, START, 0.0); answers[101] = BG
answers[102] = (0, 3, 0)
check("UI test running: app under test and runner kept", sweeps() == set())
check("runner detected by its .xctest plug-in", j.test_runner(RUNNER) and not j.test_runner(UNDER_TEST))
# 3. LLDB attached: kept; a debug socket older than the process (a killed one's, pid reused): not a guard
reset(); procs[101] = (5101, UNDER_TEST, START, 0.0); answers[101] = BG
sock = os.path.join(DBG, "x86sim-dbg-UDID1-101.sock")
open(sock, "w").close()
check("debugged app kept", sweeps() == set())
os.utime(sock, (START - 100, START - 100))
check("stale debug socket does not keep it", sweeps() == {5101})
# 4. background audio: kept while it streams, reclaimed once it stops; no audio mode: no guard
reset(); procs[103] = (5103, PLAYER, START, 0.0); answers[103] = (0, 3, 0)
open(os.path.join(STATE, "simaudio-out", "5103"), "w").close()
check("background-audio app playing kept", sweeps() == set())
os.unlink(os.path.join(STATE, "simaudio-out", "5103"))
check("background-audio app reclaimed once silent", sweeps() == {5103})
reset(); procs[101] = (5101, UNDER_TEST, START, 0.0); answers[101] = BG
open(os.path.join(STATE, "simaudio-out", "5101"), "w").close()
check("app without the audio mode not kept by a stream", sweeps() == {5101})
# 5. no fresh answer right before the kill: the old view alone kills nothing
reset(); procs[101] = (5101, UNDER_TEST, START, 0.0); answers[101] = BG; fresh_ok[0] = False
check("no fresh openurl answer: not killed on the old view", sweeps() == set())
# 6. openurl's dump lines
open(j.FRONT, "w").write("\npid 7 1 4 0\ndump 7 state <RBSProcessState| task:running\n  endowments: x>\ndump 7 bks 8 (null)\npid 8 0 3 0\n")
import importlib  # noqa: E402  (the real front_state again)
fresh = importlib.reload(j).front_state()
check("dump lines parsed per pid", fresh is not None and fresh["dumps"].get(7, [""])[0].startswith("dump 7 state")
      and len(fresh["dumps"][7]) == 3 and fresh["pids"].get(8) == (0, 3, 0))
shutil.rmtree(T, ignore_errors=True)
print("jetsam guards: %s" % ("all passed" if not fail else "%d failed" % fail))
sys.exit(1 if fail else 0)
