#!/bin/sh
# x86Sim: compile probe.metal for the iOS simulator (AIR + metallib) on Linux: Apple's Metal toolchain under Darling
# (build/linux-metal.sh through build/linux-bin/xcrun; build/metal-toolchain.py fetch installs it).
# Outputs: probe.air (AIR bitcode), probe.metallib, probe.ll (disassembled AIR when the toolchain has a disassembler),
# and the copies mtlprobe embeds: probe_metallib.h, probe_source.h (rebuild mtlprobe afterwards:
# build/mac-build-arm64-shims.sh mtlprobe, and X86SIM_PLATFORM=tvos|watchos for the others).
set -e
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}; export X86SIM_ROOT
cd "$X86SIM_ROOT/tests/metal/shaders"
XCRUN="$X86SIM_ROOT/build/linux-bin/xcrun -sdk iphonesimulator"
TGT="-target air64-apple-ios26.5-simulator"
$XCRUN metal $TGT -c probe.metal -o probe.air
$XCRUN metallib probe.air -o probe.metallib
(llvm-dis probe.air -o probe.ll 2>/dev/null || true)
ls -la probe.air probe.metallib
python3 -I - <<'PY'
import json
b = open("probe.metallib", "rb").read()
rows = [", ".join("0x%02x" % c for c in b[i:i + 12]) for i in range(0, len(b), 12)]
open("probe_metallib.h", "w").write("unsigned char probe_metallib[] = {\n  " + ",\n  ".join(rows) +
                                    "\n};\nunsigned int probe_metallib_len = %d;\n" % len(b))
open("probe_source.h", "w").write("// generated from probe.metal by build.sh\nstatic const char probe_metal_source[] = "
                                  + json.dumps(open("probe.metal").read()) + ";\n")
PY
