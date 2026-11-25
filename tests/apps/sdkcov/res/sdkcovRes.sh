#!/bin/bash
# makes res/sdkcovChapters.mov, res/sdkcovStall.mov (res/sdkcovMovies.swift) and res/sdkcovGK.sks (res/sdkcovGK.swift)
# on Linux: the generators are iOS simulator programs (AVAssetWriter, SpriteKit, GameplayKit), built with the repo's
# toolchain (build/linux-env.sh, as tests/apps/build.sh) and run on a booted arm64 phone with `x86sim spawn` (the movie
# writer needs the phone's iosurfaced and media services; plain Darling has no IOSurface). Each writes next to its own
# executable, in the device's tmp, and the files are copied back into res/.
# Usage: tests/apps/sdkcov/res/sdkcovRes.sh PHONE   (a booted iPhone: name, var/ folder or device dir)
set -e
R=$(cd "$(dirname "$0")" && pwd)
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$R/../../../.." && pwd)}
. "$X86SIM_ROOT/build/mac-env.sh"
. "$X86SIM_ROOT/cli/lib/pickdevice.sh"
[ $# = 1 ] && pick_device "$1" || { echo "usage: $0 PHONE (a booted arm64 iPhone)" >&2; exit 2; }
D=$X86SIM_DEVICE/data/tmp; mkdir -p "$D"
W=$(mktemp -d "$X86SIM_SCRATCH/sdkcovRes.XXXXXX"); trap 'rm -rf "$W"' EXIT
build() {  # build OUT SOURCE [swiftc flags]
	local o=$1 s=$2; shift 2
	nice xcrun -sdk iphonesimulator swiftc -target arm64-apple-ios27.0-simulator -Onone "$@" -o "$W/$o" "$R/$s" 2>&1 |
		grep -v -e 'directory not found for option -L' -e 'warning:' -e '^ *[0-9]* |' -e '^ *|' -e '^\[#' -e '^$' >&2 || true
	test -x "$W/$o"
}
build sdkcovGK sdkcovGK.swift
build sdkcovMovies sdkcovMovies.swift -parse-as-library
rm -f "$D/sdkcovGK.sks" "$D/sdkcovChapters.mov" "$D/sdkcovStall.mov"
"$X86SIM_ROOT/cli/x86sim" spawn "$X86SIM_DEVICE" --timeout 120 "$W/sdkcovGK"
"$X86SIM_ROOT/cli/x86sim" spawn "$X86SIM_DEVICE" --timeout 600 "$W/sdkcovMovies"
for f in sdkcovGK.sks sdkcovChapters.mov sdkcovStall.mov; do
	[ -s "$D/$f" ] || { echo "$0: $f not written" >&2; exit 1; }
	mv "$D/$f" "$R/$f"
	echo "$f $(stat -c %s "$R/$f") B"
done
