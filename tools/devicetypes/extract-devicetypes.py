#!/usr/bin/env python3
"""x86Sim: regenerate cli/lib/devicetypes-a64.json and cli/lib/devicetype-<model>.json on Linux from Xcode.xip.

    tools/devicetypes/extract-devicetypes.py SOURCE [--runtime 27.2] [--include-unsupported] [--out DIR]

--out DIR writes the files into DIR instead of cli/lib (`x86sim account download-xcode` compares them with cli/lib).

SOURCE holds Xcode's simulator device types (CoreSimulator/Profiles/DeviceTypes/*.simdevicetype), any of:
  - Xcode.xip (developer.apple.com, free Apple ID; the file `x86sim dev setup sdk --xip` takes), read as a stream
  - Xcode.app (an unpacked one), or its Contents/Resources/Packages/XcodeSystemResources.pkg
  - a DeviceTypes directory (a copy of /Library/Developer/CoreSimulator/Profiles/DeviceTypes)
Xcode installs the device types from XcodeSystemResources.pkg (Xcode.app/Contents/Resources/Packages) into
/Library/Developer/CoreSimulator/Profiles/DeviceTypes. Both archives are read with the standard library: a .xip and a
.pkg are xar archives; the .xip's Content member and the .pkg's Payload are pbzx streams (xz chunks) of an odc cpio
archive. The .pkg (~150 MB) goes to a temporary file under $X86SIM_SCRATCH; only the device types' profile.plist and
capabilities.plist are kept.

Which device types the iOS runtime takes comes from the runtime itself: runtimes/ios-<version>-*/extracted/.../
<runtime>.simruntime/Contents/Resources/profile.plist (its supportedProductFamilyIDs and unsupportedDeviceTypes, the
same data `xcrun simctl list runtimes`' supportedDeviceTypes applies) and each device type's min/maxRuntimeVersion.
Every iPhone/iPad the runtime supports gets an entry:
    name -> model (modelIdentifier), class (productClass), w/h/pitch (capabilities ScreenDimensionsCapability),
            scale ("%f"), suffix (environment SIMULATOR_LEGACY_ASSET_SUFFIX), json (devicetype-<model lowercase>.json)
and devicetype-<model>.json is the capabilities.plist as JSON (what SIMULATOR_CAPABILITIES carries). Device types
sharing a model identifier (iPad 8GB/16GB variants) share one capabilities file, the first one listed.
Only data derived from the plists is written; no Apple binaries.
--include-unsupported also takes iPhone/iPad types the runtime refuses but whose minRuntimeVersion allows (iPhone Duo,
iPhone19,4, on 27.2: the runtime profile's unsupportedDeviceTypes), with a "note". The committed files are
`extract-devicetypes.py Xcode_27.2.xip --include-unsupported`.
iPhones and iPads are listed in the order the committed devicetypes-a64.json has them (CoreSimulator's own order, as
`simctl list devicetypes` shows it: not derivable from the plists); a device type new to it goes before the first one
of its family (iPhone / iPad) with an older minRuntimeVersion. X86SIM_TYPES (below) adds x86Sim's own variants.
Platforms 1: Apple TV and Apple Watch device types are added after the iPhones and iPads, with "platform": "tvos" /
"watchos" (an entry without "platform" is iOS). Which of them a 27.x runtime takes comes from each profile's product
family (3 = Apple TV, 4 = Apple Watch) and min/maxRuntimeVersion, so no tvOS/watchOS runtime is needed.
"""
import glob
import json
import lzma
import os
import plistlib
import re
import shutil
import struct
import sys
import tempfile
import xml.etree.ElementTree as ET
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIB = os.path.join(ROOT, "cli/lib")
PKG = "Contents/Resources/Packages/XcodeSystemResources.pkg"
# a device type's plists inside the .pkg payload (./Library/Developer/...) or a DeviceTypes directory
DT_RE = re.compile(r"(?:^|/)DeviceTypes/([^/]+\.simdevicetype)/Contents/Resources/(profile|capabilities)\.plist$")


# x86Sim's own device types, not Apple's: name -> (the Apple device type it is drawn from, divisor of its pixel size, scale
# and pitch). Apple Vision Pro (at 1080p): the same 1920x1080 points at scale 1, a quarter of the pixels, as Apple's Apple
# TV "(at 1080p)" variants (mksimdevice.py takes the entry's scale and pitch over the model's capabilities)
X86SIM_TYPES = {"Apple Vision Pro (at 1080p)": ("Apple Vision Pro", 2)}


