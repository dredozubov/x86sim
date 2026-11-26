# Architecture

Documentation map:

- [USAGE.md](USAGE.md): the launcher, the `x86sim` command line, device builds, the device pool, the browser view
- [AGENT-TOOLS.md](AGENT-TOOLS.md): the screen as text, actions on elements, OCR and marks, network capture, the MCP
  server; [skills/x86sim/SKILL.md](../skills/x86sim/SKILL.md) is the skill file for coding agents
- [TESTING.md](TESTING.md): XCTest / XCUITest runs, the Accessibility Inspector
- [DEBUGGING.md](DEBUGGING.md): LLDB, the CPU profiler, the Web Inspector
- [BUILDING-APPS.md](BUILDING-APPS.md): `x86sim dev`, every app toolchain that builds on Linux, the Apple Account sign-in
- [ARCHITECTURE.md](ARCHITECTURE.md) (this file): how the pieces fit
- [METAL.md](METAL.md): the GPU path (metalhostd, vkmtl, mtlvk), GPU selection, how buffers reach the GPU
- [PARITY.md](PARITY.md): x86Sim against Apple's Simulator, feature by feature
- [WORKAROUNDS.md](WORKAROUNDS.md): what is skipped, faked or approximated, and what a faithful version would need
- [DEVELOPMENT.md](DEVELOPMENT.md): building from source, the repository layout, the simulator-side binaries
- [LINUX-BUILD.md](LINUX-BUILD.md): the audit of what builds on Linux and how
- [RELEASE.md](RELEASE.md): the AppImage, Darling's three modes, first run, updates, CI
- [REPOS.md](REPOS.md): the repositories and forks, committing and upstream syncs
- Wire formats: [protocols/SIMFB.md](protocols/SIMFB.md) (frame ring), [protocols/SIMHID.md](protocols/SIMHID.md)
  (input), [protocols/METAL.md](protocols/METAL.md) (Metal over XPC and the VKMTL socket),
  [protocols/IOSURFACE.md](protocols/IOSURFACE.md), [protocols/SIMAX.md](protocols/SIMAX.md) (accessibility reader),
  [protocols/NET.md](protocols/NET.md) (network capture)

x86Sim runs Apple's **arm64 simulator runtimes** on x86-64 Linux: iOS and iPadOS 27 (default: iOS 27.2, 24B8117), tvOS
27 (24K150), watchOS 27 (24S118) and visionOS 27 (24N120). The runtime's binaries are unchanged. They run under
**Darling** (a Darwin compatibility layer: Mach-O loader + XNU syscall/Mach emulation + `darlingserver`), and their
arm64 code is translated to x86-64 by **libarm64jit** (`linux/arm64jit`, built on dynarmic), just in time or from a
pre-translated (AOT) image. Everything CoreSimulator and the Mac host would provide around the runtime (the launchd
handshake, the display, touch input, GPU, cross-process surfaces, DNS, network state, host file services) is replaced by
small programs in this repo: some run **inside Darling** as simulator binaries (`host/`, arm64 builds under
`host/<name>/arm64`), some run **natively on Linux** (`linux/`, `cli/libexec`). Phones are started by the launcher
(`tools/launcher`) through `cli/libexec/arm64/boot-a64.sh`.

```
 Linux host                                             Darling container (one prefix per phone)
 ---------------------------------------------          -------------------------------------------------------------
 launcher (tools/launcher) / x86sim-aot                 darling shell -> simhost (host/simhost, x86_64)
   boot-a64.sh: mksimdevice.py, mtlvk, mdnsresponder,       -> launchd_sim (runtime)  [device: <device>/data]
                simaudio.py, jetsam.py                         -> the runtime's daemons and agents (backboardd, SpringBoard,
   limited.sh scope -> boot-inner.sh -> darling shell             cfprefsd, lsd, runningboardd, ..., apps)
                                                               -> our jobs: metalhostd, iosurfaced, netconfig,
                                                                  fpsim2host, openurl, fseventsd, nisimhost, mmhost
                                                        every arm64 process: mldr -> arm64host -> libarm64jit.so (ELF)
                                                                             DYLD_INSERT libsimshim (host/simshim/arm64),
                                                                             libsimaudio; libsimax / libsimnet on demand

 mtlvk (linux/mtlvk, Vulkan; one per GPU in use) <== Unix socket + memfds ==  metalhostd (MTLSimImplementation on vkmtl)
 mdnsresponder.py (linux/mdnsd) <== dnssd_ipc socket ======  libsystem_dnssd in every process
 hostnet.py (linux/hostnet) --plist--> netconfig -> host-configd store -> configd_sim's SimulatorSupport
 simview.py / fb2png.py  <== frame ring ===============    SimFramebuffer.framework (host/simfb) in backboardd
 simview.py / simtouch.py  == simhid.sock ==>                 SimulatorHID.framework (host/simhid) in backboardd
 simaudio.py (PipeWire, tap) <== simaudio.sock ==             libsimaudio (host/simaudio) in each process
 launcher core (ax.rs: snapshot, tap, ...) == simax sockets ==> libsimax (host/simax) in every UIKit process
 lldb / x86sim profile == x86sim-dbg-<UDID>-<pid>.sock ==>    libarm64jit's GDB stub and sampler
 launcher core (rwi.rs) == x86sim-rwi-<UDID>.sock ==>         the runtime's webinspectord
 darlingserver (Darling, Linux process): Mach IPC, threads, VM, memfd-backed shared memory for every container process
```

