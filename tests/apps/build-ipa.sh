#!/bin/bash
# x86Sim: build tests/apps/DeviceHello as a DEVICE app (iphoneos SDK, arm64-apple-ios27.0) on Linux and package it as an
# .ipa (Payload/DeviceHello.app) in $X86SIM_SCRATCH/apps/DeviceHello.ipa: the fixture for `x86sim install X.ipa`
# (tools/launcher core/src/devapp.rs). It has what a real export has: an embedded framework (fat: arm64 + arm64e),
# entitlements in the code signature (application-identifier, keychain-access-groups, get-task-allow),
# CFBundleSupportedPlatforms iPhoneOS / DTPlatformName iphoneos. Signed ad-hoc (no certificate needed): the conversion
# re-signs anyway. Usage: tests/apps/build-ipa.sh
# Toolchain: the device toolchain `x86sim dev device` uses: Swift 6.4 with the Darwin SDK `x86sim dev setup sdk --xip`
# makes from Xcode.xip on Linux (X86SIM_DARWIN_SDK, default ~/.config/swiftpm/swift-sdks/darwin.artifactbundle: its
# iPhoneOS.sdk and Xcode's Swift resource dir), clang + ld64.lld, llvm-lipo and rcodesign.
set -eo pipefail
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
. "$X86SIM_ROOT/cli/lib/config.sh"
B=${X86SIM_DARWIN_SDK:-$HOME/.config/swiftpm/swift-sdks/darwin.artifactbundle}
SDK=$B/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
RES=$B/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift
[ -d "$SDK" ] && [ -d "$RES/iphoneos" ] || { echo "build-ipa: no Darwin SDK with iPhoneOS at $B (x86sim dev setup sdk --xip Xcode.xip)" >&2; exit 1; }
for t in swiftc clang ld64.lld llvm-lipo rcodesign zip; do command -v $t >/dev/null || { echo "build-ipa: $t not found" >&2; exit 1; }; done
S=$X86SIM_ROOT/tests/apps/DeviceHello; OUT=$X86SIM_SCRATCH/apps; mkdir -p "$OUT"
W=$(mktemp -d "$X86SIM_SCRATCH/x86ipa.XXXXXX"); trap 'rm -rf "$W"' EXIT
cd "$W"
APP=Payload/DeviceHello.app; F=$APP/Frameworks/Greeter.framework; mkdir -p "$F"
CC="clang -fuse-ld=lld -isysroot $SDK -Wno-unused-command-line-argument"
for a in arm64 arm64e; do
	$CC -target $a-apple-ios27.0 -dynamiclib -install_name @rpath/Greeter.framework/Greeter -o g-$a "$S/Greeter.c"
done
# ld64.lld writes an arm64e link as cpusubtype ALL; Apple's ld marks it arm64e with the pointer-auth ABI bit
# (CPU_SUBTYPE_ARM64E | CPU_SUBTYPE_PTRAUTH_ABI), which is what lipo and the conversion key the slice on
python3 -I - g-arm64e <<'PY'
import struct, sys
p = sys.argv[1]; b = bytearray(open(p, "rb").read())
assert struct.unpack_from("<II", b, 0) == (0xfeedfacf, 0x0100000c), "not an arm64 Mach-O"
struct.pack_into("<I", b, 8, 0x80000002)
open(p, "wb").write(b)
PY
llvm-lipo -create g-arm64 g-arm64e -output "$F/Greeter"
# linked by the system's ld64.lld through the toolchain clang (-isysroot: LC_BUILD_VERSION sdk 27.2), as
# build/linux-swiftc.sh does for the simulator
SWIFTC="swiftc -sdk $SDK -target arm64-apple-ios27.0 -resource-dir $RES"
$SWIFTC -Xfrontend -enable-cross-import-overlays -Onone -parse-as-library -module-name DeviceHello -c -o app.o "$S/App.swift"
$SWIFTC -use-ld=lld -ld-path="$(command -v ld64.lld)" -Xclang-linker -isysroot -Xclang-linker "$SDK" \
	-F "$APP/Frameworks" -framework Greeter -Xlinker -rpath -Xlinker @executable_path/Frameworks -o "$APP/DeviceHello" app.o
python3 -I - "$APP" "$F" <<'PY'
import plistlib, sys
app, fw = sys.argv[1:3]
plistlib.dump({"CFBundleIdentifier": "com.x86sim.test.Greeter", "CFBundleExecutable": "Greeter",
               "CFBundlePackageType": "FMWK", "CFBundleSupportedPlatforms": ["iPhoneOS"], "DTPlatformName": "iphoneos",
               "MinimumOSVersion": "27.0", "CFBundleVersion": "1"}, open(fw + "/Info.plist", "wb"), fmt=plistlib.FMT_BINARY)
plistlib.dump({"CFBundleIdentifier": "com.x86sim.test.DeviceHello", "CFBundleName": "DeviceHello",
               "CFBundleDisplayName": "DeviceHello", "CFBundleExecutable": "DeviceHello", "CFBundlePackageType": "APPL",
               "CFBundleShortVersionString": "1.0", "CFBundleVersion": "1", "CFBundleSupportedPlatforms": ["iPhoneOS"],
               "DTPlatformName": "iphoneos", "DTSDKName": "iphoneos27.2", "MinimumOSVersion": "27.0",
               "UIDeviceFamily": [1, 2], "UIRequiredDeviceCapabilities": ["arm64"], "UILaunchScreen": {},
               "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False}},
              open(app + "/Info.plist", "wb"), fmt=plistlib.FMT_BINARY)
plistlib.dump({"application-identifier": "ABCDE12345.com.x86sim.test.DeviceHello",
               "com.apple.developer.team-identifier": "ABCDE12345",
               "keychain-access-groups": ["ABCDE12345.com.x86sim.test.DeviceHello"], "get-task-allow": True},
              open("ents.plist", "wb"))
PY
rcodesign sign "$F" >/dev/null
rcodesign sign -e ents.plist "$APP" >/dev/null
zip -qry app.ipa Payload
mv app.ipa "$OUT/DeviceHello.ipa"
ls -l "$OUT/DeviceHello.ipa"
