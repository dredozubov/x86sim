# x86Sim releases: one AppImage, set up by the launcher

Goal: download one file, run it, and get a booted phone with as little work as possible. GitHub CI builds it.
Full releases are tagged `v<version>` (first: `v0.1.0`, 2026-11-11; this document describes `v0.7.2`); pre-releases
`v<version>-pre<N>`. The repository and its releases are public (`x86sim/x86sim`).

What a release is: one AppImage built by `.github/workflows/release.yml` from a tag, with its `.zsync` and
`SHA256SUMS`. It carries Darling, the translator, mtlvk, the launcher and its command-line tools, and our
simulator-side binaries; nothing from Apple. The launcher's Setup page (or `x86sim.AppImage aot setup ...`) checks the
computer, makes Darling usable (no root in userns or nonroot mode, one password prompt in system mode), downloads the
runtime from Apple, pre-translates it and creates the first device.

## 1. What a fresh machine needs (developer setup)

| Step | What | Root? | Machine-specific? |
|---|---|---|---|
| Packages | clang/LLVM (recent: our Darling fork builds with clang 23; `-fno-objc-constant-literals`), cmake, ninja, bison, flex, FUSE, libcap, Darling's `-dev` list, boost headers, Rust stable, Python 3 (+dnspython), curl, openssl | yes (package manager) | distro names differ |
| Darling | `make darling-install`: ~26k ninja targets, installed to `darling-prefix/`, then `bin/darling` chowned root + setuid (`tools/debug/dinstall.sh`) | **yes**: setuid root | the install prefix is **compiled into** the binaries (`darling` execs `$PREFIX/bin/darlingserver`, darlingserver overlays `$PREFIX/libexec/darling`, mldr loads `$PREFIX/libexec/usr/lib/dyld`) |
| arm64jit | `linux/arm64jit/install.sh`: libarm64jit.so, a64hugecopy and host/arm64host (built with Darling's in-tree ld64 and Darling's own SDK) copied into the prefix | no | no |
| mtlvk | `make mtlvk` (Rust, Vulkan through the loader) | no | needs the user's Vulkan driver at run time |
| Launcher | `cargo build --release` in tools/launcher (x86sim-launcher, x86sim-aot, x86sim-mcp, x86sim-ax, x86sim-dev, x86sim-serve, x86sim-pool, x86sim-account, x86sim-devapp) | no | no |
| iOS runtime | `runtime-fetch.py fetch 24B8117`: Apple catalogue + gdmf, 8 GB download (curl, resumable), `ipsw fw aea` decrypt, aaextract.py, `7z x -snld`, symlink repair (extract-runtime.py). ~45 GB free during, ~27 GB after | no | Apple content: per machine, never redistributed |
| Maps seed | boot-a64.sh writes `runtimes/geo-seed` (geod's seed manifest; geod downloads Apple's resources itself) | no | nothing to ship |
| AOT image | x86sim-aot / Pre-translate page: built from the runtime, keyed by the translator's codegen version (read from libarm64jit.so's `g_build`, core/src/key.rs) | no | derived from Apple's code: local only |
| First phone | `device-a64.py create` / launcher "Add phone"; a fresh phone's first boot can stall once (the launcher restarts it automatically) | no | |
| Kernel | overlayfs (Darling's container), 6.11+ for PROCMAP_QUERY (faster darlingserver; older kernels fall back), no binfmt, no kernel module, no ptrace needs for normal use | - | |
| GPU | Vulkan driver (NVIDIA proprietary, Mesa RADV/ANV) + loader; without one, software rendering. AMD (RADV): read-write access to `/dev/udmabuf`, else buffers are copied ([METAL.md](METAL.md)) | - | yes |

## 2. What goes where

**Inside the AppImage** (zstd squashfs; `appimage.sh` prints its size; nothing from Apple):

```
AppRun                         entry (build/release/AppRun)
usr/share/x86sim/
  VERSION, DARLING_ID          version; content hash of the Darling tree (a new AppImage reinstalls Darling only if it changed)
  payload/                     `git ls-files` of cli host linux tools/debug tools/runtime tests (and docs/RELEASE.md,
                               README.md, LICENSE) + build outputs at their repo paths (linux/mtlvk/target/release/mtlvk,
                               tools/launcher/target/release/x86sim-{launcher,aot,mcp,ax,dev,serve,pool,devapp}) +
                               external/omarchy-apple-dev's install-toolchain.sh, ship.sh, ship-mac.sh, device-run.sh,
                               tools/, sdk-free/, flutter/, kmp/, patches/, compat/ (no receipts, docs, tests or demos)
  darling/                     Darling installed with prefix /opt/x86sim/darling (DESTDIR), + libarm64jit.so,
                               a64hugecopy, arm64host
  bin/ipsw (MIT), bin/7zz + 7z (7-Zip, LGPL-2.1 + unRAR), bin/rcodesign (MPL-2.0: re-signs converted .ipa / device
                               builds), pylib/dns (dnspython, ISC)
  payload/linux/mtlvk/target/lavapipe/
                               lavapipe for a device's GPU setting "cpu" (build/lavapipe.sh: Mesa 26.2.5 from source,
                               sha256 pinned, LLVM 20 linked in; MIT + Apache-2.0 with LLVM exceptions, its LICENSE),
                               with libdrm.so.2 and the Vulkan loader beside it. About 76 MiB unpacked, 18 MiB of the
                               AppImage ([METAL.md](METAL.md#gpu-selection))
  webinspector/                WebKit's Web Inspector frontend for `x86sim inspect` (build/webinspector.sh: the
                               WebInspectorUI files of Arch's webkit2gtk-4.1 2.54.3-1 package, sha256 pinned; BSD-2 + MIT,
                               its LICENSE); AppRun copies it to <app>/webinspector. 227 files, 6.3 MiB unpacked,
                               about 1.2 MiB of the AppImage
  install-helper.sh            the privileged step (system mode)
  darling-userns.sh            the no-root Darling wrapper (userns mode)
  darling-nonroot.sh           the no-root, no-namespace Darling wrapper (nonroot mode)
  licenses/                    Darling (GPL-3 / APSL parts), dynarmic (0BSD), metal2vulkan (GPL-2+/LGPL-3+), astcenc (Apache-2),
                               lzfse (BSD-3), omarchy-apple-dev (MIT), webinspector (BSD-2 + MIT); NOTICE lists them all
```

The committed simulator-side binaries in `host/` (simfb, simhid, simshim, simax, simnet, simaudio, metalhostd,
iosurfaced, openurl and the others; iOS, tvOS, watchOS and visionOS builds) are **ours**, built on Linux from `host/`
sources by `build/mac-build-*.sh` (clang, ld64.lld and the SDKs in `sdks/`; the scripts keep their names from when
they ran on a Mac, see [LINUX-BUILD.md](LINUX-BUILD.md)). They link against Apple's SDK stubs but contain no Apple
code. The release build does not rebuild them: it packs the committed files, so CI holds no Apple SDK. `appimage.sh`
refuses to pack if it finds a dyld shared cache, a `.simruntime`, an SDK, GeoServicesData, a RuntimeRoot or a
CoreSimulator Profiles tree.

Up to v0.7.2 the AppImage lacked the `x86sim-account` binary (`x86sim account` on the command line; the launcher's
Settings > Apple Account has the same sign-in built in) and omarchy-apple-dev's `swiftbuild/`, `linux-bin/`,
`cocoapods/`, `carthage/`, `xcodegen/`, `tuist/`, `rust/`, `dotnet/`, `shells/` and `fastlane/` directories, which
`x86sim dev` needs for Xcode projects, CocoaPods (React Native, Expo), Rust, .NET and the app shells
([BUILDING-APPS.md](BUILDING-APPS.md)). `appimage.sh` packs them from the release after v0.7.2 on; on an older AppImage,
`X86SIM_OAD=<dir>` points `x86sim dev` at a full checkout of the fork.

**Fetched or built on the user's machine, never shipped:** the iOS runtime (straight from Apple's CDN with the same
request Xcode makes; each user downloads their own copy), the Metal binary extracted from it (ensure-metal-framework.sh),
AOT images and JIT caches (derived from Apple's code), XCTest's frameworks, the device SDK and the iPhone Duo's 3D model
(from the user's own Xcode.xip: `x86sim account download-xcode`, `x86sim dev setup sdk --xip`), the Metal toolchain
(`build/metal-toolchain.py`, only for compiling shaders from source), the OCR models (`~/.cache/x86sim/ocr`). Maps
needs nothing shipped: boot-a64.sh writes geod's seed manifest and geod downloads Apple's resources.

**On disk after setup** (the AppImage mount is read-only and lives only while the AppImage runs, but phones outlive the
launcher, so AppRun copies the payload out once per version):

```
~/.local/share/x86sim/        X86SIM_ROOT, shaped like the checkout so every script and the launcher work unchanged
  app/<version>/               payload copy (+ darling/ in userns / nonroot mode); the newest two versions are kept
  cli host linux tools tests   -> app/<version>/...      (relative links: Darling resolves them under /Volumes/SystemRoot)
  darling-prefix               -> /opt/x86sim/darling (system mode) or app/<version>/darling-userns|darling-nonroot
  runtimes/ var/ setup.json    user data, kept across versions
  devicemodels/                the iPhone Duo's 3D model, when the user's Xcode.xip gave it
~/.cache/x86sim/              X86SIM_SCRATCH: per-phone Darling prefixes, jc-<build> (AOT + JIT cache), logs
/opt/x86sim/                  system mode only: darling-<id>/ (root-owned, bin/darling setuid), darling -> darling-<id>
```

AppRun sets `X86SIM_ROOT`, `X86SIM_SCRATCH`, `PATH` (bundled ipsw/7z), `X86SIM_PYLIB`, `A64_PREFIX_HEAL=0` (no
Darling build tree to heal from). Subcommands: `x86sim.AppImage
[launcher|aot|mcp|dev|serve|x86sim|shell|install-desktop|uninstall-desktop|version]`; every other command-line tool is
reached through `x86sim.AppImage x86sim <command>`.
In the checkout nothing changes: `repo_root()` is still the repo, `setup::needed()` is false, the Setup page only checks.

## 3. Root: three modes

Darling's `bin/darling` must be setuid root and its prefix is fixed; an AppImage can carry neither.

- **userns (no root, default when available).** `darling-userns.sh` keeps one "holder" process per Darling build that
  owns an unprivileged user namespace + mount namespace with the Darling tree bind-mounted at `/opt/x86sim/darling`;
  every `darling` command joins it with `nsenter --preserve-credentials -U -m`. Inside, the user is uid 0 and Darling
  starts as usual (overlay mounts are allowed in a user namespace since Linux 5.11). Tested: a phone (iPhone 17,
  iOS 27.2) booted to the home screen, GPU rendering, from a fresh data dir (first boot stalled once as usual, the
  second reached home). Differences seen so far: launchd's domain is `user/0` instead of `user/<uid>`; darlingserver
  can't raise its FD limit above the hard limit or renice itself to -10 (warnings). Inside the namespace `/opt` shows
  only `x86sim/` (the host's other `/opt` entries are hidden from Darling, not from Linux).
  **Not available** where unprivileged user namespaces are blocked: Ubuntu 23.10+ (AppArmor
  `kernel.apparmor_restrict_unprivileged_userns=1`), hardened kernels, some containers. AppRun probes what the mode
  needs: `unshare -r -m true`, `/opt` to bind onto (NixOS has none, #35) and `unshare -r -m -p -f --mount-proc true` (a
  container that masks parts of `/proc`, e.g. podman, refuses darlingserver's procfs mount: #13). Setup's Darling row
  names the one that failed (setup.rs `userns_blocker`).
- **system (one password prompt).** The wizard copies `usr/share/x86sim/darling` out of the mount (root can't read a
  user's FUSE mount) to the cache, then `pkexec sh install-helper.sh install <dir> <id>`: copy to
  `/opt/x86sim/darling-<id>`, `chown -R root:root`, `chmod 4755 bin/darling`, atomically switch the
  `/opt/x86sim/darling` link (running phones keep their tree), keep the previous tree. `install-helper.sh uninstall`
  removes `/opt/x86sim`. Without pkexec the page shows the `sudo` command. Used automatically when that exact Darling
  build is already installed there; force one with `X86SIM_DARLING_MODE=system|userns|nonroot`.
- **nonroot (no root, no namespaces).** `darling-nonroot.sh` runs the AppImage's Darling tree with
  `DARLING_NONROOT=1`: the launcher takes its install prefix from its own path, each phone's prefix is a copy of the
  system image (~690 MB, updated in place at later starts) instead of an overlay, and the container shares the host's
  process table. AppRun picks it when user namespaces are blocked inside a container (`/run/.containerenv`,
  `/.dockerenv`). Tested 2026-11-24: an iPhone 17 Pro (iOS 27.2) booted to the home screen and ran Settings (touches
  work) in a bwrap sandbox standing in for a container: no user namespaces, a PID namespace of its own, the prefix on
  overlayfs. Not tested on a bare host, where guests get the host's pids (above XNU's 99999; `ps` refuses them).

Prefix filesystem: the kernel's overlayfs cannot take its upper layer on another overlay (a container's root file
system) or a network file system and refuses with EINVAL. Darling's launcher then goes on by itself when nobody can
be asked (no terminal, as for every phone): fuse-overlayfs if the tool and `/dev/fuse` are there, else the copy, and
records the choice in the prefix's `.darling-fsmode`.

Note: the staged copy and the helper script live in the user's own dirs, so whoever runs as the user could tamper
with them between copy and `pkexec`; the password prompt is the user's own, so this gives nothing beyond what the user
already has. A stricter variant would have the helper read the AppImage file itself (`$APPIMAGE --appimage-extract`
as root) and check `DARLING_ID`.

## 4. First run (the launcher's Setup page)

From the AppImage the launcher opens on **Setup** until it was finished once (or while Darling / iOS are missing);
it stays in the sidebar afterwards. The same steps from a terminal: `x86sim.AppImage aot setup check|install-darling|link-runtime DIR|done`.

1. **This computer**: CPU (x86-64 with SSE4.1/POPCNT/CX16), kernel (overlayfs; 6.11+ noted), memory (16 GB
   recommended, 8 minimum), disk (45 GB free for a download, 10 GB with a runtime), Vulkan (loader, a driver JSON,
   a GPU node; else a warning: software rendering), GPU buffers on AMD (`/dev/udmabuf` readable and writable; else a
   warning: buffers are copied), programs (python3, curl, openssl, setsid, ip, ipsw, 7z), shared libraries,
   dnspython, resource limits (a systemd user manager; else a warning: phones run uncapped).
2. **Darling**: ready (userns) or Install/Update (system, one password).
3. **Get iOS**: Download iOS 27.2 (the existing fetch with progress, Cancel, Resume — curl `-C -`, tested), or
   "use this folder" to link a runtime already on disk (a checkout's `runtimes/ios-27.2-24B8117-arm64`; relative link).
4. **Pre-translate**: starts by itself as soon as iOS and Darling are ready. Afterwards the launcher keeps every
   installed version's image up to date on its own (at start, after a device stops, when versions change, every
   30 min), niced and while devices run; stopping a run pauses it until the next launcher start
   (`X86SIM_NO_AUTO_AOT=1`: no automatic pass).
5. **First phone**: the Add phone dialog; then Done.

## 5. Updates and versioning

- The AppImage carries update information `gh-releases-zsync|x86sim|x86sim|latest-pre|x86sim-*-x86_64.AppImage.zsync`
  and CI publishes the `.zsync`, so AppImageUpdate / AppImageLauncher can delta-update. The launcher also updates
  itself (`tools/launcher/core/src/update.rs`): the newest GitHub release, checked against its `SHA256SUMS` and
  swapped in; the channel is `stable` (full releases) or `pre` (pre-releases too), by default that of the running
  version.
- A new version gets its own `app/<version>` copy; user data (`runtimes/`, `var/`, caches) is untouched. Darling is
  reinstalled (system mode: one prompt) only when `DARLING_ID` changes.
- AOT images are already invalidated by the translator's codegen version (key.rs reads it from the installed
  libarm64jit.so; `strip --strip-debug` keeps the symbol). Data-format migrations, when needed, go in AppRun keyed on
  `setup.json`'s `done_version`.

## 6. Build and CI

- `build/release/deps-ubuntu.sh`: packages on Ubuntu 24.04 + clang 23 from apt.llvm.org (+ `/usr/include/asm` link:
  Darling's fseventsd includes `<linux/types.h>` without Debian's multiarch dir).
- `build/release/build.sh`: Darling (prefix `/opt/x86sim/darling`, `DESTDIR`), arm64jit, arm64host, mtlvk, launcher,
  lavapipe; reads the checkout only, writes `build/release/out` (gitignored). `CCACHE=1` uses ccache (hits only when the checkout
  and OUT paths are the same as the cached build's: Darling's compile lines carry both). Reproducible Darling:
  `ZERO_AR_DATE=1` (ld64's N_OSO object timestamps) and `SOURCE_DATE_EPOCH` = Darling's commit time (`__DATE__`), so
  the same Darling source gives the same `DARLING_ID` and an update reinstalls Darling only when it changed.
- `build/release/appimage.sh`: payload, Darling tree, pinned tools (ipsw, 7-Zip, rcodesign, dnspython; sha256
  checked), the Web Inspector frontend
  (`build/webinspector.sh`: needs `zstd` and glib's `gresource`, in deps-ubuntu.sh), licenses, Apple-content check,
  appimagetool (continuous; prints its hash) → `x86sim-<version>-x86_64.AppImage` + `.zsync` + `SHA256SUMS`.
- `build/release/docker-build.sh`: the same in an `ubuntu:24.04` container with the checkout mounted read-only (local
  check of the CI build).
- `.github/workflows/build.yml` (reusable): builds only what changed. `build/release/ci.sh keys` gives each component
  (Darling + arm64host, arm64jit, mtlvk, launcher, lavapipe) a cache key from the git objects of its inputs (its dirs, its
  submodule's commit, the build scripts, files it compiles in); a component whose key is cached is restored
  (`ci.sh stage`; Darling's setuid/sticky modes are reapplied, the cache's tar drops them), the others are built and
  cached (`ci.sh collect`, which also keeps their submodules' licenses for appimage.sh). Free disk, the submodule
  checkout (shallow, SSH URLs rewritten to HTTPS), the toolchain, ccache and cargo caches run only for what is built;
  a run that only packs installs `deps-ubuntu.sh --pack`. A component that starts reading a new file outside its
  inputs must be added in `ci.sh` (else a change there reuses a stale build); `KV` there drops every component cache.
  The run summary lists built / cached. `ci.yml`: every push to main / PR, docs-only changes skipped; packs the
  AppImage (zstd 9) on main and manual runs, on a PR only with the `appimage` label (adding it starts a run); a manual
  run (`gh workflow run ci --ref <branch> [-f appimage=false] [-f fresh=true]`) can skip packing or rebuild everything.
  `release.yml`: tag `v<version>` → GitHub release (marked latest), `v<version>-pre<N>` → pre-release (or a manual
  run naming a tag); each with AppImage, zsync, SHA256SUMS.

Build times, measured locally in November 2026 (Ryzen 7 9800X3D, `-j8`, a phone running alongside): Darling 26k targets
≈ 8.5 min wall, 50 CPU-min summed over jobs; arm64jit + arm64host < 1 min; mtlvk ≈ 1.5 min; launcher < 30 s; packing ≈ 1
min. 2026-11-24 (same host, `JOBS=6`, nice, other agents' phones running; 28.8k targets): cold 21.5 min (build.sh 1212 s
+ appimage.sh 78 s); warm ccache (same paths) + sccache 3.3 min (build.sh 126 s: Darling 74 s; appimage.sh 71 s).
Estimate on a 4-vCPU GitHub runner: 30–60 min cold, much less with ccache — well inside the 6 h limit. Disk: Darling
build tree 1.7 GB, destdir 0.55 GB, cargo targets 2.2 GB, shallow submodules a few GB: fits the ~14 GB free (+~25 GB
after the cleanup step).

Found and fixed for the Ubuntu toolchain: darlingserver used `PROCMAP_QUERY` from Linux 6.11 headers (Ubuntu 24.04
has 6.8): the definitions are now provided when missing (stable ABI; old kernels answer ENOTTY and the maps parser runs).

**glibc floor:** built on 24.04: glibc 2.38/2.39 symbols, libstdc++ GLIBCXX_3.4.30. Runs on Ubuntu 24.04+, Debian 13,
Fedora 39+, Arch/derivatives; not Ubuntu 22.04 / Debian 12. The simulator-side binaries are Mach-O and don't care.

## 7. Licensing of what is bundled

Darling: GPL-3.0 with APSL-2.0 / BSD parts (Apple's open-source releases) — source is our public fork; the release
notes should point at the exact submodule commits (GPL offer). dynarmic 0BSD, metal2vulkan GPL-2.0+/LGPL-3.0+ (dual),
astc-encoder Apache-2.0, lzfse BSD-3, ipsw MIT, 7-Zip LGPL-2.1 + unRAR restriction (redistribution fine), dnspython ISC,
Web Inspector frontend BSD-2 (WebKit's WebInspectorUI; bundled CodeMirror MIT, Esprima BSD-2, three.js MIT, CSS
documentation MIT: licenses/webinspector-LICENSE). Only the frontend's files ship, none of WebKitGTK's LGPL libraries.
Our own code: GPL-3.0-or-later (LICENSE); bundled components and their licenses in NOTICE.

## 8. How releases are set up

- **Repository**: `x86sim/x86sim` is public, so the releases, their `.zsync` files and the forks CI clones over HTTPS
  are readable by everyone.
- **License**: GPL-3.0-or-later for our own code (LICENSE), components listed in NOTICE; both ship in the AppImage.
- **Root**: userns (no root) by default, nonroot inside a container without user namespaces, the `pkexec` system
  install otherwise (§3).
- **Distro floor**: Ubuntu 24.04+ (glibc 2.39): also Debian 13, Fedora 39+, Arch.
- **Pre-translate**: automatic (§4).
- **Tags**: `v<version>` is a full release, marked latest; `v<version>-pre<N>` a pre-release. Releases are immutable:
  `release.yml` uploads the assets to a draft and then publishes it.
- **Pushing**: innermost first (darlingserver, darling, then this repo), see [REPOS.md](REPOS.md).