## Darling (external/darling, branch x86sim)

Darling provides the Mach-O loader (`mldr`), the XNU syscall and Mach trap emulation (`libsystem_kernel`, in
`darling-xnu`), the Mach IPC/task/thread server (`darlingserver`), `dyld` for the host side and `iokitd`. The iOS
simulator runtime is far more demanding than the macOS userland Darling targets: workloops, cooperative thread pools
(Swift concurrency), ulock, Mach memory entries, guarded fds, getattrlist/fsctl/chflags, PF_ROUTE, csops and more.
All changes are on the `x86sim` branches of our forks ([REPOS.md](REPOS.md)), each marked `x86Sim:` in the source.

Inside Darling the Linux root is `/Volumes/SystemRoot`; the scripts translate paths (`mksimdevice.py darling()`).
Each phone has its own Darling prefix (`A64_DPREFIX`, default `$X86SIM_SCRATCH/a64prefix`); stopping a phone stops only
that prefix's container.

## arm64 code: arm64host and libarm64jit

When `mldr` is asked to run an arm64-only Mach-O, it re-executes itself on `arm64host` (`host/arm64host`, an x86_64
macOS program installed next to mldr) with `X86SIM_A64_EXE` naming the arm64 program, and renames `DYLD_*` to
`X86SIM_A64_DYLD_*`. arm64host starts like any Darling process (native libSystem, TSD, darlingserver), loads the ELF
library `libarm64jit.so` through Darling's elfcalls and hands over: dynarmic runs the arm64 `dyld_sim` and the program,
while `libsystem_kernel`/`platform`/`pthread` stay the process's native x86 libraries.

Inside libarm64jit (`linux/arm64jit`):

- `jit.cpp`: each native thread running guest code has its own dynarmic Jit and an 8 MB guest stack; translated code
  is shared by all threads of the process. Native code can call back into guest code (nested `Jit::Run`).
- `boundary.cpp`: the `svc` boundary. Guest calls into native Darwin functions go through numbered `svc` thunks that
  move arguments between the arm64 and System V conventions; `guest_callable()` gives native code a trampoline into a
  guest function.
- `objc.cpp`: an inline x86 `objc_msgSend` cache probe emitted when `_objc_msgSend` is translated.
- `dyldsim.cpp`: native shortcuts applied to `dyld_sim` before it runs (`X86SIM_A64_DYLD_NATIVE=0` turns them off).
- `gdbstub.cpp`, `prof.cpp`: the GDB remote stub LLDB attaches to and the CPU sampler, both off until asked for
  ([DEBUGGING.md](DEBUGGING.md)).
- `jitcache.cpp`: the persistent translation cache in `X86SIM_A64_JITCACHE_DIR` (default `$X86SIM_SCRATCH/jitcache`;
  runtimes other than 27.0 use `$X86SIM_SCRATCH/jc-<build>`), keyed by the dyld cache UUID and a build id that includes
  the codegen version and the placement table's hash. Per-process `.bin` files record what each program ran; the
  `.aot` image holds pre-translated code and is loaded at process start (`X86SIM_A64_AOT=0` disables it).

Non-cache Mach-Os (runtime binaries, apps) get fixed addresses from a placement table
(`cli/libexec/arm64/placement-<build>.txt`, `mkplacement.py`), copied into the cache dir; the AOT image must be built
with the same table.

**Tiers.** Code that is not in the AOT image is first run by a small A64 interpreter in dynarmic: a block is
translated only after `X86SIM_A64_INTERP` runs (default 2; `0` = translate at once). Most blocks a starting process
touches run once or twice, so a boot without any cache spends far less time translating. Blocks from the AOT image are
never interpreted, so cached boots are unchanged. This is what makes a boot with no translation cache (a fresh
install before the first image is built, or `X86SIM_A64_JITCACHE=0`) reach the home screen: about 16 s on an iPhone
18 Pro when it was measured (2026-11-25), about the same as a cached boot. `X86SIM_A64_SIDE_EXITS=N` (default 0) lets
a block go on past N conditional branches; `X86SIM_A64_BLOCKCOUNT=1` counts how often translated blocks run. libarm64jit
and dynarmic are built with ThinLTO (`X86SIM_JIT_LTO`, on with clang and lld).

