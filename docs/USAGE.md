# Using x86Sim

The launcher, the `x86sim` command line, device builds, the device pool and the browser view. For agents see
[AGENT-TOOLS.md](AGENT-TOOLS.md); for tests and accessibility [TESTING.md](TESTING.md); for LLDB, profiling and Web
Inspector [DEBUGGING.md](DEBUGGING.md); for building apps [BUILDING-APPS.md](BUILDING-APPS.md).

## Launcher

The launcher is what the AppImage opens. Its pages:

- **Devices**: every device as a card with a live screen, running devices first. Click a card to open it; start,
  stop, restart, add, rename and remove devices, or open one in its own window. A device's page has its screen and
  buttons, its feature toggles, memory, CPU and processes, and its logs (lines can be picked, copied and saved). Its
  Simulate section sets appearance, text size, Increase Contrast and fidelity, and erases or clones the device.
  Further folds hold screen recording, a CPU profile, Share, Web Inspector, Network (an app's requests) and
  Accessibility; Advanced has the device's GPU. The overview says which GPU a running device renders on and
  whether its GPU buffers are shared or copied ([METAL.md](METAL.md#how-buffers-reach-the-gpu)).
- **Screens**: a device is drawn with a plain bezel and the corner radius of its device type. An iPhone Duo shows
  both screens; its fold button opens the hinge panel (a slider from closed to flat, and the poses closed, half open
  portrait, half open landscape and open). With Apple's 3D model of the Duo on this computer it is drawn in 3D, the
  hinge following the slider; the model comes from your own Xcode.xip (`x86sim account download-xcode` or `x86sim
  dev setup sdk --xip` put it in `~/.local/share/x86sim/devicemodels`) and is never shipped. Without it the two
  screens are shown flat.
- **Versions**: the runtimes on this computer and those available from Apple. Delete removes an installed version:
  only its files, or also its pre-translated code and caches. Devices that use it are listed, and a running one has
  to be stopped first.
- **Pre-translate**: build or update the ahead-of-time image for a runtime (picked from a list grouped by platform),
  and see what it takes on disk. The launcher keeps the images up to date by itself.
- **Settings**: appearance (System, Dark or Light), graphics (GPU or software), screen scaling, memory cap and
  clean-up, disk use, updates, and the Apple Account sign-in ([BUILDING-APPS.md](BUILDING-APPS.md#apple-account)).
- **Setup**: the first-run steps, which stay available afterwards as a check of the computer.
- **Develop**: the app toolchain (see [Building and shipping apps](BUILDING-APPS.md)): what is installed, and
  install / repair for each piece.

The Devices page also shows device pools (see [Device pool](#device-pool)).

Arrow keys or `hjkl` move between devices and rows, Enter opens, the number keys switch pages, `?` lists every
shortcut and `q` quits. Closing the launcher leaves running devices running.

## Command line

`x86sim` follows `xcrun simctl` where there is an equivalent. From the AppImage it is
`./x86sim-*.AppImage x86sim <command>`; in a checkout it is `cli/x86sim`.

```sh
x86sim device models                          # the models a device can be
x86sim device create --model "iPhone 17 Pro" work
x86sim runtime list all                       # runtimes in Apple's catalogue
x86sim runtime delete 24K150 --dry-run        # what deleting a version frees (--all: its caches too)
x86sim device delete work --stop              # the device's folder, state, prefix and frame ring
x86sim gpu work list                          # the host's GPUs and the one this device renders on
x86sim gpu work set amd                       # auto | cpu | a GPU by name, id or list index; at the next start

x86sim install MyApp.app                      # an arm64 iOS-simulator build
x86sim install MyApp.ipa                      # or a device build: .ipa, .xcarchive, device .app
x86sim launch --console com.example.myapp -arg value
x86sim terminate com.example.myapp
x86sim listapps --json
x86sim get_app_container com.example.myapp data

x86sim openurl https://example.com
x86sim push com.example.myapp payload.json    # simulated remote notification
x86sim location set 48.8584,2.2945            # also: routes and scenarios
x86sim addmedia photo.jpg clip.mov
x86sim log stream --app com.example.myapp
x86sim logs com.example.myapp                 # its os_log and last crash report, symbolicated
x86sim app-state com.example.myapp            # running? foreground / background / suspended, memory, last exit
x86sim net work capture com.example.myapp on --relaunch   # its network requests: net log, net show ID, net mock

x86sim ui appearance dark                     # also: content_size, increase_contrast, reduce_motion, ...
x86sim status_bar override --time 9:41 --batteryLevel 100 --batteryState charged --cellularBars 4 --wifiBars 3
x86sim pbcopy "text"                          # pbpaste; --host: the Linux clipboard; pbsync keeps both the same
x86sim locale --language fr-CA --locale fr_CA # also: timezone Europe/Paris, keychain reset
x86sim fidelity fast                          # 3x iPhone at 2x + reduced effects (high: native)
x86sim erase work                             # back to new; clone work work2 copies it (device off)

x86sim tap 200 400                            # also: swipe, pinch, type, key, home, lock, crown
x86sim --phone work snapshot                  # the screen as text (see "Agents" below); --phone on any command
x86sim screenshot shot.png
x86sim io recordVideo --secs 10 out.mp4
x86sim record start out.mp4                   # in the background; record stop finishes the file
x86sim account status                         # the Apple Account sign-in (Xcode downloads, signing)
```

`x86sim help` lists every command; `--phone NAME` (a name, folder or path) before a command picks the device, and
most simctl-style commands also take it as their first argument. A second tool, `x86sim-aot`
(`./x86sim-*.AppImage aot`), starts and stops devices (`x86sim-aot --device work sim start|stop|restart`, `sim status`
lists them), edits feature sets and builds the pre-translated image from a terminal.

A model can be created only on a runtime that takes it (the runtime's own profile says which, as in CoreSimulator):
`device create`, a boot and `clone` refuse the others, and such a device shows as unavailable.

### GPU per device

Each device renders on its own GPU setting: `auto` (a discrete GPU first), one GPU, or `cpu` (lavapipe, Mesa's CPU
Vulkan driver: no GPU is used). `cpu` is always there: x86Sim comes with its own lavapipe and needs no driver installed.
`x86sim gpu [PHONE] list` shows the host's GPUs, the setting and the GPU a running device uses; `x86sim gpu [PHONE]
set auto|cpu|NAME|ID` changes it for the next start (the launcher: Advanced > GPU; MCP `sim_gpu`). Devices on the
same GPU share one GPU helper process (mtlvk). On an AMD GPU, give your user read-write access to `/dev/udmabuf`
(the Setup page checks it): without it every buffer is copied to the GPU and rendering is slower. How it works:
[METAL.md](METAL.md#gpu-selection).

### Sound

Every device has audio devices. `X86SIM_AUDIO=1` in `x86sim.env` (or the launcher's environment) plays a device's
output on PipeWire and records the host's microphone; without it nothing is played on the host and inputs read
silence. The browser view plays a device's sound either way (below). How it works:
[ARCHITECTURE.md](ARCHITECTURE.md#audio-simaudio).

### Apple TV screen size

The 4K Apple TV models have a 3840x2160 screen at scale 2 (1920x1080 points, as tvOS lays out); the "(at 1080p)"
models a 1920x1080 screen at scale 1 and a quarter of the pixels to draw.

## Device builds

`x86sim install` (and the MCP tool `app_install`, and a drop on the launcher) also takes what you would install on an
iPhone: an `.ipa`, an `.xcarchive` or a device `.app`. The arm64 code is the same either way, so the conversion is
metadata, on a copy (the input is never changed):

- every Mach-O in the bundle (app, frameworks, app extensions, a watch app) is retagged to the simulator platform
  (`LC_BUILD_VERSION`, or an old `LC_VERSION_MIN_*` rewritten as one); a fat file keeps its arm64 slice;
- each bundle's `Info.plist` names the simulator (`CFBundleSupportedPlatforms`, `DTPlatformName`, `DTSDKName`);
- the app is re-signed ad hoc, each binary keeping the entitlements its signature had (rcodesign).

App Store downloads are encrypted with FairPlay (`LC_ENCRYPTION_INFO` cryptid 1) for the device they were bought
on and are refused with a message saying so; export a development, ad-hoc or enterprise build instead. Binaries
without an arm64 slice (armv7, arm64e only, x86_64) are refused too. `x86sim-devapp inspect X.ipa` shows what a
bundle holds; `tests/apps/build-ipa.sh` builds a small device `.ipa` (an embedded fat framework, entitlements) on
Linux as a fixture.

## Device pool

For agents and CI, a pool keeps devices booted at their home screen; a caller takes one, uses it and gives it back.

```sh
x86sim pool up 3 --model "iPhone 17 Pro"      # pool-1..pool-3, booted one at a time while memory allows
phone=$(x86sim pool take --ttl 900 --hold-parent)   # a free booted device, held by this shell, at most 15 min
x86sim install "$phone" MyApp.ipa && x86sim launch "$phone" com.example.myapp
x86sim pool release "$phone"                  # reset in the background, then free again
x86sim pool status                            # who holds what, memory per device, room for more
x86sim pool down --delete
```

- **Leases** end at their TTL (`--ttl`, default 30 min; `pool renew`) or when the holder process exits (`--pid`,
  `--hold-parent`; the MCP server holds with its own process, so a session that ends frees its devices). Any pool
  command reaps them. Taking is atomic across processes (a lock around the pool's state in `var/pool/`).
- **Reset on release** (`--reset` at take or release): `apps` (default: uninstall the apps installed during the
  lease, with their data, then Home), `restart` (a fresh boot), `erase` (re-cloned from the template), `none`.
- **Hung devices**: a device whose SpringBoard stops answering (its simax reader, asked on SpringBoard's main
  thread, silent for 3 checks in a row over 10 s or more) shows `hung` in `pool status` and `"hung": true` in MCP
  `phones_list`; it is not handed out, and a free one is restarted (an `apps` reset of a hung device restarts it).
- **Fast creation**: members are clones of `<pool>-template`, a device of the pool's model booted once and stopped,
  copied with `cp --reflink=auto` (instant and sharing disk on btrfs / XFS) and given their own paths and UDID.
- **Memory**: `pool up` boots a device only while available memory stays above a reserve (3 GB, `--reserve-mb`)
  after the measured cost of one device; it stops short rather than risk the out-of-memory killer (`--force`).
- **KSM**: pool devices opt in to kernel same-page merging (`PR_SET_MEMORY_MERGE`, no root). KSM itself is off
  until root turns it on: `x86sim pool ksm` shows the two commands, `x86sim pool ksm on` runs them with sudo on a
  terminal, in the open.
- `--pool NAME` keeps several pools (one model each). The launcher's Devices page shows each pool and can release a
  device; the MCP tools are `pool_status`, `phone_take` and `phone_release`.

## In a browser (local or remote)

`x86sim serve` puts every device in a browser tab: a dashboard with live thumbnails (start, stop, share), and a
device's live screen with its controls. The screen streams as H.264 decoded by WebCodecs (JPEG where the browser
lacks it, e.g. plain HTTP on the LAN); quality, size and frame rate are picked on the page.

- **Input**: click or drag to touch (edge swipes become Home, Control Center and Notification Center as on a
  device), real multi-touch from a touchscreen, Alt + drag to pinch or rotate, Shift + drag for a two-finger pan, the
  wheel scrolls (the Digital Crown on a watch, the remote's swipes on a TV), the hardware keyboard (Ctrl / Cmd is
  Command), Ctrl+V types the clipboard into the device, F1 to F4 Home, Lock and volume, Keyboard > Software / Hardware
  (Toggle Software Keyboard, Connect Hardware Keyboard).
- **Controls per platform**: iPhone / iPad buttons (Home, Lock, volume, Siri, Action, App Switcher), rotate, shake,
  the iPhone Duo's hinge slider and fold poses, drawn in 3D as in the launcher when Apple's model is there; an
  Apple TV's Siri Remote; an Apple Watch's crown, side button and hand gestures; a
  Vision Pro's crown, and the mouse as its system pointer (hover, click, drag; the wheel scrolls where it points).
- **Sound**: Sound on plays the device's audio in the page (Opus decoded by WebCodecs, 16-bit PCM where the browser
  lacks it), ~70 ms from the server to the speaker (a tap on a button that beeps is heard ~115 ms later), with a volume
  per viewer; browsers start audio only from a click, so it is off until then. Mic on (control links, HTTPS or this
  machine) sends the browser's microphone to the device's input instead of the host's.
- **On a phone's browser**: the screen fills the window, with Home, App Switcher, Type… and Sound under it and the
  other controls below; fingers touch, two fingers pinch, rotate and pan.
- **Capture**: a full-size PNG screenshot (also with element marks), and recording the stream to a video file.
- **Panels** (control links): Logs (copy and save), Network (an app's requests, picked from the device's apps),
  Accessibility (inspect and audit), Web pages… (the Web Inspector), Profile 5 s, and the device's GPU.
- **Theme**: the page follows this machine's Omarchy theme live where there is one, else a light or dark look.
- **Links**: a control link (watch and drive) and a view-only link; more links with their own expiry, limited to
  one device or not, from the Share dialog (with a QR code) or `x86sim serve link`; revoke them there.

```sh
x86sim serve --open                 # http://127.0.0.1:7380, opened in the browser
x86sim serve --bg --tailscale       # also https://<machine>.<tailnet>.ts.net, tailnet only (tailscale serve)
x86sim serve --bg --funnel          # the same address, public (tailscale funnel)
x86sim serve --bg --cloudflared     # a public https://*.trycloudflare.com quick tunnel
x86sim serve --cloudflared --cf-tunnel NAME --cf-host phones.example.com   # a named tunnel you set up
x86sim serve --listen 0.0.0.0:7380  # the LAN, plain HTTP
x86sim serve status | stop | stop cloudflared
x86sim serve link --phone work --ttl 2h          # a view-only link; --control to drive
```

It listens on loopback unless told otherwise and has no TLS of its own: remote access goes through Tailscale or
cloudflared, which bring HTTPS. Only a browser on this machine gets in without a token; everything else, tunnels
included, needs the token in the link. `--ttl` makes the printed links expire. Tokens and links are kept across
restarts of the server; `x86sim serve --bg` runs it as its own systemd user service. In the launcher, the globe button
beside a device's screen opens it in the browser, and its Share section turns tunnels on and off, copies links and
stops sharing. Tailscale must be logged in, with Serve (and Funnel) enabled for the tailnet; `x86sim serve` shows
the admin link when they are not.

## NixOS and containers

**NixOS.** Run the AppImage with `appimage-run`.
- **Vulkan:** the drivers in `/run/opengl-driver` are found by themselves.
- **No-root mode** needs `/opt` to exist, and NixOS has none. Create it once with `sudo mkdir /opt`, or permanently
  with `systemd.tmpfiles.rules = [ "d /opt 0755 root root -" ];`. Without it, Setup offers the install that asks for
  your password.
- **Overlayfs** may be built as a module. That is fine: a mount loads it.
- **App toolchain** (`x86sim dev setup`): its build tools must be inside `appimage-run`'s environment, not just
  installed on the system:

```nix
# nix-build this file, then run the AppImage with result/bin/appimage-run
(import <nixpkgs> { }).appimage-run.override {
  extraPkgs = p: with p; [
    gcc gcc.cc glibc.dev          # swift.org clang wants /usr/lib/gcc/<triple>/<ver> (crtbeginS.o, libgcc) and libc headers
    git zip unzip pkg-config curl
    openssl openssl.dev
    libimobiledevice libimobiledevice.dev libimobiledevice-glue libimobiledevice-glue.dev
    libplist libplist.dev libusbmuxd usbmuxd libusb1.dev
    xz.dev zlib.dev bzip2.dev libxml2.dev sqlite.dev curl.dev linuxHeaders
    (python3.withPackages (ps: [ ps.pip ps.virtualenv ]))
    libxml2 sqlite ncurses libedit zlib libuuid stdenv.cc.cc.lib
  ];
}
```

usbmuxd is only for a physical iPhone. If the Swift toolchain reports a missing `libncurses.so.6` / `libtinfo.so.6`,
`x86sim dev setup` links them into the toolchain.

**Containers (podman, docker).** Inside a container, Darling runs in nonroot mode: no namespaces, and each device's
prefix is a copy of the system image. This also applies where the container allows user namespaces but masks parts of
`/proc`, which a new process namespace then cannot mount. The overlay in the prefix falls back to fuse-overlayfs or to
a copy by itself. Run x86Sim there as an ordinary user, as toolbox and distrobox do: as the container's root, Darling
takes its root mode instead, which needs the namespaces the container does not give.
