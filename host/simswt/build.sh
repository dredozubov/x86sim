#!/bin/bash
# x86Sim: build libsimswt.dylib (x86sim test's helper in the test process: Swift Testing's events, simswt.swift; the
# call stacks of XCTest issues without a location, simswt_issues.c) for a simulator platform, on
# Linux with the swift.org toolchain (build/linux-swiftc.sh) against the SDK in sdks/ and the platform's own
# Testing.framework (from Xcode.xip: x86sim dev setup sdk --xip). cli/libexec/xctest.py runs it once per platform and
# Testing version and keeps the result in the scratch dir.
#   host/simswt/build.sh <Xcode's ...Simulator.platform> <ios|tvos|watchos|xros> <out.dylib>
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
X=$(cd "$here/../.." && pwd)
plat_dir=${1:?usage: build.sh <platform dir> <ios|tvos|watchos|xros> <out.dylib>} plat=${2:?} out=${3:?}
case $plat in
ios) sdk=iPhoneSimulator; tgt=arm64-apple-ios17.0-simulator; arch=arm64-apple-ios-simulator ;;
tvos) sdk=AppleTVSimulator; tgt=arm64-apple-tvos17.0-simulator; arch=arm64-apple-tvos-simulator ;;
watchos) sdk=WatchSimulator; tgt=arm64-apple-watchos10.0-simulator; arch=arm64-apple-watchos-simulator ;;
xros) sdk=XRSimulator; tgt=arm64-apple-xros1.0-simulator; arch=arm64-apple-xros-simulator ;;
*) echo "simswt: platform ios, tvos, watchos or xros" >&2; exit 2 ;;
esac
sdks=${X86SIM_SDKS:-$X/sdks}
# watchOS / visionOS: the SDKs with Swift modules are the -xcode ones (as for the shims, build/mac-build-arm64-shims.sh)
if [ -d "$sdks/$sdk-xcode.sdk/usr/lib/swift/Swift.swiftmodule" ]; then sdk=$sdks/$sdk-xcode.sdk; else sdk=$sdks/$sdk.sdk; fi
fw=$plat_dir/Developer/Library/Frameworks
iface=$fw/Testing.framework/Modules/Testing.swiftmodule/$arch.swiftinterface
[ -f "$iface" ] || { echo "simswt: no $iface" >&2; exit 2; }
w=$(mktemp -d "$(dirname "$out")/.simswt.XXXXXX"); trap 'rm -rf "$w"' EXIT
# Testing's module: its public interface + the SPI declarations libsimswt uses (found by -I before any framework)
mkdir -p "$w/mods/Testing.swiftmodule"
cat "$iface" "$here/Testing-SPI.swiftinterface" > "$w/mods/Testing.swiftmodule/$arch.swiftinterface"
clang -target "$tgt" -isysroot "$sdk" -c -o "$w/interpose.o" "$here/simswt_interpose.c"
clang -target "$tgt" -isysroot "$sdk" -O1 -Wall -c -o "$w/issues.o" "$here/simswt_issues.c"
"$X/build/linux-swiftc.sh" -sdk "$sdk" -target "$tgt" -swift-version 5 -O -parse-as-library -module-name simswt \
	-module-cache-path "$w/mc" -I "$w/mods" -emit-library -o "$w/libsimswt.dylib" "$here/simswt.swift" "$w/interpose.o" "$w/issues.o" \
	-Xfrontend -disable-autolink-framework -Xfrontend Testing -Xlinker -F -Xlinker "$fw" \
	-Xlinker -weak_framework -Xlinker Testing -Xlinker -install_name -Xlinker @rpath/libsimswt.dylib >&2
# every Testing symbol it imports must be one Testing exports (the SPI declarations match the framework)
nm=$(command -v llvm-nm || echo "$X/sdks/swift-6.4.2/usr/bin/llvm-nm")
missing=$(comm -23 <("$nm" -u "$w/libsimswt.dylib" | awk '{print $NF}' | grep '^_$s7Testing' | sort -u) \
	<("$nm" --defined-only --extern-only --arch=arm64 "$fw/Testing.framework/Testing" | awk '{print $NF}' | sort -u))
[ -z "$missing" ] || { echo "simswt: Testing does not export: $missing" >&2; exit 1; }
mv "$w/libsimswt.dylib" "$out"