**Memory.** Guest anonymous private memory is mapped `MAP_NORESERVE`. A main executable's read-only segments are
mapped read-only (dyld_sim's `__TEXT` keeps write: `dyldsim.cpp` patches it), so the idle file trim can drop them:
once a process is quiet, its clean file-backed pages (AOT image, the image's index, dyld cache text) are given back
(`X86SIM_A64_FILETRIM`), and a process that never goes quiet (visionOS's 60 fps compositor) is trimmed at most once a
minute after its file RSS grew. Pages of the AOT image stay shared between processes: image code is never linked to
code a process translated itself (such a link made the image page private).

### Pre-translation (tools/launcher x86sim-aot)

`tools/launcher/core/src/aot.rs` builds the AOT image in chunks: one per dyld-cache dylib, placed runtime Mach-O or
placed app executable. Each chunk is translated by libarm64jit's builder into its own slot of the code slab (translated
code is position dependent, so a slot is fixed once assigned and a rebuilt chunk returns to it); the image
(`<uuid>-<build>.aot`) is assembled from the chunk files. Layout under the cache dir: `placement.txt`,
`aot/config.json`, `aot/manifest.json`, `aot/chunks/`, `aot/progress.json`. What goes in is chosen from training
profiles: the install's own `.bin` files (and `.live` files: what a process running on the image translated itself)
and the shipped `cli/libexec/arm64/training-<build>.x86t`.

Ranking: the code slab is smaller than what the profiles ask for (an iOS hot set wants about 3 GB of 1.7), so blocks
are ranked by the number of programs that ran them (`core/src/hot.rs`) and the slab is filled from the top. Programs
that run at idle on every boot count as 4 programs each (`RESIDENT_WEIGHT`): `boot-a64.sh` records them in
`aot/resident.txt`, the union over boots, so SpringBoard's own code is not pushed out by code that several test apps
happen to share. The chunk builders always translate (they do not use the interpreter tier), and a chunk that was
built empty although it has training counts as stale.

Upkeep is incremental. 90 s after a boot, once the phone is idle, `boot-a64.sh` runs `x86sim-aot maintain` (an image
for the current placement assembled from the chunks that are up to date, then the cleanup of images, chunks and
per-process caches nothing uses any more) and `x86sim-aot status`, which notes in `$ST/aot-status.txt` how many chunks
need rebuilding (`X86SIM_AOT_AUTOUPDATE=1` runs `x86sim-aot update` right away). Only stale chunks are rebuilt, each
into its own slot. The launcher runs the same update by itself: at start, after a device stops, when versions
change and every 30 min (`X86SIM_NO_AUTO_AOT=1` turns that off).

## Booting: boot-a64.sh, simhost and launchd_sim

`cli/libexec/arm64/boot-a64.sh` boots one device (`A64_DEVICE`, default `var/device-a64`; its iOS version is
`<device>/runtime`, `A64_RUNTIME` overrides). It:

1. starts this boot's mtlvk when `X86SIM_METAL` is not `0` (own socket and pidfile in the state dir, one per GPU
   choice: `mtlvk<key>.sock`, see [METAL.md](METAL.md#gpu-selection)), or shares a running one (`A64_MTLVK_SOCKET`);
   an mtlvk other phones render through is never stopped, and a stop (`A64_STOP_ONLY=1`) starts none;
2. picks the job list (`A64_JOBS=min|slim|std|full`, default `std`; each job's reason is in a comment), applies the
   device's feature toggles (`<device>/features.json`, definitions in `cli/libexec/arm64/features-def.json`) and
   `A64_DROP`, and runs `cli/libexec/mksimdevice.py`;
3. stops this prefix's previous container (its own processes only, found by exact checks), then starts
   `linux/mdnsd/mdnsresponder.py`, `cli/libexec/jetsam.py` and `cli/libexec/simaudio.py`;
4. runs `cli/libexec/arm64/boot-inner.sh` inside the systemd scope of `cli/libexec/limited.sh` (IO cap and memory cap
   `X86SIM_MEM_MAX`; without a systemd user manager, uncapped and outside any scope), which moves this phone's Darling processes into the scope and runs `darling shell` with
   `host/simhost/simhost`, which execs the runtime's `launchd_sim` with the device's environment.

Darling's own macOS launchd jobs that the simulator never needs at load start on demand (usernoted, the macOS
locationd, launchservicesd, securityd, aslmanager, diskarbitrationd) or not at all (eventmonitor, settingsd);
`A64_HOST_DAEMONS=all` keeps every job as installed. A device whose runtime does not take its model (the runtime
profile's `unsupportedDeviceTypes` / `restrictedToDeviceTypes`, e.g. the iPhone Duo on iOS 27.2) is "unavailable", as
in CoreSimulator: `device-a64.py check` refuses to boot it, create it or clone it; stopping is always allowed.

`mksimdevice.py` writes the device the way CoreSimulator does on a Mac: `<device>/data` (the device's home),
`LaunchDaemons/` and `LaunchAngels/` with only the requested jobs (copied from the runtime, or synthetic
`label=program` jobs for our binaries: arm64 builds from `host/<name>/arm64`, left out when there is none),
`data/var/run/launchd_bootstrap.plist`, and `sim.env` (the `SIMULATOR_*`, `DYLD_*` environment, UDID). Device models
come from `cli/lib/devicetypes-a64.json` (`<device>/model`, `x86sim device create --model`; see
[Device types and models](#device-types-and-models)). `simhost` (x86_64: Darling's
host side) plays CoreSimulator's part of the launchd handshake (bootstrap port, the service port MIG request 708, the
holding-tank child). launchd_sim's log is in the prefix at
`private/var/tmp/com.apple.CoreSimulator.SimDevice.<UDID>/launchd.log`.

The launcher (`tools/launcher`, `core/src/sim.rs` and `instance.rs`) runs boot-a64.sh with `A64_KEEP=1`, the phone's
`A64_DPREFIX` and `X86SIM_METAL`, finds a phone's processes by exact checks (its prefix's darlingserver and its
descendants), and starts `simview.py` for its window.

## Apple TV, Apple Watch and Apple Vision Pro (tvOS / watchOS / visionOS)

The same pieces run Apple's tvOS 27, watchOS 27 and visionOS 27 simulator runtimes (`runtimes/tvos-<ver>-<build>-arm64`,
`watchos-...`, `xros-...`; `runtime-fetch.py fetch 24K150` / `24S118` / `24N120`). iPads run the iOS runtime. What
differs from iOS:

- **Our in-simulator binaries are built per platform** (`host/<name>/arm64-tvos`, `arm64-watchos`, `arm64-xros`;
  `X86SIM_PLATFORM=tvos|watchos|xros build/mac-build-arm64-shims.sh`, on Linux): dyld_sim loads only Mach-Os of its
  own platform.
  mksimdevice.py picks the platform's build from the runtime's SystemVersion.plist. libarm64jit's stub dylibs take
  the dyld cache's platform (its header's `platform` field).
- **launchd_sim has only the system domain.** iOS's launchd_sim runs the jobs in `user/<uid>`, which ends its own
  bootstrap mode once loaded; tvOS's and watchOS's put every job in `system`, which stays in bootstrap mode (every
  request of its jobs deferred, so nothing gets past xpcproxy_sim) until the host sends MIG 700 of subsystem 700
  (launchd_sim the server): a send right to a host port, which launchd_sim also watches for death. simhost sends it
  when `SIMHOST_BOOTSTRAP_DONE=1` (boot-a64.sh, for non-iOS runtimes).
- **Shell and jobs**: PineBoard (tvOS), Carousel (watchOS) and SurfBoard (visionOS) take SpringBoard's place;
  boot-a64.sh has their job lists (`TV_UI`, `WATCH_UI`, `XR_UI`) and leaves out shared jobs the runtime doesn't ship.
- **visionOS needs Metal**: `vhmdd` (the simulator's virtual head-mounted display) and `wakeboardd` (its Metal
  compositor) put the room on the screen, so boot-a64.sh refuses to boot a Vision Pro with `X86SIM_METAL=0` or
  without a working mtlvk.
- **The cache holds MTLSimImplementation**, whose calls into Metal can't be rebound: metalhostd patches the two
  device entry points in its own process (WORKAROUNDS.md).
- **Libraries built like device ones**: libdispatch receives large messages with `mach_msg2` and an aux buffer
  (Darling's `mach_msg2_internal` counts receive vectors). The translator's patches into Apple code find their
  targets by the code around them, not iOS offsets: libobjc's `_collecting_in_critical` and BackBoardServices' UI
  sensor connect (objc.cpp), dyld_sim's `matchesPath` install-name call (dyldsim.cpp).
- **Placement and training**: `placement-24K150.txt` / `placement-24S118.txt` place every non-cache Mach-O the
  runtime ships (small enough to fit the window whole); `training-<build>.x86t` as for iOS.
- **Input**: Apple TV has no touchscreen; tvOS takes the hardware keyboard as the remote (arrows, return = select,
  escape = back) and the Siri Remote's buttons as consumer usages on simhid's buttons service (0x40 Back, 0x60 TV,
  0xcd play / pause). PineBoard's system sleep is declined (simshim; WORKAROUNDS.md): there is no HDMI / CEC sink to
  answer it, and a half-finished sleep left a TV that never woke. An Apple Watch gets simhid's Digital Crown service (`crown <delta> y`; the mouse wheel in
  simview).
- **Device types**: `devicetypes-a64.json` entries with `"platform": "tvos"` / `"watchos"` (`x86sim device create
  --model "Apple TV 4K (3rd generation)"` takes the newest tvOS runtime). Apple TV's capabilities name its display
  `TVOut`; simfb serves it as the main display (`LCD`) all the same, as an external display with an sRGB mode, as
  Apple's simulator does. A 3840x2160 Apple TV has screen scale 2 (the device type's artwork scale factor: tvOS lays
  out 1920x1080 points, and MobileGestalt's `main-screen-scale` of 1 drew the UI into a quarter of the screen); the
  "(at 1080p)" models keep scale 1.
- Not yet: pairing a watch with a phone (both devices' `ids_simd` must reach each other's Mach ports, which live in
  different Darling containers).

## simshim (host/simshim)

`libsimshim.dylib` is injected into every simulator process (`DYLD_INSERT_LIBRARIES` in `sim.env`). It interposes the
few host services a Linux host cannot provide, among them system power registration (no IOPMrootDomain), csops
entitlement blobs (sent to Darling's syscall) and sandbox extensions (tokens issued and accepted; nothing is
sandboxed). The arm64 build also includes the os_log formatter used by `x86sim log stream`. It loads two more
libraries where they are wanted: `libsimax` (`X86SIM_AX_DYLIB`) into processes that have UIKit, and `libsimnet`
(`X86SIM_NET_DYLIB`) into a third-party app whose network capture is on. It also records why a process aborted
(`abort_with_payload` / `abort_with_reason`: `<data>/var/log/x86sim-exit/<exe>.<pid>.log`), which `app_launch`,
`app-state` and `logs` show. Optional diagnostic shims (`host/simshim/diag`, `X86SIM_INSERT=...`, built with
`make mac-diag`) log specific subsystems.

## Accessibility reader: simax

`host/simax` (`libsimax.dylib`) answers requests for a process's accessibility elements on a Unix socket per process
([protocols/SIMAX.md](protocols/SIMAX.md)). The host side (`tools/launcher/core/src/ax.rs`) merges the app in front,
SpringBoard and web content into one snapshot with stable refs and performs actions; it is what the MCP tools, `x86sim
snapshot` / `tap` / ..., the Accessibility Inspector and the pool's hang check (`liveness.rs`: the shell's reader is
asked on its main queue) are built on. Besides UIKit and SwiftUI it reads Flutter's semantics tree, SpriteKit and
SceneKit named nodes and Unity objects (through IL2CPP).

Where a screen has no elements, the host reads the pixels: `core/src/ocr.rs` runs OCR on the frame (ocrs on the rten
runtime, pure Rust; two models of about 12 MB downloaded once into `~/.cache/x86sim/ocr` and checked by SHA-256) for a
view that draws its own pixels, and `core/src/marks.rs` draws element outlines with their refs onto a screenshot
([AGENT-TOOLS.md](AGENT-TOOLS.md#text-in-pixels-ocr)).

## Network capture: simnet

`host/simnet` (`libsimnet.dylib`) is an `NSURLProtocol` in the app's own process that records URLSession requests
(headers, bodies, timings) and answers mock rules; libsimshim records connections of other network stacks. Everything
goes through files in `<device>/data/x86sim-net/`, read by `core/src/net.rs` ([protocols/NET.md](protocols/NET.md)).
There is no proxy and no certificate: HTTPS is seen in the clear because the hook is above TLS.

## Jetsam: jetsam.py

The simulator has no memorystatus, and every process carries a few hundred MB under the JIT. `cli/libexec/jetsam.py`
reclaims what a device's jetsam would (idle extensions, suspended background apps, clean idle-exit daemons, system XPC
services), reading the records Darling's `libsystem_kernel` keeps in the container
(`/private/var/run/x86sim-suspended/<pid>`, `/private/var/run/x86sim-jetsam/<pid>`: band, dirty flags, background
state). An app is killed only on a positive background signal (RunningBoard suspended it, `PRIO_DARWIN_BG`, its
role, RunningBoard's state as the openurl job reports it) and never while it is visible or was in front at the last
touch; an app going to the background also raises the simulator's memory warning. Daemons every app launch talks to
get a longer grace, as do all daemons while an app is in front; something relaunched right after a kill doubles its
grace each time. On iPad, chronod's widget renderer runs as an app and is not taken for the app in front. The grace
times are `X86SIM_JETSAM_*` variables listed at the top of the script. `X86SIM_JETSAM=0` turns it off.

Other memory measures: the frame ring's idle trim and skipped repeated frames (below), the translator's file trim and
shared AOT image pages (above), `mdnsresponder.py` importing dnspython only for its first unicast query, pool devices
opting in to kernel same-page merging (`PR_SET_MEMORY_MERGE`; [USAGE.md](USAGE.md#device-pool)), and the per-device
memory cap `X86SIM_MEM_MAX` of `limited.sh`'s systemd scope.

## Display: simfb and the frame ring

backboardd loads `SimFramebuffer.framework` from `SIMULATOR_FRAMEBUFFER_FRAMEWORK`. Ours (`host/simfb`) reports a
built-in display named `LCD` (QuartzCore treats a main display with any other name as absent), gives CoreAnimation
IOSurface swapchains and copies each completed present into a shared-memory ring
([protocols/SIMFB.md](protocols/SIMFB.md)), written in the user's runtime directory (`/run/user/<uid>`, `SIMFB_RING`
in `sim.env`; one ring per device, `x86sim-a64[-<name>]-simfb.ring`) and linked from `/dev/shm`. A device with several
integrated screens (the iPhone Duo: the outer `LCD` and the inner `LCD-1`) gets one display per screen of its
capabilities, each with its own ring, present queue and pacing. Every publish wakes Linux readers through a futex on
the ring's seq word (ring version 2), so they sleep while the screen doesn't change. Linux readers: the launcher and
`x86sim serve` (`core/src/ring.rs`), `simview.py` (GTK4 window), `fb2png.py` (screenshots), `fpsmeter.py`,
`framecheck.py`, `simrecord.py`.

- **GPU completion**: with Metal, a present is copied once every command buffer committed before its
  `SFBSwapchainSwapSubmit` has completed; a 1 s watchdog copies anyway.
- **Backpressure**: a swap begins (`SFBSwapchainSwapBegin`) only once fewer than `SIMFB_MAX_INFLIGHT` (default 1) of
  the display's presents still wait for the GPU, cut at `SIMFB_BEGIN_WAIT_MS` (default 100; 0 in either turns it off),
  as on Apple's simulator, where the render server cannot start a frame before a swapchain surface is free. Without
  it the render server encoded frames as fast as the CPU went and a slow GPU built up a queue of about half a
  second, most of it frames that were then dropped.
- **Pacing**: a completed present is published at the next refresh slot (`SIMFB_HZ`, default 60; 0 = at once); a newer
  ready present replaces one still waiting.
- **Repeated frames**: a present equal to the latest frame is not copied (visionOS composites a still scene at
  60 fps); the latest slot is republished at most once a second. The ring has 3 slots, and after
  `SIMFB_RING_IDLE_MS` (default 1500) without a new frame the slots other than the latest are given back to the
  system.

## Input: simhid

backboardd loads `SimulatorHID.framework` from `SIMULATOR_HID_SYSTEM_MANAGER`. Ours (`host/simhid`) adds virtual
touchscreen, button and keyboard HID services to backboardd's event system, and per device type the Digital Crown,
a game controller, the iPad's pointer and trackpad, biometrics and the iPhone Duo's hinge, and feeds them from
`<device>/data/simhid.sock`, a line protocol ([protocols/SIMHID.md](protocols/SIMHID.md)) used by the launcher
(`core/src/hid.rs`), `x86sim serve`, `simview.py` and `simtouch.py`.

The hinge: `hinge <degrees> [ms]` moves the angle between 0 (closed) and 180 (flat) in reports of at least one per
whole degree, and repeats it every 100 ms while the phone is part open, as a hinge sensor streams. CoreMotion reads
it from the hinge service and SpringBoard's device pose picks the outer or inner display (it swaps at 85 degrees).
The launcher's hinge panel, the web page and MCP `sim_fold` offer the poses of Xcode's DeviceHub: closed, half open
portrait, half open landscape, open; each also sets the orientation.

## GPU: metalhostd, vkmtl, mtlvk

On a Mac, simulator processes' Metal goes through `MTLSimDriver` over XPC to the host's `MTLSimDriverHost`, which
replays it on the Mac's GPU. Here `host/metalhostd` (a simulator job) loads the runtime's own `MTLSimImplementation` and
gives it a Metal device implemented by `vkmtl.m`, which forwards every object and command buffer over a Unix socket
(VKMTL protocol, [protocols/METAL.md](protocols/METAL.md)) to `linux/mtlvk`, a native Rust process that runs it on
Vulkan with **metal2vulkan** (`external/metal2vulkan`, branch x86sim: Metal API on Vulkan + AIR to SPIR-V translation).
Buffer and texture memory is shared without copies: simulator memory is memfd-backed (darlingserver), metalhostd obtains
the fd with syscall 599 and passes it with `SCM_RIGHTS`; mtlvk imports it (`VK_EXT_external_memory_host`; on amdgpu,
which refuses that for shmem pages, as a `/dev/udmabuf` dma-buf; mtlvk writes which path its buffers took into
`<socket>.state`). Render targets over IOSurfaces of the screen's size are the exception: mtlvk draws them in VRAM and
copies them to the surface's pages once per command buffer (blending into host pages crossed PCIe for every layer).
CoreAnimation's render server, the wallpaper and apps all use it (`X86SIM_METAL=all`, the default of the launcher and of
boot-a64.sh run by hand; `0` = software rendering).

Each device has a GPU setting (auto, cpu, or one GPU by its Vulkan device UUID; `x86sim gpu`, MCP `sim_gpu`, the
launcher's Advanced > GPU), applied at its next start. There is one mtlvk per GPU in use, shared by the devices on
that GPU. Details: [METAL.md](METAL.md).

## Cross-process surfaces: iosurfaced

IOSurfaces shared between processes (CoreAnimation layers, video, WebKit) are served on a Mac by CoreSimulator's
SimRenderServer as `com.apple.IOSurface.Remote`. `host/iosurfaced` implements that service inside the simulator;
surfaces are shared anonymous memory (memfds in darlingserver) handed out as `xpc_shmem`
([protocols/IOSURFACE.md](protocols/IOSURFACE.md)).

## Network: mdnsresponder and netconfig

The simulator resolves names through the host's mDNSResponder socket (`/var/run/mDNSResponder`).
`linux/mdnsd/mdnsresponder.py` implements the dnssd_ipc protocol on Linux (real DNS via dnspython) at
`$ST/mDNSResponder` (one server per boot, started by boot-a64.sh), linked into the container's `/var/run`
(`X86SIM_MDNS=0`: none). Bonjour works on the device itself: services registered through it are found by Browse and
Resolve, so apps on one device can advertise and connect; there is no multicast DNS on the host's network.
Network state (what a Mac's configd publishes) comes from `linux/hostnet/hostnet.py` (the Linux default-route
interface as Setup:/State: keys), loaded by `host/netconfig` into a second `configd_sim` registered as
`com.apple.SystemConfiguration.configd` (`com.x86sim.host-configd`), which the simulator's configd_sim mirrors. Sockets
and routing sockets themselves are Darling's (PF_ROUTE, socket options, EVFILT_SOCK).

## Host file services: fpsim2host

FileProvider sends some operations to the Mac host's fileproviderd (`com.apple.FileProvider.sim2host`): open by file
id, openat/mkdirat/... on behalf of extensions, package lookup, directory entries, dataless files.
`host/fpsim2host` (job `com.x86sim.fpsim2host`) serves that interface inside the simulator.

## Audio: simaudio

`host/simaudio/arm64/libsimaudio.dylib`, injected into each process, provides the audio devices a Mac's CoreSimulator
and coreaudiod would, and streams PCM over `simaudio.sock` to `cli/libexec/simaudio.py`, which boot-a64.sh starts on
every boot. With `X86SIM_AUDIO=1` it plays the output on PipeWire and records the host's microphone (`pw-cat -a`; with
PipeWire before 1.4, whose pw-cat has no raw mode, `pacat`/`parec --raw` through pipewire-pulse); otherwise input
streams get silence. Either way it offers the output streams on a tap, `simaudio-tap.sock` in the state dir, where
`x86sim serve` (`tools/launcher/core/src/share/audio.rs`) mixes them for a browser (Opus or PCM on the page's
WebSocket) and feeds a browser's microphone back to the input streams. `X86SIM_AUDIO_SOCKET=none` leaves the devices
without a socket (the output drops the PCM on its clock, the input reads silence); the devices are always there, as the
simulator always has an output device: AVPlayer refuses items with audio (CoreMediaErrorDomain -12746) when there is
none (see [WORKAROUNDS.md](WORKAROUNDS.md)).

## Debugging, profiling and web inspection

The app's arm64 code runs translated, so no debugserver can see it. libarm64jit carries a GDB remote stub
(`gdbstub.cpp`) on `/run/user/<uid>/x86sim-dbg-<UDID>-<pid>.sock`, which the host's lldb attaches to, and a sampler
(`prof.cpp`, `perf_event_open` per thread) started through the same request channel. Safari's pages and inspectable
web views are reached through the runtime's own `webinspectord`, started on demand, whose debugger socket
(`/run/user/<uid>/x86sim-rwi-<UDID>.sock`, where simshim binds its listener in place of the launchd socket) speaks
Apple's Remote Web Inspector protocol (`core/src/rwi.rs`). All three are described in [DEBUGGING.md](DEBUGGING.md).

## Device types and models

`cli/lib/devicetypes-a64.json` and `cli/lib/devicetype-<model>.json` (capabilities) come from Xcode's device type
plists, read on Linux by `tools/devicetypes/extract-devicetypes.py` from Xcode.xip (its `XcodeSystemResources.pkg`),
an Xcode.app, the bare package or a DeviceTypes directory. Which models a runtime takes comes from the runtime's own
profile. `x86sim account download-xcode` compares a downloaded Xcode's device types with the committed ones
(`--update-devicetypes` writes `cli/lib`).

The launcher and the web page take the screen's corner radius from the device type (`Instance::corner`:
`DeviceCornerRadius` in points over the screen's upright width), so an iPad, an iPhone, an iPhone SE, a watch and a TV
each get their own corners.

The iPhone Duo is drawn in 3D from Apple's own model, Xcode DeviceHub's `V68.usdz`. It is never committed or shipped:
`tools/devicemodels/extract-devicemodels.py` (run by `x86sim account download-xcode` and `x86sim dev setup sdk --xip`)
copies it from the user's Xcode.xip into `~/.local/share/x86sim/devicemodels` (`$X86SIM_DEVICEMODELS`).
`core/src/devicemodel.rs` reads it with a pure Rust USD reader into one skinned mesh; the model's animation (1.5
degrees a frame from flat to closed) gives the pose for a hinge angle. The launcher draws it with OpenGL in egui
(`gui/src/duo3d`), the web page with WebGL2 (`share/web/duo3d.js`), both with the two live screens as textures.
Without the model both show the Duo's screens flat.

## The launcher and its tools

`tools/launcher` is a Cargo workspace: `core` (the library everything shares, and the command-line tools
`x86sim-aot`, `x86sim-mcp`, `x86sim-ax`, `x86sim-dev`, `x86sim-serve`, `x86sim-pool`, `x86sim-account`,
`x86sim-devapp`) and `gui` (`x86sim-launcher`: egui on eframe 0.37, glow renderer, X11 and Wayland). The GUI does its
periodic work in eframe's `App::logic`, which runs whether or not a frame is drawn, so a hidden Wayland window (which
gets no frame callbacks) is not reported as "not responding". `egui-phosphor` (the icon font) is vendored in
`tools/launcher/vendor` until it has a release for egui 0.37.

`x86sim serve` (`core/src/share`) is the browser view: an HTTP and WebSocket server streaming each device's frame ring
as H.264 (or JPEG), its audio from simaudio's tap, and taking input; see
[USAGE.md](USAGE.md#in-a-browser-local-or-remote). The Apple Account sign-in (`core/src/account.rs`, `x86sim account`,
Settings > Apple Account) downloads Xcode.xip for the SDK, the device types and the Duo's model; see
[BUILDING-APPS.md](BUILDING-APPS.md#apple-account).

## Test helpers inside the device

`host/openurl` (job `com.x86sim.openurl`) opens URLs and apps through FrontBoard (`x86sim openurl|app|launch`), reading
requests from `<device>/data/tmp/x86sim-openurl`. It also installs and removes apps (`x86sim install|uninstall`,
`cli/libexec/appinstall.sh`), the way CoreSimulatorBridge does on a Mac: `+[IXAppInstallCoordinator
installApplication:consumeSource:options:completion:]` -> installcoordinationd -> installd (copies the bundle into
`data/Containers/Bundle/Application/<uuid>`) -> containermanagerd (data container) -> lsd (registration) ->
SpringBoard (icon). The device type's capabilities (`cli/lib/devicetype-<model>.json`) are written as
`<device>/capabilities.plist` and given to MobileGestalt with `SIMULATOR_CAPABILITIES`.

simctl's developer commands (`cli/libexec/simctl.py`: `x86sim launch|terminate|get_app_container|listapps|push|
location|addmedia|log stream|io|pidof`) go to the same job as one-line JSON requests (`req <id> <json>`, answered by a
`result <id> <json>` log line). The job does what CoreSimulatorBridge does inside a Mac's device, with the Bridge's
entitlements: FrontBoard's debug options (`__DebugOptions`: arguments, environment, stdout/stderr paths for
`--console`, wait-for-debugger), `FBSSystemService` termination, `LSApplicationProxy` containers,
`+[UNNotificationRequest requestWithIdentifier:pushPayload:bundleIdentifier:]` for `push`, `CLSimulationManager` for
`location` (locationd's `com.apple.locationd.simulation` service: one point repeated every second, waypoints moved along
at a speed with updates by interval or distance, or one of the runtime's scenarios in CoreLocation.framework/Support/
SimulationScenarios; nanoregistryd must run), `PHPhotoLibrary` change requests for `addmedia`.
`--console-pty` passes a Linux pty's path (`/Volumes/SystemRoot/dev/pts/N`) as the app's stdout/stderr. `log stream --app` relaunches the app with
`X86SIM_OSLOG`, which turns on libsimshim's built-in os_log formatter (`host/simshim/diag/oslogdiag.m` compiled in):
messages go to `data/var/log/oslog.<prog>.<pid>.log` without logd/diagnosticd. `io recordVideo` encodes the frame
ring with ffmpeg.

## CLI

`cli/x86sim` reads `x86sim.env` through `cli/lib/config.sh` (also used by every script; `cli/lib/x86config.py` for
Python) and dispatches to the scripts in `cli/libexec` (`x86sim help` lists the commands). Defaults are the arm64
runtime (`runtimes/ios-27.2-24B8117-arm64/RuntimeRoot`) and device (`var/device-a64`). Large scratch files (Darling
prefixes, JIT/AOT caches) are in `$X86SIM_SCRATCH`. The commands that are Rust tools (`snapshot` and the other agent
commands, `dev`, `serve`, `pool`, `account`, `debug`'s session, `profile`, `net`, `gpu`) run the binaries in
`tools/launcher/target/release`.

## Data flows at a glance

| Flow | From | Channel | To |
|---|---|---|---|
| frames | backboardd (simfb) | ring in `/run/user/<uid>`, linked as `$SIMFB_RING_LINUX` | simview, fb2png, framecheck |
| input | simview, simtouch | `<device>/data/simhid.sock` (text lines) | backboardd (simhid) |
| Metal | every Metal client | XPC `com.apple.metal.simulator[.<proc>]` | metalhostd |
| Metal | metalhostd (vkmtl) | Unix socket `mtlvk<key>.sock` (state dir, or a shared one) + memfds | mtlvk (Vulkan) |
| screen as text | libsimax in each UIKit process | a Unix socket per process ([SIMAX.md](protocols/SIMAX.md)) | launcher core (ax.rs): MCP, CLI |
| network capture | libsimnet, libsimshim in the app | files in `<device>/data/x86sim-net/` | launcher core (net.rs) |
| debugger, profiler | lldb, `x86sim profile` | `/run/user/<uid>/x86sim-dbg-<UDID>-<pid>.sock` | libarm64jit (gdbstub.cpp, prof.cpp) |
| web inspection | launcher core (rwi.rs) | `/run/user/<uid>/x86sim-rwi-<UDID>.sock` | the runtime's webinspectord |
| IOSurface | IOSurface.framework | XPC `com.apple.IOSurface.Remote` + xpc_shmem | iosurfaced |
| DNS | libsystem_dnssd | `/var/run/mDNSResponder` -> the boot's `mDNSResponder` socket | mdnsresponder.py |
| network state | hostnet.py | plist -> netconfig -> host-configd | configd_sim (SimulatorSupport) |
| audio | libsimaudio | `simaudio.sock` | simaudio.py (PipeWire; its tap: x86sim serve) |
| host files | FileProvider | XPC `com.apple.FileProvider.sim2host` | fpsim2host |
| install app | x86sim install (appinstall.sh copies the .app into `data/tmp/x86sim-install`) | `<device>/data/tmp/x86sim-openurl` | openurl job -> InstallCoordination -> installd |
| open URL/app | x86sim openurl/app | `<device>/data/tmp/x86sim-openurl` | openurl job -> FrontBoard |
| simctl commands | x86sim launch/push/... (simctl.py) | `req <id> <json>` in `<device>/data/tmp/x86sim-openurl`, `result` lines in its log | openurl job -> FrontBoard, UserNotifications, Photos, CoreLocation, LaunchServices |