def ints(v):
    """plutil -convert json's form (the committed files): integral reals as integers"""
    if isinstance(v, float) and v.is_integer():
        return int(v)
    if isinstance(v, dict):
        return {k: ints(x) for k, x in v.items()}
    if isinstance(v, list):
        return [ints(x) for x in v]
    return v


def ver(s):
    return [int(x) for x in s.split(".")]


def die(msg):
    sys.exit("extract-devicetypes: " + msg)


# --- archives: xar (.xip, .pkg), pbzx, odc cpio ---

def xar_members(f):
    """{path: (absolute offset, length, encoding)} of a xar archive's files"""
    head = f.read(28)
    if len(head) < 28 or head[:4] != b"xar!":
        raise ValueError("not a xar archive")
    hsize, toc_c = struct.unpack(">H", head[4:6])[0], struct.unpack(">Q", head[8:16])[0]
    f.seek(hsize)
    toc = ET.fromstring(zlib.decompress(f.read(toc_c))).find("toc")
    heap, out = hsize + toc_c, {}

    def walk(node, prefix):
        for e in node.findall("file"):
            p = prefix + e.findtext("name")
            d = e.find("data")
            if d is not None:
                enc = d.find("encoding")
                out[p] = (heap + int(d.findtext("offset")), int(d.findtext("length")),
                          enc.get("style") if enc is not None else "")
            walk(e, p + "/")
    walk(toc, "")
    return out


def member_stream(f, member):
    """the decompressed chunks of a xar member that is a pbzx stream (or gzip / plain)"""
    start, length, enc = member
    f.seek(start)
    magic = f.read(4)
    if magic != b"pbzx":
        f.seek(start)
        data = f.read(length)
        yield zlib.decompress(data, 47) if "gzip" in enc or data[:2] == b"\x1f\x8b" else data
        return
    f.read(8)
    done = 12
    while done < length:
        _flags, size = struct.unpack(">QQ", f.read(16))
        data = f.read(size)
        if len(data) < size:
            raise ValueError("truncated pbzx stream")
        done += 16 + size
        yield lzma.decompress(data) if data[:6] == b"\xfd7zXZ\x00" else data


class Chunks:
    """a byte reader over a chunk iterator, keeping at most one chunk"""

    def __init__(self, it):
        self.it, self.buf, self.pos = it, b"", 0

    def read(self, n):
        out = []
        while n:
            if self.pos == len(self.buf):
                self.buf, self.pos = next(self.it, b""), 0
                if not self.buf:
                    break
            k = min(n, len(self.buf) - self.pos)
            out.append(self.buf[self.pos:self.pos + k])
            self.pos += k
            n -= k
        return b"".join(out)


def cpio(chunks, want):
    """odc cpio members: calls want(name) -> None (skip) or a writer(bytes) per member; returns when want says stop"""
    r = Chunks(chunks)
    while True:
        h = r.read(76)
        if len(h) < 76 or h[:6] != b"070707":
            raise ValueError("not an odc cpio archive" if h else "cpio archive ended early")
        nsize, fsize = int(h[59:65], 8), int(h[65:76], 8)
        name = r.read(nsize)[:-1].decode(errors="replace")
        if name == "TRAILER!!!":
            return
        w = want(name)
        if w == "stop":
            return
        while fsize:
            b = r.read(min(fsize, 1 << 20))
            if not b:
                raise ValueError("cpio archive ended early")
            fsize -= len(b)
            if w:
                w(b)


def plists_from_payload(chunks):
    files = {}

    def want(name):
        m = DT_RE.search(name)
        if not m:
            return None
        key = m.group(1) + "/Contents/Resources/" + m.group(2) + ".plist"
        buf = files.setdefault(key, bytearray())
        return buf.extend
    cpio(chunks, want)
    return {k: plistlib.loads(bytes(v)) for k, v in files.items()}


def from_pkg(path):
    with open(path, "rb") as f:
        m = xar_members(f)
        if "Payload" not in m:
            die("%s: no Payload in the package" % path)
        return plists_from_payload(member_stream(f, m["Payload"]))


