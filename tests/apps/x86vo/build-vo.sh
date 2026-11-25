#!/bin/bash
# x86Sim: build x86vo (tests/apps/build.sh x86vo) and put its stand-in engine in it as Frameworks/Flutter.framework,
# the name simax_engines.m looks for. Usage: tests/apps/x86vo/build-vo.sh  (-> $X86SIM_SCRATCH/apps/x86vo.app)
set -eo pipefail
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
"$X86SIM_ROOT/tests/apps/build.sh" x86vo >/dev/null
. "$X86SIM_ROOT/build/mac-env.sh"
APP=$X86SIM_SCRATCH/apps/x86vo.app
tar cf - -C "$X86SIM_ROOT/tests/apps/x86vo" engine.c | mac "set -e; W=\$(mktemp -d /tmp/x86vo.XXXXXX); cd \$W; tar xf -
	F=Flutter.framework; mkdir \$F
	$SIMCC -dynamiclib -O1 -install_name @rpath/Flutter.framework/Flutter -framework CoreFoundation -framework UIKit -o \$F/Flutter engine.c >&2
	cat > \$F/Info.plist <<PL
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>com.x86sim.test.x86vo.engine</string>
<key>CFBundleExecutable</key><string>Flutter</string><key>CFBundlePackageType</key><string>FMWK</string></dict></plist>
PL
	codesign -f -s - \$F >&2; tar cf - \$F; cd /; rm -rf \$W" | (mkdir -p "$APP/Frameworks" && cd "$APP/Frameworks" && rm -rf Flutter.framework && tar xf -)
# signed again as a whole (the framework is new in it); through a file: on Linux the "Mac" is this machine
T=$(mktemp "$X86SIM_SCRATCH/x86vo.XXXXXX.tar"); tar cf "$T" -C "$X86SIM_SCRATCH/apps" x86vo.app
mac "set -e; W=\$(mktemp -d /tmp/x86vo.XXXXXX); cd \$W; tar xf -; codesign -f -s - x86vo.app >&2; tar cf - x86vo.app; cd /; rm -rf \$W" < "$T" |
	(cd "$X86SIM_SCRATCH/apps" && rm -rf x86vo.app && tar xf -)
rm -f "$T"; ls -d "$APP"
