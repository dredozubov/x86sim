#!/bin/bash
# makes res/sdkcovCI-<platform>.metallib from res/sdkcovCI.metal on Linux: Apple's Metal toolchain under Darling
# (build/linux-metal.sh through build/linux-bin/xcrun; build/metal-toolchain.py fetch installs it). Stitchable Core Image
# kernels (linked against CoreImage; -fcikernel is the older non-stitchable form and leaves these out), one library per
# simulator platform. The library records its output name: k.metallib, as the libraries were first made.
set -e
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}
. "$X86SIM_ROOT/cli/lib/config.sh"
R=$X86SIM_ROOT/tests/apps/sdkcov/res
W=$(mktemp -d "$X86SIM_SCRATCH/sdkcovCI.XXXXXX"); trap 'rm -rf "$W"' EXIT
cp "$R/sdkcovCI.metal" "$W/k.metal"
for p in ios:iphonesimulator tvos:appletvsimulator xros:xrsimulator; do
	(cd "$W" && "$X86SIM_ROOT/build/linux-bin/xcrun" -sdk "${p#*:}" metal k.metal -o k.metallib -framework CoreImage)
	mv "$W/k.metallib" "$R/sdkcovCI-${p%%:*}.metallib"
	echo "sdkcovCI-${p%%:*}.metallib $(stat -c %s "$R/sdkcovCI-${p%%:*}.metallib") B"
done
