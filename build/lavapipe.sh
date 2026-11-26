#!/bin/sh
# lavapipe, Mesa's CPU Vulkan driver, for a device's GPU setting "cpu" (linux/mtlvk/src/gpus.rs finds it at
# <mtlvk's dir>/../lavapipe), so that choice is there on every computer: one with no GPU, one with no Vulkan driver
# installed, or one whose user does not want a device on the GPU. Built from Mesa's pinned source release (sha256
# checked) with only llvmpipe and lavapipe, no window system, and LLVM linked in statically: one library that needs
# libc, libm, zlib, zstd and libdrm (a copy of libdrm goes beside it), instead of the distribution's package and its
# 180 MB of libLLVM, ICU and X11 / Wayland libraries.
#   build/lavapipe.sh [dest]   dest default linux/mtlvk/target/lavapipe (the checkout's copy; release AppImages carry
#                              it at the same path in their payload)
#   LAVAPIPE_DL                download and build dir (default: dest's parent/lavapipe-build)
#   LLVM_CONFIG                an llvm-config whose LLVM has static libraries (default: llvm-config-20, llvm-config).
#                              Ubuntu / Debian: llvm-20-dev libpolly-20-dev. Arch's llvm has shared libraries only:
#                              run this in the release container (build/release/docker-build.sh), or install the
#                              distribution's lavapipe instead (vulkan-swrast), which mtlvk uses when it is there.
# Needs curl, tar, xz, meson 1.4 or newer, ninja, a C / C++ compiler, bison, flex, pkg-config, glslangValidator,
# python3 with mako, yaml and packaging, patchelf, and the headers of zlib, zstd and libdrm.
# The one source change: lavapipe offers VK_KHR_swapchain only when a window system is built in; here it is always on
# (Mesa's headless surfaces are always built), because metal2vulkan's runtime asks for the extension.
# The result: dest/libvulkan_lvp.so, dest/lvp_icd.json, dest/libdrm.so.2, dest/libvulkan.so.1 (the Vulkan loader of
# the build machine, for a computer that has none), dest/LICENSE, dest/VERSION.
set -e
X=$(cd "$(dirname "$0")/.." && pwd)
MESA_VER=${MESA_VER:-26.2.5}
MESA_SHA=${MESA_SHA:-794b3d1729075dae7ebd47c7283b7ca0cdb5dec668f7f11cc0a5d82f6138a0a5}
MESA_URL=https://archive.mesa3d.org/mesa-$MESA_VER.tar.xz
DEST=${1:-$X/linux/mtlvk/target/lavapipe}
DL=${LAVAPIPE_DL:-$(dirname "$DEST")/lavapipe-build}
if [ -z "$LLVM_CONFIG" ]; then
	for c in llvm-config-20 llvm-config; do command -v $c >/dev/null && { LLVM_CONFIG=$c; break; }; done
fi
for t in curl tar xz meson ninja cc c++ bison flex pkg-config glslangValidator python3 patchelf "${LLVM_CONFIG:-llvm-config}"; do
	command -v "$t" >/dev/null || { echo "lavapipe: $t is needed (see the top of build/lavapipe.sh)" >&2; exit 1; }
done
LLVM_VER=$("$LLVM_CONFIG" --version)
WANT="mesa $MESA_VER, llvm $LLVM_VER"
if [ -f "$DEST/VERSION" ] && [ "$(cat "$DEST/VERSION")" = "$WANT" ] && [ -f "$DEST/libvulkan_lvp.so" ]; then
	echo "  lavapipe $WANT (already there: $DEST)"
	exit 0
fi
"$LLVM_CONFIG" --link-static --libs core >/dev/null 2>&1 || {
	echo "lavapipe: $LLVM_CONFIG ($LLVM_VER) has no static libraries (see LLVM_CONFIG at the top of build/lavapipe.sh)" >&2
	exit 1
}
mkdir -p "$DL"
SRC=$DL/mesa-$MESA_VER.tar.xz
if [ ! -s "$SRC" ]; then curl -fsSL --retry 3 -o "$SRC.part" "$MESA_URL" && mv "$SRC.part" "$SRC"; fi
h=$(sha256sum "$SRC" | cut -d' ' -f1)
[ "$h" = "$MESA_SHA" ] || { echo "lavapipe: $SRC: sha256 $h, expected $MESA_SHA" >&2; exit 1; }
rm -rf "$DL/mesa-$MESA_VER" "$DL/build" "$DL/inst"
tar -xJf "$SRC" -C "$DL"
M=$DL/mesa-$MESA_VER
# VK_KHR_swapchain without a window system (see above): the #if around the define goes
F=$M/src/gallium/frontends/lavapipe/lvp_device.c
python3 - "$F" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
n = re.subn(r'#if defined\(VK_USE_PLATFORM_WAYLAND_KHR\)(?:[^\n]*\\\n)*[^\n]*\n#define LVP_USE_WSI_PLATFORM\n#endif\n',
            '/* x86Sim: no window system is built in; the swapchain extension stays, on headless surfaces */\n'
            '#define LVP_USE_WSI_PLATFORM\n', s)
