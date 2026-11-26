# Rules for agents working in this repository

## Everything builds on Linux

- x86Sim is built on Linux. Every binary, library, test app and resource must build here with the Linux toolchain
  (build/linux-env.sh: clang, ld64.lld, swiftc and the SDKs in sdks/). Nothing in the product, the release or the
  setup may depend on copying files or build output from a Mac.
- The Mac ($X86SIM_MAC) is for comparison testing and validation: running the same app, check or input on Apple's
  simulator to see what Apple does (tests/apps/sdkcov/ref-mac.sh), and validating x86Sim's results against it. It
  is not a build machine and not a source of files for the product. If something really cannot be built here, say
  so in the change, explain why, and find the Linux path before adding a Mac dependency.
- What is not built here and why (docs/LINUX-BUILD.md has the full audit):
  - Apple's own pieces are downloaded on Linux, never copied from a Mac: runtimes (`runtime-fetch.py`) and the Metal
    toolchain (`build/metal-toolchain.py`) without an Apple ID; XCTest's frameworks and the device SDK come from
    Xcode.xip (a free Apple ID), unpacked on Linux by `x86sim dev setup sdk --xip`. Apple publishes no XCTest without one.
  - The FoundationModels relay (`X86SIM_FM_RELAY`, off by default) is a runtime service, not a build: Apple's on-device
    model runs only on a Mac with Apple Intelligence, so the relay forwards the guest's requests there.
  - `tests/apps/XCTestDemo/build.sh` runs `xcodebuild` on the Mac on purpose: the fixture checks that bundles made by
    Xcode itself run in `x86sim test` (comparison). Linux-built tests are covered by `x86sim test --spm`.
  - Fixtures only an Apple framework can write are made by guest programs built here and run on a phone (sdkcov's
    `res/*.mov` / `res/sdkcovGK.sks`: `tests/apps/sdkcov/res/sdkcovRes.sh`).
  - Simulator device types (`cli/lib/devicetype*.json`) come from Xcode.xip too (its XcodeSystemResources.pkg), read
    on Linux by `tools/devicetypes/extract-devicetypes.py`; which ones a runtime takes comes from the runtime's profile.
  - The iPhone Duo's 3D model (Xcode DeviceHub's `V68.usdz`, Apple's) is never committed or shipped: each user's own
    Xcode.xip gives it (`tools/devicemodels/extract-devicemodels.py`, run by `account download-xcode` / `dev setup sdk
    --xip`) into ~/.local/share/x86sim/devicemodels; without it the launcher and web page show the Duo flat.

## Stopping processes

- Kill by PID, never by pattern. Keep the PID of what you start (`$!`, a pidfile, the `pid` a tool returns) and
  `kill <pid>`. Never `pkill -f`/`killall`: a pattern also matches your own shell's command line (which contains the
  pattern) and kills it, and it can hit the user's processes (another phone, a running build).
- To stop a phone, use its own stop (`x86sim` / the MCP `sim_stop phone=<name>`), not a signal to Darling processes.
