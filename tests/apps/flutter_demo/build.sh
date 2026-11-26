#!/bin/bash
# x86Sim: build flutter_demo on Linux as a device app (an iPhone .ipa: Flutter builds for the simulator only on a Mac)
# with the dev toolchain's Flutter scripts (omarchy-apple-dev flutter/build.sh, after its flutter/setup.sh), for
# app_install's device-app conversion. A device build waits for VoiceOver before it builds its semantics tree: what
# simax's screen-reader switch is for.
# Usage: tests/apps/flutter_demo/build.sh   (-> $X86SIM_SCRATCH/apps/flutter_demo.ipa, bundle com.x86sim.test.flutterDemo)
# Env: FLUTTER (default: flutter on PATH), X86SIM_DEV_FORK (default ~/omarchy-apple-dev)
set -eo pipefail
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
. "$X86SIM_ROOT/cli/lib/config.sh"
FL=${FLUTTER:-$(command -v flutter)} || { echo "flutter is not on PATH (set FLUTTER)" >&2; exit 1; }
FORK=${X86SIM_DEV_FORK:-$HOME/omarchy-apple-dev}
OUT=${X86SIM_SCRATCH:?}/apps; W=$OUT/flutter_demo-src
rm -rf "$W"; mkdir -p "$W"
cp -r "$X86SIM_ROOT/tests/apps/flutter_demo/lib" "$X86SIM_ROOT/tests/apps/flutter_demo/pubspec.yaml" "$W/"
(cd "$W" && "$FL" create --platforms ios --org com.x86sim.test --project-name flutter_demo . >&2)
PATH=$(dirname "$FL"):$PATH BUNDLE_ID=com.x86sim.test.flutterDemo bash "$FORK/flutter/build.sh" "$W" >&2
cp "$W/build/ios-linux/Runner.ipa" "$OUT/flutter_demo.ipa"
ls "$OUT/flutter_demo.ipa"
