#!/bin/bash
# x86Sim: Linux drop-in for `xcrun -sdk <sdk> metal` / `metallib`: Apple's own Metal toolchain, run under Darling.
#
# The Metal Shading Language front end exists only in Apple's toolchain (AIR re-encoded by upstream LLVM is rejected
# by Apple's MTLCompilerService). Since Xcode 26 that toolchain is a separate public download (a MobileAsset, no Apple
# ID): build/metal-toolchain.py fetches it into sdks/metal-<build>/ (x86_64 slice), and this script runs its `metal` /
# `metallib` in a Darling container of its own (X86SIM_METAL_DPREFIX, default $X86SIM_SCRATCH/metal-prefix), with
# build/metal-shim.c's library inserted. Same output as on a Mac with the same toolchain build.
#
# Usage (the arguments Xcode's tools take; `-sdk <sdk>` picks sdks/<Platform>.sdk as SDKROOT, as xcrun does):
#   build/linux-metal.sh metal    -target air64-apple-ios26.5-simulator -c probe.metal -o probe.air
#   build/linux-metal.sh metal    -sdk iphonesimulator k.metal -o k.metallib -framework CoreImage
#   build/linux-metal.sh metallib probe.air -o probe.metallib
#   build/linux-metal.sh inspect  <file.metallib>...           # header, sections, functions (type, hash check)
# Also works when symlinked as `metal` / `metallib`.
set -euo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)

inspect() {
	python3 -I - "$@" <<'PY'
import struct, sys, hashlib
TYPES = {0: "vertex", 1: "fragment", 2: "kernel", 3: "unqualified", 4: "visible", 5: "extern", 6: "intersection"}
for path in sys.argv[1:]:
    b = open(path, "rb").read()
    if b[:4] != b"MTLB":
        print(f"{path}: not a metallib (magic {b[:4]!r})"); continue
    plat, vmaj, vmin, ftype, osv, osmaj, osmin = struct.unpack_from("<HHHBBHH", b, 4)
    size, = struct.unpack_from("<Q", b, 0x10)
    secs = [struct.unpack_from("<QQ", b, 0x18 + 16 * i) for i in range(4)]
    print(f"{path}: {len(b)} bytes (header says {size}), platform {plat}, format {vmaj}.{vmin}, file type {ftype}, "
          f"os {osv & 0x7f} {osmaj}.{osmin}")
    print("  sections funclist/public/private/bitcode:", ", ".join(f"{o}+{s}" for o, s in secs))
    fo, _ = secs[0]; bo = secs[3][0]
    n, = struct.unpack_from("<I", b, fo); p = fo + 4
    for _ in range(n):
        ln, = struct.unpack_from("<I", b, p); q, end, tags = p + 4, p + ln, {}
        while q < end:
            t = b[q:q + 4]; q += 4
            if t == b"ENDT": break
            sz, = struct.unpack_from("<H", b, q); q += 2; tags[t.decode("latin1")] = b[q:q + sz]; q += sz
        p = end
        name = tags.get("NAME", b"?").rstrip(b"\0").decode()
        ty = TYPES.get(tags["TYPE"][0], tags["TYPE"][0]) if "TYPE" in tags else "?"
        vers = struct.unpack("<4H", tags["VERS"]) if len(tags.get("VERS", b"")) == 8 else None
        ok, sz = "?", 0
        if "OFFT" in tags and "MDSZ" in tags and "HASH" in tags:
            bc = bo + struct.unpack("<QQQ", tags["OFFT"])[2]; sz, = struct.unpack("<Q", tags["MDSZ"])
            body = b[bc:bc + sz]
            ok = "ok" if hashlib.sha256(body).digest() == tags["HASH"] else "MISMATCH"
        print(f"  {name:16} {ty:9} air {vers[0]}.{vers[1]} lang {vers[2]}.{vers[3]}" if vers else f"  {name:16} {ty:9}",
              f"bitcode {sz} B sha256 {ok}", sep="  ")
PY
}

# run <tool> <args...>: the toolchain's tool in the Darling container, Linux paths seen through /Volumes/SystemRoot
run() {
	local tool=$1; shift
	TC=$(python3 -I "$ROOT/build/metal-toolchain.py" path) || {
		echo "linux-metal: no Metal toolchain in sdks/: build/metal-toolchain.py fetch (about 840 MB from Apple)" >&2; exit 1; }
	X86SIM_ROOT=${X86SIM_ROOT:-$ROOT}; . "$ROOT/cli/lib/config.sh"
	local V=/Volumes/SystemRoot args="" a sdkroot=${SDKROOT:-}
	q() { printf "'%s'" "$(printf %s "$1" | sed "s/'/'\\\\''/g")"; }
	while (($#)); do
		a=$1; shift
		case $a in
			-sdk) case $1 in iphonesimulator*) sdkroot=$ROOT/sdks/iPhoneSimulator.sdk ;;
				appletvsimulator*) sdkroot=$ROOT/sdks/AppleTVSimulator.sdk ;; watchsimulator*) sdkroot=$ROOT/sdks/WatchSimulator.sdk ;;
				xrsimulator*) sdkroot=$ROOT/sdks/XRSimulator.sdk ;; macosx*) sdkroot=$ROOT/sdks/MacOSX.sdk ;;
				*) echo "linux-metal: unknown sdk $1" >&2; exit 2 ;; esac; shift; continue ;;
			/*) a=$V$(realpath -m "$a") ;;
			-I/*|-o/*|-F/*|-L/*) a=${a:0:2}$V$(realpath -m "${a:2}") ;;
		esac
		args="$args $(q "$a")"
	done
	local env="DYLD_FORCE_FLAT_NAMESPACE=1 DYLD_INSERT_LIBRARIES=$(q "$V$TC/libmetalshim.dylib")"
	[ -n "$sdkroot" ] && env="$env SDKROOT=$(q "$V$(realpath "$sdkroot")")"
	DPREFIX=${X86SIM_METAL_DPREFIX:-$X86SIM_SCRATCH/metal-prefix} "$X86SIM_DARLING" shell /bin/sh -c \
		"cd $(q "$V$(pwd -P)") && $env exec $(q "$V$TC/bin/$tool")$args"
}

me=$(basename "$0")
case $me in metal|metallib) run "$me" "$@"; exit ;; esac
cmd=${1:-}; shift || true
case $cmd in
	metal|metallib) run "$cmd" "$@" ;;
	inspect) inspect "$@" ;;
	*) sed -n '2,/^set -e/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2 ;;
esac
