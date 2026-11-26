# Developing x86Sim

Building from source, the repository layout and day-to-day use from the command line. For the
design, see [ARCHITECTURE.md](ARCHITECTURE.md), which also has the map of all documents; for using a built x86Sim,
[USAGE.md](USAGE.md).

## Requirements

- **Linux x86-64** with a recent kernel. Darling needs its usual setup: FUSE/overlayfs and a setuid-root `darling`
  binary (a source build; the AppImage also runs without root, [RELEASE.md](RELEASE.md)).
- **A Vulkan GPU**: NVIDIA (proprietary driver) or AMD (RADV), with `VK_EXT_external_memory_host`. On AMD also
  read-write access to `/dev/udmabuf` (the `udmabuf` module; RADV refuses host-pointer imports of Darling's memory,
  and without udmabuf every buffer is mirrored; [METAL.md](METAL.md#how-buffers-reach-the-gpu)). Development used an
  NVIDIA RTX 5090 and an AMD integrated GPU. Without a usable GPU, a device's GPU setting `cpu` renders on lavapipe and
  `X86SIM_METAL=0` falls back to CoreAnimation's software rendering (not for visionOS, which needs Metal).
- **Darling's build dependencies**: clang/LLVM, cmake, ninja, bison, flex, FUSE, libcap, Python 3, and the rest of
  Darling's [build list](https://docs.darlinghq.org/build-instructions.html); dynarmic also needs boost headers.
- **Rust** (stable, via rustup) for `linux/mtlvk` and metal2vulkan.
- **Python 3** with `PIL` (Pillow) and `dnspython`. The GTK viewer (`x86sim view`) needs PyGObject with GTK 4,
  `x86sim io recordVideo` needs `ffmpeg`, and `x86sim dismiss` needs `tesseract`.
- **Apple's simulator runtimes**, not included: `runtime-fetch.py` downloads them straight from Apple's catalogue
  (no Mac, no Apple ID). It needs [`ipsw`](https://github.com/blacktop/ipsw) and 7-Zip.
- **No Mac.** Everything builds on Linux (AGENTS.md, [LINUX-BUILD.md](LINUX-BUILD.md)). The simulator-side binaries in
  `host/` and `tests/` are committed, and rebuilding them works here: `make sdks` sets up the SDKs without an Apple ID
  (see *Simulator-side binaries*), and Metal shaders compile with Apple's Metal toolchain, a public download, run
  under Darling. Only XCTest's frameworks and the Swift / UIKit parts need files from Xcode.xip (a free Apple ID),
  which is unpacked on Linux. A Mac (`$X86SIM_MAC`) is used only to compare results with Apple's simulator.

## Layout

```
cli/        x86sim front end; cli/libexec: the scripts it wraps (cli/libexec/arm64: boot, runtime fetch, placement,
            prefetch, shipped training); cli/lib: configuration and device types
host/       simulator-side code (Mach-O, run inside Darling): simhost (x86_64), arm64host, and arm64 builds under
            host/<name>/arm64 (iOS), arm64-tvos, arm64-watchos, arm64-xros of simfb, simhid, simaudio, simax (the
            accessibility reader), simnet (network capture), iosurfaced, metalhostd (+ vkmtl), fpsim2host, fseventsd,
            netconfig, nisimhost, openurl, mmhost, simshim/{compat,diag}
linux/      native Linux pieces: arm64jit (the JIT host library), mtlvk (Rust, Metal on Vulkan), mdnsd, hostnet,
            fmrelay (FoundationModels relay to a Mac)
tests/      sample apps and sdkcov (tests/apps), arm64 JIT tests (tests/arm64), Metal (tests/metal: mtlprobe +
            shaders), end-to-end checks through MCP (tests/ax, tests/dev, tests/mcp, tests/share, tests/account),
            tests/lldb, tests/profile, tests/web/webcov, perf.py
tools/      launcher/: the launcher GUI and the Rust command-line tools (x86sim-aot, -mcp, -ax, -dev, -serve, -pool,
            -account, -devapp); debug/: core dumps, stacks, stuck processes, Darling install (dinstall.sh);
            runtime/extract-runtime.py: Apple's runtime image -> RuntimeRoot on Linux; devicetypes/, devicemodels/:
            device types and the iPhone Duo's 3D model out of Xcode.xip
build/      build scripts for the host/ and tests/ binaries, run on Linux (mac-build-*.sh keep their names;
            linux-env.sh, linux-swiftc.sh, linux-metal.sh, linux-bin/); sdk/: the SDKs; release/: the AppImage
docs/       ARCHITECTURE (with the map of all documents), protocols/, screens/
skills/     x86sim/SKILL.md: the skill file for coding agents
external/   git submodules: darling, dynarmic, metal2vulkan and omarchy-apple-dev (x86sim branches of the x86sim
            forks)
```

## Setup

Pre-built: the AppImage from the GitHub releases sets itself up (host checks, Darling, iOS download, first
phone) from the launcher's Setup page; see [docs/RELEASE.md](RELEASE.md). From source:

1. **Clone with submodules.**
   ```sh
   git clone --recursive https://github.com/x86sim/x86sim.git && cd x86sim
   cp x86sim.env.example x86sim.env      # then edit if needed: paths, GPU settings
   ```
2. **Get the iOS 27.2 runtime** straight from Apple (about 8 GB download, ~23 GB unpacked):
   ```sh
   cli/libexec/arm64/runtime-fetch.py list            # iOS 27.x runtimes in Apple's catalogue
   cli/libexec/arm64/runtime-fetch.py fetch 24B8117   # iOS 27.2 -> runtimes/ios-27.2-24B8117-arm64/
   echo ios-27.2-24B8117-arm64 > var/device-a64/runtime
   ```
   It decrypts Apple's archive (`ipsw`), unpacks the APFS image (`7z`), and remakes every symlink 7-Zip gets wrong
   (`tools/runtime/extract-runtime.py --links`, then `--check`).
   Apple TV, Apple Watch and Vision Pro: `runtime-fetch.py list all`, then e.g. `fetch 24K150` (tvOS 27.2, about
   4 GB), `fetch 24S118` (watchOS 27.2) or `fetch 24N120` (visionOS 27.2) into `runtimes/tvos-...` /
   `runtimes/watchos-...` / `runtimes/xros-...`, and
   `x86sim device create --model "Apple TV 4K (3rd generation) (at 1080p)" tv` or `--model "Apple Watch Series 11 (46mm)"
   watch` (the newest runtime of the model's platform). Boot one with `A64_DEVICE=var/device-a64-tv` as usual.
3. **Build and install Darling** (bin/darling must be setuid root, so this asks for sudo):
   ```sh
   make darling-install                  # configures external/darling -> $X86SIM_PREFIX, builds, installs
   ```
4. **Build the Linux pieces:**
   ```sh
   make mtlvk                            # Metal on Vulkan
   linux/arm64jit/install.sh             # the arm64 JIT, installed into Darling
   (cd tools/launcher && cargo build --release)   # x86sim-launcher, x86sim-aot, x86sim-mcp and the other tools
   ```
5. **Pre-translate** (optional, much faster boots and app opens):
   `tools/launcher/target/release/x86sim-aot --device $PWD/var/device-a64 build --full`, or the launcher's
   Pre-translate page.
6. **Boot:** from the launcher, or `A64_KEEP=1 cli/libexec/arm64/boot-a64.sh` (see *Usage*). A boot without the
   pre-translated image works too: cold code starts in the translator's interpreter tier
   ([ARCHITECTURE.md](ARCHITECTURE.md#arm64-code-arm64host-and-libarm64jit)).

Commands that need root (installing Darling, killing the setuid `darling` launcher, cores) read the password from
`SUDO_PASS` in the environment or use sudo's prompt or cache. The password is never stored in a file.

## Usage

Phones are started from the launcher, with `x86sim-aot --device NAME sim start|stop|restart`, or by hand with
`cli/libexec/arm64/boot-a64.sh` (`A64_DEVICE=<dir>` for another device, `A64_KEEP=1` to keep it running,
`A64_STOP_ONLY=1` to stop it). [USAGE.md](USAGE.md) and [AGENT-TOOLS.md](AGENT-TOOLS.md) describe the commands; the
ones used most while developing, with a phone running:

```sh
x86sim view [--bg]              # GTK window: mouse = touch, keyboard input
x86sim wait home                # wait for the home screen on the framebuffer
x86sim tap X Y                  # device pixels; also: swipe, pinch, pan2, key, type "text", home, lock
x86sim openurl https://example.com
x86sim app com.apple.Preferences
x86sim install MyApp.app        # an iOS-simulator build (arm64), as xcrun simctl install: icon on the home screen
x86sim launch com.example.myapp -arg value   # as simctl launch; also: x86sim uninstall com.example.myapp
x86sim launch --console --terminate-running-process com.example.myapp   # stdout/stderr here (--console-pty: a pty)
x86sim location set 48.8584,2.2945                 # simulated location; `location start|list|run|clear`
x86sim terminate com.example.myapp
x86sim get_app_container com.example.myapp data   # app | data | groups | <group id> (Linux paths)
x86sim listapps [--json]
x86sim push com.example.myapp payload.json   # simulated remote notification
x86sim addmedia photo.jpg clip.mov           # into the Photos library
x86sim log stream --app com.example.myapp    # the app's os_log (relaunched; --match TEXT filters)
x86sim io recordVideo --secs 10 out.mp4      # also: x86sim io screenshot out.png
x86sim screenshot shot.png 3    # newest frame, scaled down 3x
x86sim logs [label] | fps 10
x86sim device models|list|create --model "iPhone 17 Pro" [name]
tests/perf.py all               # short performance run (idle CPU, launch times, frame times, touch latency)
```

Useful environment variables: `X86SIM_METAL=all|backboardd|0` (GPU for every process, the default / backboardd only /
software rendering), `MTLVK_DEVICE_ID=auto|cpu|<id>` (the GPU, [METAL.md](METAL.md#gpu-selection)),
`X86SIM_A64_INTERP=N` (the interpreter tier's threshold, 0 = off), `X86SIM_A64_JITCACHE=0` / `X86SIM_A64_AOT=0` (no
translation cache / no image), `A64_JOBS=min|slim|std|full`, `A64_DROP="label ..."`, `X86SIM_NODT=all,-<label>` (os_log
text for one job), `X86SIM_INSERT=host/simshim/diag/...` (diagnostic shims, built with `make mac-diag`),
`X86SIM_MDNS=0`, `X86SIM_JETSAM=0`, `X86SIM_MEM_MAX`. Debugging: `tools/debug/` (`lastcrash.sh`, `stuck.sh <process>`,
`allstacks.sh`, `sigctx.py`).

### FoundationModels through a Mac

Apple's simulators run the system language model (FoundationModels, `SystemLanguageModel`) on the Mac they run on. To get
it on iOS / iPadOS and visionOS devices here, point `X86SIM_FM_RELAY` at a Mac with Apple Intelligence turned on
(`1`: `$X86SIM_MAC`, or `user@host`) in `x86sim.env` or the environment of the launcher; the next boot uses it. The Mac
needs ssh key login (BatchMode) and the Command Line Tools (`clang`); nothing is installed or left running there:
the relay builds its Mac end into `~/Library/Caches/x86sim-fmrelay/` and runs it over ssh only while a device uses the
model. The Mac's `modelmanagerd` must offer `com.apple.modelmanager.simulator` (where Xcode's simulators get the model:
`launchctl print system/com.apple.modelmanagerd` lists it under endpoints); no SIP or security change is involved.

The device then runs `modelmanagerd`, `modelcatalogd`, `generativeexperiencesd` and `dasd` as Apple's simulator does,
and `host/mmhost` in place of the Mac's service, which hands each connection to `linux/fmrelay/fmrelay.py`; that one
replays it to the Mac's `modelmanagerd` message for message (`host/mmhost/xpcwire.h`). The model reads available about
a minute after boot (on Apple's simulator too: `generativeexperiencesd`'s boot task decides it). If the Mac can't be
reached the model stays `modelNotReady`, as on a Mac without the service. Off (the default), none of this runs.
visionOS: as on Apple's simulator the model reads available and generation is refused (ModelManagerError 1026).

## Simulator-side binaries

Everything builds on Linux (AGENTS.md); `docs/LINUX-BUILD.md` lists every committed binary and generated file, where
it was made and how it rebuilds here.

The Mach-O files in `host/` and `tests/` (`simhost`, `arm64host`, `SimFramebuffer.framework`, `SimulatorHID.framework`,
`libsimshim.dylib`, `libsimaudio.dylib`, `iosurfaced`, `metalhostd`, `fpsim2host`, `netconfig`, `openurl`, `mtlprobe`,
`iosprobe`, the probes, diagnostic shims and sample apps) are our own code and are committed, so nothing needs building
to run. To rebuild them on Linux, put the SDKs in `sdks/` (gitignored, never committed), then run the usual scripts,
e.g. `make mac` and `build/mac-build-arm64-shims.sh`: with `sdks/` present they build locally (`build/linux-env.sh`:
clang + ld64.lld, `build/linux-swiftc.sh`). Two ways to fill `sdks/`:

- **`make sdks`: no Mac, no Xcode, no Apple ID.** `build/sdk/macos-sdk.py` downloads `MacOSX.sdk` from Apple's public
  software-update CDN (the Command Line Tools SDK package `xcode-select --install` fetches; about 70 MB).
  `build/sdk/sim-sdk.py` then assembles a substitute `iPhoneSimulator.sdk`: link stubs (`.tbd`) generated from the
  `dyld_sim_shared_cache` of a runtime in `runtimes/` (which `runtime-fetch.py` downloads), plus the macOS SDK's headers,
  which are the same for everything our C and Objective-C code includes (where iOS differs, a patched copy or a minimal
  header of our own). Against the 27.2 runtime and macOS 27.2 SDK it rebuilds every C / Objective-C binary in `host/`
  and `tests/` byte-identically to Xcode's SDK (apart from clang's random temp-object names). Not covered: Swift and
  UIKit (`tests/arm64/objcswift`, `sleepprobe`, `tests/apps`), which need Xcode's own SDK. Using these files means
  accepting Apple's SDK agreement.
- **From Xcode.xip** (a free Apple ID; `x86sim account download-xcode` fetches it, and it is unpacked on Linux, never
  copied from a Mac): Xcode's own `iPhoneSimulator.sdk` and `MacOSX.sdk` in `sdks/`, its watchOS and visionOS SDKs as
  `sdks/WatchSimulator-xcode.sdk` and `sdks/XRSimulator-xcode.sdk` (the test apps and simax build against those: the
  plain ones are the substitutes), plus for the Swift parts `sdks/swift-6.4.2/` (swift.org's Linux toolchain) and
  `sdks/swift-lib/` (the Darwin Swift resource dir of Xcode's toolchain); `build/linux-swiftc.sh` lists what it reads.

tvOS and watchOS builds of the same binaries (`host/<name>/arm64-tvos`, `arm64-watchos`) take
`X86SIM_PLATFORM=tvos|watchos build/mac-build-arm64-shims.sh ...` and their own SDK in `sdks/`: `AppleTVSimulator.sdk`
and `WatchSimulator.sdk`, from Xcode or made by `build/sdk/sim-sdk.py --runtime runtimes/<tvos-|watchos-...>` like
the iOS one. Xcode's WatchSimulator.sdk has no IOKit, IOSurface, Metal or SystemConfiguration (private on watchOS),
which our binaries need: use the substitute for watchOS.

`cargo install apple-codesign` for signing either way. Metal shaders (`xcrun metal` / `metallib`, the probe library and
sdkcov's Core Image kernels) compile with Apple's own Metal toolchain, a public download like the runtimes
(`build/metal-toolchain.py fetch`: about 840 MB from Apple, 380 MB kept in `sdks/metal-<build>/`), run under Darling by
`build/linux-metal.sh`. The visionOS builds (`host/<name>/arm64-xros`) take `X86SIM_PLATFORM=xros` and
`XRSimulator.sdk` in the same way.

A committed binary can be checked against its source this way too: rebuild it and compare (the only differences
should be the LC_UUID, the code signature and clang's temp-object names in the debug map).

## Shipped pre-translate training

`cli/libexec/arm64/training-<build>.x86t` holds the code blocks each program ran (addresses and how many programs ran
them; no code or content) on the machine that made the release. The planner counts it with the install's own profiles,
so a new install's first image already holds what apps run. Refresh it after using the system apps on a dev build,
adding to what it holds (`--merge`: a block keeps the higher program count) and any other cache dirs (an AppImage
install's `~/.cache/x86sim/jc-<build>`; each dir adds every program's newest profile, a program's blocks counted once):

    T=cli/libexec/arm64/training-24B8117.x86t
    tools/launcher/target/release/x86sim-aot --jc ~/scratch/x86sim/jc-24B8117 export-training \
        --out $T --merge $T ~/.cache/x86sim/jc-24B8117
