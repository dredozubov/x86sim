#!/bin/sh
# CI helpers for .github/workflows/build.yml: one cache per build component, keyed by that component's inputs, so a run
# rebuilds only the components whose inputs changed (a launcher-only change restores Darling, arm64jit and mtlvk).
#   ci.sh keys             print <component>=<cache key> lines (build.yml appends them to $GITHUB_OUTPUT)
#   ci.sh collect <comp>   after building <comp>: copy its outputs, and the licenses of its submodules (appimage.sh
#                          packs them; a run that restores <comp> does not check those submodules out), to parts/<comp>
#   ci.sh stage <comp>     after restoring parts/<comp>: put its outputs where build.sh puts them
# Components: darling (Darling + arm64host, which links with Darling's build tree; its output is destdir itself),
# arm64jit, mtlvk, launcher, lavapipe. A key hashes HEAD's git objects for each input path (a tree, a blob or a submodule commit):
# it ignores uncommitted changes. When a component starts reading a file outside its inputs, add the path below;
# bump KV to drop every cached component at once.
#   OUT (default build/release/out), as build.sh
set -e
X=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${OUT:-$X/build/release/out}
L=$OUT/destdir/opt/x86sim/darling/libexec/darling/usr/libexec/darling
KV=1
# collect / stage below decide what a cached component holds: this script is an input of every component
SELF=build/release/ci.sh
COMPONENTS="darling arm64jit mtlvk launcher lavapipe"

inputs() { case $1 in
	darling) echo $SELF external/darling host/arm64host tools/debug/set_macho_platform.py build/release/build.sh build/release/deps-ubuntu.sh ;;
	arm64jit) echo $SELF external/dynarmic linux/arm64jit build/release/build.sh build/release/deps-ubuntu.sh ;;
	mtlvk) echo $SELF external/metal2vulkan linux/mtlvk build/release/build.sh ;;
	# include_str!/include_bytes! of files outside the crate: features.rs, desktop.rs
	launcher) echo $SELF tools/launcher cli/libexec/arm64/features-def.json build/release/x86sim.desktop build/release/x86sim.png \
		build/release/build.sh ;;
	lavapipe) echo $SELF build/lavapipe.sh build/release/build.sh build/release/deps-ubuntu.sh ;;
	*) echo "ci: unknown component $1" >&2; exit 1 ;;
esac; }

case $1 in
keys)
	for c in $COMPONENTS; do
		ids=
		for p in $(inputs "$c"); do
			id=$(git -C "$X" rev-parse --verify -q "HEAD:$p") || { echo "ci: $c: input $p is not in HEAD" >&2; exit 1; }
			ids="$ids$p $id
"
		done
		echo "$c=$c-v$KV-$(printf %s "$ids" | sha256sum | cut -c1-24)"
	done
	;;
collect)
	inputs "$2" >/dev/null
	P=$OUT/parts/$2
	rm -rf "$P" && mkdir -p "$P/licenses"
	case $2 in
	darling)
		cp "$X/external/darling/LICENSE" "$P/licenses/darling-LICENSE"
		# the cache's tar, extracting as a user, applies the umask and drops setuid/setgid (bin/darling 4755,
		# private/var/tmp 1777): keep those modes for stage (they are part of DARLING_ID and needed at install)
		(cd "$OUT/destdir" && find . ! -type l -perm /7022 -printf '%m %p\n') > "$P/modes" ;;
	arm64jit)
		cp -p "$OUT/build-arm64jit/libarm64jit.so" "$OUT/build-arm64jit/a64hugecopy" "$P/"
		cp "$X/external/dynarmic/LICENSE.txt" "$P/licenses/dynarmic-LICENSE" ;;
	mtlvk)
		cp -p "$OUT/cargo-mtlvk/release/mtlvk" "$P/"
		for f in "$X"/external/metal2vulkan/LICENSE*; do cp "$f" "$P/licenses/metal2vulkan-$(basename "$f")"; done ;;
	launcher) find "$OUT/cargo-launcher/release" -maxdepth 1 -type f -name 'x86sim-*' -perm -u+x -exec cp -p -t "$P/" {} + ;;
	lavapipe) cp -a "$OUT/lavapipe" "$P/lavapipe" ;;  # its LICENSE is inside
	esac
	# mtlvk's and the launcher's debug info (appimage.sh strips it too): a smaller cache. Nothing in destdir: appimage.sh
	# strips only some of it, and DARLING_ID hashes the rest as built
	case $2 in mtlvk|launcher) find "$P" -maxdepth 1 -type f -perm -u+x -exec strip --strip-debug {} + ;; esac
	echo "ci: $2: $(du -sh "$P" | cut -f1) collected"
	;;
stage)
	inputs "$2" >/dev/null
	P=$OUT/parts/$2
	case $2 in
	darling)
		[ -x "$OUT/destdir/opt/x86sim/darling/bin/darling" ] || { echo "ci: darling: no restored destdir" >&2; exit 1; }
		(cd "$OUT/destdir" && while read -r m f; do chmod "$m" "$f"; done) < "$P/modes" ;;
	arm64jit) mkdir -p "$L" && cp -p "$P/libarm64jit.so" "$P/a64hugecopy" "$L/" ;;
	mtlvk) mkdir -p "$OUT/cargo-mtlvk/release" && cp -p "$P/mtlvk" "$OUT/cargo-mtlvk/release/" ;;
	launcher) mkdir -p "$OUT/cargo-launcher/release" && cp -p "$P"/x86sim-* "$OUT/cargo-launcher/release/" ;;
	lavapipe) rm -rf "$OUT/lavapipe" && cp -a "$P/lavapipe" "$OUT/lavapipe" ;;
	esac
	echo "ci: $2: staged from the cache"
	;;
*) echo "usage: ci.sh keys | collect <component> | stage <component>" >&2; exit 1 ;;
esac
