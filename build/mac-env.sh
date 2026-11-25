# x86Sim: sourced by build/mac-build-*.sh. The simulator-side binaries (host/, tests/) are Mach-O for the arm64 iOS
# simulator (simhost: macOS x86_64, Darling's host side), built on Linux with clang + ld64.lld and the SDKs in sdks/
# (build/linux-env.sh; `make sdks` makes them without a Mac). The scripts keep the shape they had when they ran over ssh:
# mac() runs a command string here, sources on stdin, the built file on stdout.
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}; . "$X86SIM_ROOT/cli/lib/config.sh"
X=$X86SIM_ROOT
export X86SIM_BUILD=linux
. "$X/build/linux-env.sh"
