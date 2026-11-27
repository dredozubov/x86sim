#!/bin/sh
# x86Sim: make the Darling pieces a boot uses match our build, so a recreated prefix can't lose fixes again.
# (2026-11-01: $X86SIM_SCRATCH/a64prefix was recreated and lost the libsystem_kernel installed there in Speed 12, whose
# dserver RPC fix stops "Bad S2C call: no FD, but expected one" aborts; backboardd then died on Photos/Maps launches.)
#
# Each manifest line: <path under external/darling/build> <path under the Darling install root>. A piece whose build
# output differs from the installed one is copied into the install root (darling-prefix/libexec/darling, the lower
# layer every prefix overlays; copy + rename, so running processes keep their mapping). A copy in the prefix's own
# upper layer that differs would shadow it: it is replaced the same way (only when the prefix is already set up:
# Darling treats an existing prefix dir as initialized, so a fresh one is never created here).
# A third field "platform": the piece gets tools/debug/set_macho_platform.py (as tools/debug/dinstall.sh does) before
# it is compared and installed.
# Speed 27: libsystem_c (Darling's libkqueue is linked into it) and libkqueue_sim (the simulator's kqueue) joined: the
# close() knote fix (libkqueue kqueue_closed_fd) lives in both.
# fileproviderd vnode: libSystem.B too: Darling links a copy of libkqueue into it (kevent() of Darling's own x86_64
# programs; the simulator's arm64 processes use libkqueue_sim).
# RAM 2: libsystem_kernel records jetsam state (process/memorystatus.c) for cli/libexec/jetsam.py.
# darlingserver too (field "host": a Linux binary beside the install root, never in a prefix): libsystem_kernel and
# darlingserver share one RPC call table (darlingserver's generate-rpc-wrappers.py), so a libsystem_kernel built
# after a darlingserver change and installed without it makes every container's darlingserver abort in its first
# calls (2026-11-27: upstream's mach_sq calls shifted the numbers; InterruptExit::processCall abort, "Timed out
# waiting for shellspawn in container" on every boot).
# Usage: prefix-heal.sh <prefix dir>        (A64_PREFIX_HEAL=0 in boot-a64.sh: skip)
X=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
P=$1
B=$X/external/darling/build
I=${X86SIM_DARLING_ROOT:-$X/darling-prefix/libexec/darling}
MANIFEST="
src/external/xnu/darling/src/libsystem_kernel/libsystem_kernel.dylib usr/lib/system/libsystem_kernel.dylib
src/external/libc/libsystem_c.dylib usr/lib/system/libsystem_c.dylib
src/external/libsystem/libSystem.B.dylib usr/lib/libSystem.B.dylib
src/external/libkqueue/libkqueue_sim.dylib usr/lib/darling/libkqueue_sim.dylib platform
src/external/darlingserver/darlingserver ../../bin/darlingserver host
"
install1() {  # <src> <dst>
	mkdir -p "$(dirname "$2")" && cp "$1" "$2.heal.$$" && mv -f "$2.heal.$$" "$2" && echo "  prefix-heal: installed $2"
}
RPC=$X/external/darling/src/external/darlingserver/scripts/generate-rpc-wrappers.py
DS=$B/src/external/darlingserver/darlingserver
if [ -f "$RPC" ] && [ -f "$DS" ] && [ "$RPC" -nt "$DS" ]; then
	echo "  prefix-heal: WARNING: $DS is older than its RPC table ($RPC): rebuild it (ninja -C $B darlingserver)," \
		"or the libsystem_kernel built since will not talk to it"
fi
TMPD=$(mktemp -d /tmp/x86sim-heal.XXXXXX) || exit 0
echo "$MANIFEST" | while read -r src dst opt; do
	[ -n "$src" ] || continue
	if [ ! -f "$B/$src" ]; then echo "  prefix-heal: no build output $src (not built?)"; continue; fi
	f=$B/$src
	if [ "$opt" = platform ]; then
		f=$TMPD/$(basename "$src"); cp "$B/$src" "$f" && python3 -I "$X/tools/debug/set_macho_platform.py" "$f" >/dev/null || continue
	fi
	cmp -s "$f" "$I/$dst" || install1 "$f" "$I/$dst"
	[ "$opt" = host ] && continue
	if [ -n "$P" ] && [ -f "$P/$dst" ] && ! cmp -s "$f" "$P/$dst"; then install1 "$f" "$P/$dst"; fi
done
rm -rf "$TMPD"
exit 0
