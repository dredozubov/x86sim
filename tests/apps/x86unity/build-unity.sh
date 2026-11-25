#!/bin/bash
# x86Sim: build x86unity (tests/apps/build.sh x86unity) and put its stand-in engine in it as
# Frameworks/UnityFramework.framework, the name simax_unity.m looks for (fakeunity.m exports IL2CPP's API; it is not
# Unity). Usage: tests/apps/x86unity/build-unity.sh  (-> $X86SIM_SCRATCH/apps/x86unity.app)
set -eo pipefail
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
"$X86SIM_ROOT/tests/apps/build.sh" x86unity >/dev/null
. "$X86SIM_ROOT/build/mac-env.sh"
APP=$X86SIM_SCRATCH/apps/x86unity.app
tar cf - -C "$X86SIM_ROOT/tests/apps/x86unity" fakeunity.m | mac "set -e; W=\$(mktemp -d /tmp/x86unity.XXXXXX); cd \$W; tar xf -
	F=UnityFramework.framework; mkdir \$F
	$SIMCC -dynamiclib -O1 -install_name @rpath/UnityFramework.framework/UnityFramework -fno-objc-arc -Wno-deprecated-declarations -framework Foundation -framework CoreGraphics -framework QuartzCore -framework UIKit -o \$F/UnityFramework fakeunity.m >&2
	cat > \$F/Info.plist <<PL
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>com.x86sim.test.x86unity.engine</string>
<key>CFBundleExecutable</key><string>UnityFramework</string><key>CFBundlePackageType</key><string>FMWK</string></dict></plist>
PL
	codesign -f -s - \$F >&2; tar cf - \$F; cd /; rm -rf \$W" | (mkdir -p "$APP/Frameworks" && cd "$APP/Frameworks" && rm -rf UnityFramework.framework && tar xf -)
# signed again as a whole (the framework is new in it); through a file: on Linux the "Mac" is this machine
T=$(mktemp "$X86SIM_SCRATCH/x86unity.XXXXXX.tar"); tar cf "$T" -C "$X86SIM_SCRATCH/apps" x86unity.app
mac "set -e; W=\$(mktemp -d /tmp/x86unity.XXXXXX); cd \$W; tar xf -; codesign -f -s - x86unity.app >&2; tar cf - x86unity.app; cd /; rm -rf \$W" < "$T" |
	(cd "$X86SIM_SCRATCH/apps" && rm -rf x86unity.app && tar xf -)
rm -f "$T"; ls -d "$APP"
