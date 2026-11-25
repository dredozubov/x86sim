#!/usr/bin/env python3
"""x86Sim: Apple's Metal toolchain (the `metal` compiler and `metallib` linker) straight from Apple, no Mac, no Apple ID.

    build/metal-toolchain.py list            the Metal toolchains in Apple's catalogue (the one Xcode reads)
    build/metal-toolchain.py fetch [BUILD]   download BUILD (default: the pinned one) into sdks/metal-<BUILD>/
    build/metal-toolchain.py path            the installed toolchain dir (exit 1 if none)

Xcode 26+ no longer ships the Metal compiler: `xcodebuild -downloadComponent MetalToolchain` fetches it as a MobileAsset,
exactly like the simulator runtimes (cli/libexec/arm64/runtime-fetch.py): the catalogue lists it under
otherDownloadables (assetType metalToolchain, downloadMethod mobileAsset), gdmf.apple.com answers the asset query with
an updates.cdn-apple.com URL to an encrypted Apple Archive and its key. Inside: a cryptex disk image holding
Metal.xctoolchain. Only what compiling and linking need is kept (usr/metal/<n>/bin/metal, air-lld = metallib,
lib/clang, lib/metalfe: about 360 MB), the binaries thinned to x86_64: build/linux-metal.sh runs them under Darling.
Plus build/metal-shim.c built here (two symbols the toolchain imports that Darling's libSystem / libc++ lack).
The toolchain is Apple's: never committed (sdks/ is gitignored), fetched per machine.
"""
import base64
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RF = os.path.join(ROOT, "cli", "libexec", "arm64")
sys.path.insert(0, RF)
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location("runtime_fetch", os.path.join(RF, "runtime-fetch.py"))
rf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rf)

# Xcode 27.2's toolchain (the SDKs and runtimes in use are 27.2)
PINNED = "27B47"
ASSET_TYPE = "com.apple.MobileAsset.MetalToolchain"
KEEP = ["bin/metal", "bin/air-lld", "bin/metallib", "lib/clang", "lib/metalfe", "ToolchainInfo.plist"]


def catalogue():
    with urllib.request.urlopen(rf.INDEX) as r:
        d = plistlib.loads(r.read())
    return [x for x in d.get("otherDownloadables", []) if x.get("assetType") == "metalToolchain"]


def asset(build):
    body = {"AssetAudience": rf.XCODE_SIM_AUDIENCE, "AssetType": ASSET_TYPE, "ClientVersion": 2,
            "CertIssuanceDay": "2023-12-10", "RequestedBuild": build, "Build": build, "BuildVersion": build}
    with tempfile.TemporaryDirectory() as tmp:
        r = subprocess.run(["curl", "-sf", "--cacert", rf.apple_ca(tmp), "-H", "Content-Type: application/json",
                            "-X", "POST", "--data", json.dumps(body), rf.GDMF], capture_output=True, text=True,
                           check=True).stdout
    p = r.strip().split(".")
    d = json.loads(base64.urlsafe_b64decode(p[1] + "=" * (-len(p[1]) % 4)))
    for a in d.get("Assets", []):
        if a.get("Build") == build:
            return a
    sys.exit(f"metal-toolchain: gdmf has no Metal toolchain {build}")


def installed():
    sd = os.path.join(ROOT, "sdks")
    want = os.environ.get("X86SIM_METAL_TOOLCHAIN")
    if want:
        return want if os.path.isfile(os.path.join(want, "bin", "metal")) else None
    for b in [PINNED] + sorted((d[6:] for d in os.listdir(sd) if d.startswith("metal-")) if os.path.isdir(sd) else [],
                               reverse=True):
        d = os.path.join(sd, "metal-" + b)
        if os.path.isfile(os.path.join(d, "bin", "metal")):
            return d
    return None