if n[1] != 1:
    sys.exit('lavapipe: lvp_device.c: the LVP_USE_WSI_PLATFORM condition is not where Mesa %s has it' % p)
open(p, 'w').write(n[0])
EOF
printf "[binaries]\nllvm-config = '%s'\n" "$(command -v "$LLVM_CONFIG")" > "$DL/native.ini"
meson setup "$DL/build" "$M" --buildtype=release --prefix="$DL/inst" --libdir=lib --native-file "$DL/native.ini" \
	-Dgallium-drivers=llvmpipe -Dvulkan-drivers=swrast -Dplatforms= -Dglx=disabled -Degl=disabled -Dgbm=disabled \
	-Dopengl=false -Dgles1=disabled -Dgles2=disabled -Dllvm=enabled -Dshared-llvm=disabled -Dxmlconfig=disabled \
	-Dvalgrind=disabled -Dlibunwind=disabled -Dlmsensors=disabled -Dzstd=enabled -Dvideo-codecs= -Dgallium-va=disabled \
	-Dbuild-tests=false -Dvulkan-layers= -Dtools= -Dshader-cache=enabled \
	-Dcpp_link_args='-static-libstdc++ -static-libgcc' -Dc_link_args=-static-libgcc > "$DL/meson.log" 2>&1 \
	|| { tail -30 "$DL/meson.log" >&2; exit 1; }
ninja -C "$DL/build" install > "$DL/ninja.log" 2>&1 || { tail -40 "$DL/ninja.log" >&2; exit 1; }
T=$DEST.tmp$$
rm -rf "$T"
mkdir -p "$T"
strip --strip-unneeded -o "$T/libvulkan_lvp.so" "$DL/inst/lib/libvulkan_lvp.so"
# the libraries it needs that a computer without graphics may lack: libdrm, and the Vulkan loader for mtlvk itself
syslib() { ldconfig -p 2>/dev/null | awk -v n="$1" '$1 == n && /x86-64/ { print $NF; exit }'; }
for l in libdrm.so.2 libvulkan.so.1; do
	p=$(syslib $l)
	[ -n "$p" ] && [ -f "$p" ] || { echo "lavapipe: $l is not on this machine (libdrm2, libvulkan1 / vulkan-icd-loader)" >&2; exit 1; }
	cp -L "$p" "$T/$l"
done
patchelf --set-rpath '$ORIGIN' "$T/libvulkan_lvp.so"
API=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["ICD"]["api_version"])' "$DL"/inst/share/vulkan/icd.d/lvp_icd*.json)
cat > "$T/lvp_icd.json" <<EOF
{
    "ICD": {
        "api_version": "$API",
        "library_arch": "64",
        "library_path": "./libvulkan_lvp.so"
    },
    "file_format_version": "1.0.1"
}
EOF
{
	echo "lavapipe (libvulkan_lvp.so): Mesa $MESA_VER, https://mesa3d.org, built by build/lavapipe.sh with LLVM $LLVM_VER"
	echo "linked in. Mesa is under the MIT license and the licenses below; LLVM under the Apache License v2.0 with LLVM"
	echo "Exceptions (https://llvm.org/LICENSE.txt). libdrm.so.2: libdrm, MIT. libvulkan.so.1: the Khronos Vulkan loader,"
	echo "Apache License v2.0."
	echo
	echo "==== Mesa: docs/license.rst"
	cat "$M/docs/license.rst"
	echo
	echo "==== Mesa: licenses/MIT"
	cat "$M/licenses/MIT"
	for d in "llvm-${LLVM_VER%%.*}-dev" libdrm2 libvulkan1; do
		[ -f "/usr/share/doc/$d/copyright" ] && { echo; echo "==== $d: /usr/share/doc/$d/copyright"; cat "/usr/share/doc/$d/copyright"; }
	done
	true
} > "$T/LICENSE"
echo "$WANT" > "$T/VERSION"
rm -rf "$DEST"
mv "$T" "$DEST"
echo "  lavapipe $WANT: $(du -sh "$DEST" | cut -f1) in $DEST"
