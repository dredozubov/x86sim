# Everything builds on Linux: audit

AGENTS.md's rule: every binary, library, test app and resource of x86Sim builds on Linux with the Linux toolchain
(`build/linux-env.sh`: clang, ld64.lld, `build/linux-swiftc.sh`, the SDKs in `sdks/`), and nothing in the product, the
release or the setup comes from a Mac. The Mac (`$X86SIM_MAC`) is for comparison testing and validation only
(`tests/apps/sdkcov/ref-mac.sh`, `tests/web/webcov/run.sh --ref-mac`).

This is the audit of what the repository held against that rule (2026-11-25): every committed binary or generated
file, and every script that reached the Mac for anything but comparison. "Made" says where the committed file came
from (for Mach-O files: the linker recorded in `LC_BUILD_VERSION`, `lld` = Linux, `ld` = Apple's linker on a Mac);
"Linux today" is the result of rebuilding it here.

## Committed binaries and generated files

| What | Made | Linux today | Fix |
|---|---|---|---|
| `host/*/arm64{,-tvos,-watchos,-xros}/*` (simshim, simax, simnet, simaudio, simfb, simhid, metalhostd, iosurfaced, openurl, netconfig, fpsim2host, nisimhost, fseventsd, mmhost: 64 files) | Linux (lld 23) | yes: `build/mac-build-arm64-shims.sh` (simax rebuilt byte-identical) | none |
| `host/simhost/simhost` (macOS x86_64) | Linux (lld) | yes: `build/mac-build-simhost.sh`, byte-identical | none |
| `host/simshim/diag/arm64/*.dylib` (29 diagnostic shims) | Linux (lld) | yes: `build/mac-build-diag.sh` | none |
| `tests/metal/arm64*/mtlprobe` | Linux (lld) | yes: `build/mac-build-arm64-shims.sh mtlprobe` | embeds `tests/metal/shaders/probe_metallib.h`, see Metal below |
| `tests/arm64/*.sim`, `*.mac` (probes; `.mac` are macOS baselines run on the Mac for comparison) | Linux (lld), except `crashsig.sim` and `threadstack.sim`: Apple `ld` (Mac) | yes: `build/mac-build-arm64-tests.sh` (crashsig builds; threadstack, deadname, forkstress, fp16x, sleepprobe had no line in the script) | done: crashsig/threadstack rebuilt here (both pass in `tests/arm64/run.sh`), every committed C probe has a line in the script |
| `build/metal-cache/*.metallib` (the probe library) | **Mac** (Xcode 27.1, recorded by `linux-metal.sh`) | no: a cache miss needed the Mac (`X86SIM_METAL_RECORD=1`) | done (F3): `linux-metal.sh` runs Apple's Metal toolchain (`build/metal-toolchain.py`: a public MobileAsset) under Darling; cache removed |
| `tests/metal/shaders/probe_metallib.h` (embedded in mtlprobe) | **Mac** (`tests/metal/shaders/build.sh` over ssh) | yes (F3) | done: rebuilt here (toolchain 27B47 instead of the Mac's 27.1: same functions, a few bytes per function differ); mtlprobe passes as before on a phone (48 of 49, the one failure, the 1206-wide IOSurface render, is the same with the Mac-built library) |
| `tests/apps/sdkcov/res/sdkcovCI-{ios,tvos,xros}.metallib` | **Mac** (`res/sdkcovCI.sh`, ssh) | yes (F3): rebuilt byte-identical to the Mac's | done: `sdkcovCI.sh` runs here (the visionOS substitute SDK needed CoreImage.metallib: `build/sdk/sim-sdk.py` now copies framework Metal libraries from the runtime) |
| `build/metal-research/{mac,work}/*` (AIR/metallib from the research into running the toolchain under Darling) | `mac/`: **Mac**; `work/`: Darling | n/a (research outputs) | done: removed; the shim it proved is `build/metal-shim.c` |
| `tests/metal/shaders/captured/*.wire.metallib` | x86Sim on Linux (what the guest's MTLSimImplementation hands metalhostd, `docs/METAL.md`) | yes (captured from a phone) | none |
| `tests/apps/sdkcov/res/sdkcovChapters.mov`, `sdkcovStall.mov` | **Mac** (`res/sdkcovMovies.swift` run as a macOS program) | yes | done: `res/sdkcovRes.sh PHONE` builds the generator with the Linux toolchain and runs it on a booted iPhone (`x86sim spawn`; AVAssetWriter needs the phone's iosurfaced, plain Darling has no IOSurface). Equivalent, not byte-identical: the same atoms (header first in the stall movie), tracks, frame counts, durations and chapters; the H.264 data differs (the simulator's software encoder, not the Mac's), so the files are about twice the size. `func:AVFoundation.chapters-bundled-movie` and `player-stalled-http-loopback` answer as with the Mac's files |
| `tests/apps/sdkcov/res/sdkcovGK.sks` | **Mac** (`res/sdkcovGK.swift`, macOS program) | yes | done: the same script (it also runs under plain Darling, `tests/arm64/run.sh`, with the same output). Equivalent: the same 58 archived objects, classes and keys; the iOS build archives SKNode's superclass as UIResponder (macOS: NSResponder), a newer SpriteKit version number and the gravity as a float. `func:GameplayKit.gkscene-from-sks` answers as before |
| `cli/lib/devicetype-*.json`, `cli/lib/devicetypes-a64.json` (data from Xcode's device type plists) | **Mac** (`tools/devicetypes/extract-devicetypes.py` over ssh) | not yet | read the same plists out of an Xcode .xip on Linux (see "Open") |
| `cli/libexec/arm64/training-*.x86t` (pre-translate training) | Linux (x86sim-aot) | yes | none |
| `build/sdk/xros-versionmap.json` | Apple's public SDK data, written by hand | n/a | none |
| fonts (`tools/launcher/gui/assets/fonts/Inter-*.ttf`, `cli/libexec/fonts/Phosphor.ttf`) | upstream font releases | n/a | none |
| `docs/screens/**/*.png`, `build/release/x86sim.png` | screenshots of x86Sim / artwork | n/a | none |

## Scripts that reached the Mac

| Script | Used the Mac for | Fix |
|---|---|---|
| `build/mac-env.sh` (`X86SIM_BUILD=mac`) | building every simulator-side binary over ssh when `sdks/` was missing | done: the Mac path is removed; without `sdks/` the build says how to make them (`make sdks`) |
| `build/linux-metal.sh` (`X86SIM_METAL_RECORD=1`) | compiling Metal shaders on a cache miss | done (F3) |
| `tests/metal/shaders/build.sh`, `tests/apps/sdkcov/res/sdkcovCI.sh` | `xcrun metal` on the Mac | done (F3): run here |
| `cli/libexec/xctest.py` (`x86sim test fetch-platform`) | copying Xcode's `<Platform>.platform` XCTest files from the Mac | done (F1): from the Darwin SDK `x86sim dev setup sdk --xip Xcode.xip` builds on Linux (it holds XCTest.framework, XCTestCore, XCUIAutomation, libXCTestBundleInject and the rest; the xctest agent comes from the runtime). Apple publishes no XCTest download without an Apple ID (the simulator catalogue lists runtimes, Metal toolchains, docs and device support only), and the runtime ships only XCTestSupport / XCTAutomationSupport. xcodebuild's XCTestDemo bundles run with it as before (13 of 14 results = Apple; the 14th is a stale build of the fixture, its failure on the line the older source had) |
| `tests/apps/XCTestDemo/build.sh` | kept, as comparison: the fixture exists to check that bundles made by Xcode's own `xcodebuild` run; built on Linux it would test our build instead (AGENTS.md). Linux-built tests are covered by `x86sim test --spm` |
| `cli/libexec/arm64/fetch-macos-host.sh` | copying `/System/Library/GeoServicesData` (Maps' seed resource manifest) | done (F2): no download needed. The seed only names a tile group; geod then fetches Apple's manifest and every resource (the region / territory / time zone archives included) itself. boot-a64.sh writes it; Maps draws tiles on a phone with no geod state |
| `tests/apps/build-ipa.sh` | building the DeviceHello device `.ipa` fixture with Xcode | done (F4): Swift 6.4 + the Darwin SDK made from Xcode.xip on Linux (what `x86sim dev device` uses), clang + ld64.lld, rcodesign; `x86sim-devapp inspect` reads it as the Mac-built one, and it installs and runs on a phone |
| `tools/devicetypes/extract-devicetypes.py` | reading Xcode's device type plists | Open |
| `tests/apps/sdkcov/res/sdkcovMovies.swift`, `sdkcovGK.swift` | running macOS programs that write fixtures | done: iOS simulator programs run on a phone by `res/sdkcovRes.sh` |
| `linux/fmrelay/fmrelay.py`, `boot-a64.sh` (`X86SIM_FM_RELAY`) | a runtime service, not a build: Apple's on-device FoundationModels model runs only on a Mac with Apple Intelligence, so the optional relay forwards the guest's model requests there (off by default) | cannot move: documented in AGENTS.md |
| `tests/apps/sdkcov/ref-mac.sh`, `tests/web/webcov/run.sh --ref-mac` | comparison with Apple's simulator | allowed (validation) |

## Open

Items not moved in this round (listed in AGENTS.md), each with its Linux path:

- Device types: Xcode's `Contents/Developer/Platforms/*.platform/Library/Developer/CoreSimulator/Profiles/DeviceTypes`
  are inside Xcode.xip, which the Darwin SDK setup already streams on Linux.
