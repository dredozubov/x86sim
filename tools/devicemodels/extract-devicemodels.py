#!/usr/bin/env python3
"""x86Sim: copy Xcode's 3D device models (DeviceHub's) out of Xcode.xip on Linux, for the launcher's 3D phone.

    tools/devicemodels/extract-devicemodels.py SOURCE [--out DIR] [--only NAME[,NAME...]]

SOURCE is Xcode.xip (developer.apple.com, free Apple ID; the file `x86sim dev setup sdk --xip` takes) or an unpacked
Xcode.app. Xcode draws a device's model in its DeviceHub with CoreDevicePopDeviceKitExtension, whose Resources hold one
.usdz per model (V68.usdz: iPhone Duo, iPhone19,4). They are Apple's: never committed or shipped with x86Sim; each
user's own Xcode.xip gives them, into DIR (default: $XDG_DATA_HOME/x86sim/devicemodels, the directory the launcher and
`x86sim-serve` read; X86SIM_DEVICEMODELS overrides both). --only keeps just the named models (default: all).
The .xip is read as a stream with the standard library (the xar / pbzx / cpio readers of extract-devicetypes.py): the
whole archive may be read before the plug-in turns up, a few minutes.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RES = "Contents/SharedFrameworks/DeviceKit.framework/Versions/A/PlugIns/CoreDevicePopDeviceKitExtension.devicekitplugin/Contents/Resources/"


def die(msg):
    sys.exit("extract-devicemodels: " + msg)


def readers():
    """extract-devicetypes.py's xar / pbzx / cpio readers"""
    p = os.path.join(os.path.dirname(HERE), "devicetypes", "extract-devicetypes.py")
    spec = importlib.util.spec_from_file_location("extract_devicetypes", p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def default_out():
    if os.environ.get("X86SIM_DEVICEMODELS"):
        return os.environ["X86SIM_DEVICEMODELS"]
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(data, "x86sim", "devicemodels")


def wanted(name, only):
    base = name.rsplit("/", 1)[-1]
    return base.endswith(".usdz") and (not only or base[:-5] in only)


def from_app(app, out, only):
    res = os.path.join(app, RES)
    if not os.path.isdir(res):
        die("%s: no %s" % (app, RES))
    got = []
    for n in sorted(os.listdir(res)):
        if wanted(n, only):
            with open(os.path.join(res, n), "rb") as f:
                write(out, n, f.read())
            got.append(n)
    return got


def write(out, name, data):
    os.makedirs(out, exist_ok=True)
    tmp = os.path.join(out, name + ".part")
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, os.path.join(out, name))


def from_xip(path, out, only):
    r = readers()
    got, bufs = [], {}
    state = {"in": False, "left": False}
    with open(path, "rb") as f:
        m = r.xar_members(f)
        if "Content" not in m:
            die("%s: no Content member (not an Xcode .xip?)" % path)

        def want(name):
            inside = RES in name
            # the archive lists the directories first, then the files; the Resources' files come together: once
            # past the models, stop reading
            if state["in"] and not inside:
                return "stop"
            if inside and wanted(name, only):
                state["in"] = True
                return bufs.setdefault(name.rsplit("/", 1)[-1], bytearray()).extend
            return None
        print("reading %s (the archive is streamed until DeviceKit's models)" % path, file=sys.stderr)
        r.cpio(r.member_stream(f, m["Content"]), want)
    for n, b in sorted(bufs.items()):
        write(out, n, bytes(b))
        got.append(n)
    return got


def main():
    a, src, out, only = sys.argv[1:], None, None, set()
    while a:
        o = a.pop(0)
        if o == "--out" and a:
            out = a.pop(0)
        elif o == "--only" and a:
            only = {x for x in a.pop(0).split(",") if x}
        elif o.startswith("-") or src:
            sys.exit(__doc__)
        else:
            src = o
    if not src:
        sys.exit(__doc__)
    out = out or default_out()
    got = from_app(src, out, only) if os.path.isdir(src) else from_xip(src, out, only)
    if not got:
        die("%s: no device models in it" % src)
    for n in got:
        print(os.path.join(out, n))


if __name__ == "__main__":
    main()