def from_xip(path):
    scratch = os.environ.get("X86SIM_SCRATCH") or os.path.expanduser("~/scratch")
    os.makedirs(scratch, exist_ok=True)
    with open(path, "rb") as f, tempfile.TemporaryDirectory(dir=scratch, prefix="devicetypes.") as tmp:
        m = xar_members(f)
        if "Content" not in m:
            die("%s: no Content member (not an Xcode .xip?)" % path)
        pkg = os.path.join(tmp, "XcodeSystemResources.pkg")
        state = {"found": False}
        out = open(pkg, "wb")

        def want(name):
            if state["found"]:
                return "stop"
            if name.endswith("/" + PKG) or name == PKG:
                state["found"] = True
                return out.write
            return None
        print("reading %s (the whole archive may be streamed until XcodeSystemResources.pkg)" % path, file=sys.stderr)
        cpio(member_stream(f, m["Content"]), want)
        out.close()
        if not state["found"]:
            die("%s: no %s in it" % (path, PKG))
        return from_pkg(pkg)


def from_dir(path):
    files = {}
    for p in glob.glob(os.path.join(path, "*.simdevicetype/Contents/Resources/*.plist")):
        m = DT_RE.search("DeviceTypes/" + os.path.relpath(p, path).replace(os.sep, "/"))
        if m:
            with open(p, "rb") as f:
                files[m.group(1) + "/Contents/Resources/" + m.group(2) + ".plist"] = plistlib.load(f)
    return files


def load(src):
    if os.path.isdir(src):
        if os.path.isfile(os.path.join(src, PKG)):
            return from_pkg(os.path.join(src, PKG))
        for d in (src, os.path.join(src, "Library/Developer/CoreSimulator/Profiles/DeviceTypes")):
            if glob.glob(os.path.join(d, "*.simdevicetype")):
                return from_dir(d)
        die("%s: neither an Xcode.app nor a DeviceTypes directory" % src)
    with open(src, "rb") as f:
        if f.read(4) != b"xar!":
            die("%s: not a .xip / .pkg (xar) archive" % src)
    with open(src, "rb") as f:
        names = xar_members(f)
    return from_xip(src) if "Content" in names else from_pkg(src)


def ios_runtime(rtver):
    """(build, profile.plist) of the newest installed iOS <rtver> runtime that takes every device type (no
    restrictedToDeviceTypes: a device-specific beta build like 24B91016s is left out)"""
    found = []
    for p in sorted(glob.glob(os.path.join(ROOT, "runtimes", "ios-%s-*" % rtver, "extracted", "Library/Developer/CoreSimulator/Profiles/Runtimes/*.simruntime/Contents/Resources/profile.plist"))):
        with open(p, "rb") as f:
            prof = plistlib.load(f)
        if not prof.get("restrictedToDeviceTypes"):
            found.append((os.path.relpath(p, os.path.join(ROOT, "runtimes")).split("/")[0].split("-")[2], prof))
    if not found:
        die("no iOS %s runtime in runtimes/ (cli/x86sim runtime list ios; runtime fetch BUILD)" % rtver)
    return found[-1]