def build_shim(dst):
    """build/metal-shim.c -> dst/libmetalshim.dylib (macOS x86_64, Linux clang + lld + sdks/MacOSX.sdk)"""
    sdk = os.path.join(ROOT, "sdks", "MacOSX.sdk")
    if not os.path.isdir(sdk):
        sys.exit("metal-toolchain: no sdks/MacOSX.sdk for the shim (make sdks)")
    subprocess.run(["clang", "-fuse-ld=lld", "-isysroot", sdk, "-target", "x86_64-apple-macos10.15", "-dynamiclib",
                    "-O1", "-Wno-unused-command-line-argument", "-o", os.path.join(dst, "libmetalshim.dylib"),
                    os.path.join(ROOT, "build", "metal-shim.c")], check=True)


def fetch(build):
    a = asset(build)
    dst = os.path.join(ROOT, "sdks", "metal-" + build)
    work = dst + ".download"
    os.makedirs(work, exist_ok=True)
    aar = os.path.join(work, "toolchain.aar")
    url = a["__BaseURL"] + a["__RelativePath"]
    size = int(a["_DownloadSize"])
    print(f"Metal toolchain {build}: {size / 1e6:.0f} MB from {url}", flush=True)
    if not (os.path.exists(aar) and os.path.getsize(aar) == size):
        subprocess.run(["curl", "-f", "-C", "-", "-o", aar, url], check=True)
    if os.path.getsize(aar) != size:
        sys.exit("metal-toolchain: size mismatch")
    dec = os.path.join(work, "decrypted")
    os.makedirs(dec, exist_ok=True)
    subprocess.run(["ipsw", "fw", "aea", aar, "-b", a["ArchiveDecryptionKey"], "-o", dec], check=True)
    os.unlink(aar)
    for f in os.listdir(dec):
        subprocess.run([sys.executable, "-I", os.path.join(RF, "aaextract.py"), os.path.join(dec, f), "extract",
                        os.path.join(work, "bundle")], check=True, stdout=subprocess.DEVNULL)
    shutil.rmtree(dec)
    dmgs = [os.path.join(dp, f) for dp, _, fs in os.walk(os.path.join(work, "bundle")) for f in fs if f.endswith(".dmg")]
    if not dmgs:
        sys.exit("metal-toolchain: no disk image in the archive")
    dmg = max(dmgs, key=os.path.getsize)
    listing = subprocess.run(["7z", "l", "-slt", dmg], capture_output=True, text=True).stdout
    tc = sorted({ln[7:].split("/bin/metal")[0] for ln in listing.splitlines()
                 if ln.startswith("Path = ") and ln.endswith("/bin/metal") and "/usr/metal/" in ln})
    if not tc:
        sys.exit("metal-toolchain: no usr/metal/<n>/bin/metal in the image")
    ex = os.path.join(work, "x")
    subprocess.run(["7z", "x", "-snld", "-y", "-o" + ex, dmg] + [tc[0] + "/" + k for k in KEEP] + ["-r"],
                   check=True, stdout=subprocess.DEVNULL)
    shutil.rmtree(dst, ignore_errors=True)
    shutil.move(os.path.join(ex, tc[0]), dst)
    for b in ("metal", "air-lld"):  # x86_64 only: Darling runs that slice
        p = os.path.join(dst, "bin", b)
        subprocess.run(["llvm-lipo", "-thin", "x86_64", p, "-output", p + ".x86_64"], check=True)
        os.replace(p + ".x86_64", p)
    shutil.rmtree(work)
    build_shim(dst)
    with open(os.path.join(dst, "asset.json"), "w") as f:
        json.dump({k: a[k] for k in a if k != "ArchiveDecryptionKey"}, f, indent=1)
    print(dst)


def main():
    a = sys.argv[1:] or ["list"]
    if a[0] == "list":
        for x in catalogue():
            have = os.path.isdir(os.path.join(ROOT, "sdks", "metal-" + x["assetBuildUpdate"]))
            print(f"{x['assetBuildUpdate']:12} {x['name']}{'  (downloaded)' if have else ''}")
    elif a[0] == "fetch":
        fetch(a[1] if len(a) > 1 else PINNED)
    elif a[0] == "path":
        d = installed()
        if not d:
            sys.exit(1)
        print(d)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