def main():
    rtver, unsupported, src, out_dir = "27.2", False, None, LIB
    a = sys.argv[1:]
    while a:
        o = a.pop(0)
        if o == "--runtime":
            rtver = a.pop(0)
        elif o == "--out" and a:
            out_dir = a.pop(0)
            os.makedirs(out_dir, exist_ok=True)
        elif o == "--include-unsupported":
            unsupported = True
        elif o.startswith("-") or src:
            sys.exit(__doc__)
        else:
            src = o
    if not src:
        sys.exit(__doc__)
    files = load(src)
    if not files:
        die("%s: no device types found" % src)
    build, rprof = ios_runtime(rtver)
    fams, refused = set(rprof.get("supportedProductFamilyIDs", [])) & {1, 2}, set(rprof.get("unsupportedDeviceTypes", []))
    prof = lambda b: files.get(b + "/Contents/Resources/profile.plist", {})
    allowed = lambda b: ver(prof(b).get("minRuntimeVersion", "0")) <= ver(rtver) <= ver(prof(b).get("maxRuntimeVersion", "99.99"))
    alltypes = sorted({p.split("/")[0] for p in files})
    supported, bundles = [], []
    for b in alltypes:
        p = prof(b)
        if not (set(p.get("supportedProductFamilyIDs", [])) & fams and b.startswith(("iPhone", "iPad")) and allowed(b)):
            continue
        if p.get("modelIdentifier") not in refused and "arm64" in p.get("supportedArchs", ["arm64"]):
            supported.append(b)
            bundles.append(b)
        elif unsupported:
            bundles.append(b)
    # CoreSimulator's order: the committed file's; a new one before the first of its family with an older minimum
    try:
        with open(os.path.join(LIB, "devicetypes-a64.json")) as f:
            order = [k + ".simdevicetype" for k, v in json.load(f).items() if "platform" not in v]
    except (OSError, ValueError):
        order = []
    fam = lambda b: "iPad" if b.startswith("iPad") else "iPhone"
    ordered = [b for b in order if b in bundles]
    for b in sorted((b for b in bundles if b not in order), key=lambda b: ver(prof(b).get("minRuntimeVersion", "0")), reverse=True):
        mv = ver(prof(b).get("minRuntimeVersion", "0"))
        same = [i for i, x in enumerate(ordered) if fam(x) == fam(b)]
        older = [i for i in same if ver(prof(ordered[i]).get("minRuntimeVersion", "0")) < mv]
        at = older[0] if older else (same[-1] + 1 if same else (len(ordered) if fam(b) == "iPad" else
                                                                 next((i for i, x in enumerate(ordered) if fam(x) == "iPad"), len(ordered))))
        ordered.insert(at, b)
    # Platforms 1: (bundle, platform) for every device type; iOS first, as before
    plat = {b: None for b in ordered}
    # Platforms 2: Apple Vision Pro (product family 7, "xros")
    for famid, key in ((3, "tvos"), (4, "watchos"), (7, "xros")):
        # newest first, as Xcode's own lists show them (model identifier generation, then name)
        cands = [b for b in alltypes if famid in prof(b).get("supportedProductFamilyIDs", []) and allowed(b)
                 and "arm64" in prof(b).get("supportedArchs", ["arm64"])]
        gen = lambda b: [int(x) for x in "".join(c if c.isdigit() else " " for c in prof(b)["modelIdentifier"]).split()]
        for b in sorted(cands, key=lambda b: (gen(b), b), reverse=True):
            plat[b] = key
    out, written = {}, set()
    for b in plat:
        p = prof(b)
        caps = files[b + "/Contents/Resources/capabilities.plist"]
        sd = caps["capabilities"]["ScreenDimensionsCapability"]
        model = p["modelIdentifier"]
        js = "devicetype-%s.json" % model.lower()
        e = out[b[:-len(".simdevicetype")]] = {
            "model": model, "class": p["productClass"],
            "w": str(ints(sd["main-screen-width"])), "h": str(ints(sd["main-screen-height"])),
            # numbers, or strings in a few profiles (Apple TV 4K (4th generation) (at 1080p)); Apple TV: no pitch (an external display)
            # Apple TV 4K at 3840x2160: MobileGestalt's main-screen-scale says 1, but tvOS lays out 1920x1080 points,
            # so at scale 1 the UI filled a quarter of the screen; the artwork scale factor (2) is the screen's scale
            "scale": "%f" % (float(caps["capabilities"].get("ArtworkTraits", {}).get("ArtworkDeviceScaleFactor", 1))
                             if caps["capabilities"].get("ArtworkTraits", {}).get("ArtworkDeviceIdiom") == "tv"
                             else float(sd["main-screen-scale"])),
            "pitch": "%f" % float(sd.get("main-screen-pitch", 0)),
            "suffix": p.get("environment", {}).get("SIMULATOR_LEGACY_ASSET_SUFFIX",
                                                    "" if plat[b] else
                                                    "ipad" if 2 in p["supportedProductFamilyIDs"] else "iphone"),
            "json": js}
        if plat[b]:
            e["platform"] = plat[b]
        elif b not in supported:
            e["note"] = (f"iOS {rtver} lists it as unsupported (Xcode can't create it on this runtime); it has a build of its "
                         f"own (iPhone Duo: 27.2 24B91016s, runtime-fetch.py fetch 24B91016s)")
        if js not in written:
            written.add(js)
            with open(os.path.join(out_dir, js), "w") as f:
                json.dump(ints(caps), f, indent=1, sort_keys=True)
    # x86Sim's own device types (no Apple profile): a variant of an Apple one right after it
    final = {}
    for name, e in out.items():
        final[name] = e
        for xname, (base, scale) in X86SIM_TYPES.items():
            if base == name:
                final[xname] = dict(e, w=str(int(e["w"]) // scale), h=str(int(e["h"]) // scale),
                                    scale="%f" % (float(e["scale"]) / scale), pitch="%f" % (float(e["pitch"]) / scale))
    out = final
    with open(os.path.join(out_dir, "devicetypes-a64.json"), "w") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    print(f"{sum(1 for v in out.values() if 'platform' in v)} of them Apple TV / Apple Watch / Apple Vision Pro")
    print(f"{len(out)} device types ({len(written)} capability files) for iOS {rtver} {build}")


if __name__ == "__main__":
    main()
