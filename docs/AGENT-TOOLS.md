# x86Sim for AI agents

How an agent reads a device's screen as text and acts on it, text read from pixels, screenshots with marks, an
app's network traffic, and the MCP server's tools.
[skills/x86sim/SKILL.md](../skills/x86sim/SKILL.md) is the skill file that teaches a coding agent the loop.

## Agents: reading the screen and acting on it

An agent drives a running phone through the screen as text. `snapshot` lists the accessibility elements on screen:
the app in front (UIKit and SwiftUI), web pages it shows (links, buttons, fields, headings and text from the DOM),
and SpringBoard (alerts and other system UI on top, the home screen, the status bar). Each element gets a ref, its
role, label, value, identifier, states, and the point to touch:

```
device ram2 · 402x874 pt · front com.apple.Preferences
app com.apple.Preferences:
@e17 button "General" id=com.apple.settings.general (201,319)
@e18 button "Accessibility" id=com.apple.settings.accessibility (201,371)
@e28 searchfield "Search" (201,822)
status bar: 2:23 AM | Cellular: No signal | 100% battery power: Not charging
```

- **Refs are stable.** An element keeps its ref for as long as it is on screen, across snapshots and CLI calls,
  so an agent can act on a ref it saw a few steps back. `snapshot diff=true` shows only what changed (`+` new,
  `-` gone, `~` a label, value or state changed).
- **Actions answer with the result.** `tap`, `long_press`, `type`, `key`, `scroll`, `scroll_to`, `swipe`,
  `press`, `open_url`, `app_launch` and `app_terminate` wait until the screen has settled (no new frames and no
  transition still running) and answer with the next snapshot, or only the changes (`after: "diff"`), or nothing
  (`after: "none"`).
- **Targets**: a ref (`@e3`), an accessibility identifier (`id:com.apple.settings.general`), label text (exact,
  then prefix, then substring, with an alert over the app before the app beneath it), or `x`/`y` in points. An
  element the app has loaded but scrolled out of view is scrolled into view before it is tapped.
- **Typing** inserts text into the focused field as the software keyboard does, so any characters work (`clear`
  empties the field first, `submit` presses return). `keys=true` presses hardware keys instead.
- **`wait_for`** returns when a target appears (or, with `gone`, disappears). It checks again on every new
  frame rather than polling on a timer.
- **`screenshot`** returns the screen as an image, one pixel per point by default, so its coordinates match the
  snapshot's. `marks=true` outlines every element with its ref, `target` crops to one element (below).
- **Forms and controls**: `fill` types a whole form in one call (each field scrolled into view, tapped, focused,
  emptied and typed; optionally a submit). `set_value` sets a slider, switch, stepper, segmented control, picker
  wheel or date picker as a touch would. `drag` presses, holds to lift, moves and drops.
- **Checks**: `expect` checks a target's label, value, state or count and answers PASS or FAIL with what is there
  instead; `wait_for` takes the same conditions. Numbers in a target match exactly.
- **`batch`** runs several of these tools in one call and answers one line per step and the final screen.
- **Other UI kits**: Flutter apps show their semantics tree, SpriteKit and SceneKit scenes their named nodes, Unity
  games their objects (read through IL2CPP, also in stripped builds); the screen-reader switch is turned on for
  Unity, Unreal and Godot apps.

Each of these MCP tools takes `phone` (a name, a folder or a path). The same commands are on the command line:

```sh
x86sim --phone ram2 snapshot [--diff] [--all] [--json]
x86sim --phone ram2 tap @e17                 # or: tap "General", tap id:com.apple.settings.general
x86sim --phone ram2 type "hello@example.com" --submit
x86sim --phone ram2 scroll-to "Privacy & Security"
x86sim --phone ram2 wait-for "Wi-Fi" --timeout 10
x86sim --phone ram2 screenshot shot.png 3    # device pixels divided by 3: points on a 3x phone
x86sim --phone ram2 fill Email=me@example.com Password=s3cret --submit-tap "Sign In"
x86sim --phone ram2 set-value "Volume" 75%
x86sim --phone ram2 expect "Total" --contains "$42" --timeout 5
x86sim --phone ram2 snapshot --ocr            # also the text no element says, read from the pixels
x86sim --phone ram2 screenshot marked.png --marks actionable
```

On the command line, `tap X Y` and `swipe X1 Y1 X2 Y2` with plain numbers are device pixels, as before; targets
(refs, `id:`, text) are the way to use a snapshot's points. `find TARGET` shows what a target would match without
acting. [skills/x86sim/SKILL.md](../skills/x86sim/SKILL.md) puts it together for coding agents.

Snapshots come from host/simax, a reader loaded into every process that has UIKit
([docs/protocols/SIMAX.md](protocols/SIMAX.md)). On an iPhone 17, a snapshot that has settled takes about 10 ms in
Settings, about 15 ms on the home screen, and 25-35 ms for a long web page (about 130 elements).

### Text in pixels (OCR)

A view that draws its own pixels (Metal, OpenGL, SpriteKit / SceneKit, a game engine, a web page's `<canvas>`) has no
accessibility elements. When such a view covers a quarter of the screen and has no elements inside, the snapshot
reads its text from the frame: each phrase comes as a `text` element tagged `[ocr]` (`"ocr": true` in JSON) with a ref
that stays, and an `ocr:` line says which view, which frame and how long it took (about 0.1-0.4 s once per frame,
then cached). `snapshot --ocr` (MCP `ocr=true`) reads the whole screen and adds any text no element says. `tap`,
`wait_for` and `find` look in the pixels by themselves when no element matches; one or two letters read wrong still
match, numbers must match exactly. The home screen's wallpaper is not read.

How: `tools/launcher/core/src/ocr.rs`, the `ocrs` engine on the `rten` runtime (pure Rust, no system library); a picture
larger than the detection model's input is read in tiles. Its two models (text detection and line recognition, about 12
MB) are downloaded once into `~/.cache/x86sim/ocr` and checked against their SHA-256; offline, the `ocr:` line says what
to fetch. Latin script. `X86SIM_OCR=0` turns it off. Which views count as pixel views comes from simax (a view drawing
through a Metal or GL sublayer; [protocols/SIMAX.md](protocols/SIMAX.md)).

### Screenshots with marks

For agents that work from images (`tools/launcher/core/src/marks.rs`): `screenshot --marks` (MCP `marks=true`) returns
the frame in points with every element of the snapshot outlined and its `@ref` in a tag beside it;
`--marks actionable` marks only what `tap` acts on (controls, links, fields, `[ocr]` text). `screenshot --target @e7`
crops the picture to one element with a margin. Tags are placed where they overlap no other tag and are drawn with a
built-in bitmap font. The MCP answer carries the marked image together with the snapshot's text, so a tag seen in
the image is the ref to pass to `tap`.

### An app's network traffic

`net_capture` turns recording on for one app (it starts at the app's next launch: `relaunch=true`), `net_log` lists its
requests (method, status, URL, duration, size; filters such as `status:5xx`, `method:POST`, `error`, `mock`),
`net_request` shows one with headers both ways, bodies and timings (DNS, connect, TLS, first byte), and `net_mock`
answers matching requests without a server: a status and body, a delay, or a failure (offline, timeout, dns, refused,
reset). On the command line it is `x86sim net [PHONE] capture|log|show|mock`.

There is no proxy and no certificate to install: the recorder is an `NSURLProtocol` loaded into the app's own process
(`host/simnet`), so HTTPS is seen in the clear. It sees URLSession requests; other network stacks show as connection
records (libsimshim), and background-session transfers are not seen. It applies to third-party apps only. Files,
formats and what capture changes for an app: [protocols/NET.md](protocols/NET.md).

### Devices, apps and GPUs

`phones_list` lists every device with its state, whether it reached the home screen, whether it hangs, and the GPU
it renders on (`gpu_name`). `sim_add_device` / `sim_delete` create and delete devices, `sim_gpu` lists the host's
GPUs and sets a device's. `app_state` says what an app is doing (running, pid, foreground / background / suspended,
memory, CPU, how its last run ended), `app_launch` fails with the reason when the app did not start or died at once
(dyld's halts, abort reasons), and `app_terminate signal=kill` ends an app as a crash would.
`sim_record_video action=start|stop|status` records the screen in the background.

There is no MCP tool for the Apple Account sign-in: agents never get the user's credentials. `x86sim account` and the
launcher's Settings do that ([BUILDING-APPS.md](BUILDING-APPS.md#apple-account)).

Per platform:

- **iPad**: windowed apps (Windowed Apps, Stage Manager) are reported where they are on the display; `front` lists
  the top window's app first, SpringBoard's window controls and the windows behind it are an "app windows" group,
  and an element under another app's window is marked `[covered]`. Landscape, the software keyboard's keys,
  `key cmd+a`-style shortcuts and `pointer` (the iPad's mouse) work as on a device.
- **Apple TV** has no touchscreen: the snapshot names what has the focus (`focus: @e13 button "General"`), and `tap`
  moves the focus onto its target with the remote's arrows, checking after each press, then presses select, as
  XCUIRemote does; `scroll` and `swipe` move the focus, `press menu` goes back, `press tv` home. `type` writes into
  tvOS's full-screen keyboard.
- **Apple Watch**: the watch face and the app grid are the home screen; a text field's input sheet (keyboard,
  Scribble, dictation) is listed and `type` writes into it; `crown` scrolls.
- **Apple Vision Pro**: windows float in a rendered room, so a snapshot's points are each app's own window points,
  not display positions. `tap` acts through accessibility (the element's activate, else a tap made inside the app at
  its activation point, as VoiceOver does); `scroll` / `swipe` move the front app's scroll view; `press home` (the
  Digital Crown) opens the Home View. `pointer` drives the system pointer by display position.

## MCP server

`x86sim-mcp` is a [Model Context Protocol](https://modelcontextprotocol.io) server over stdio for AI agents and
other MCP clients.

```sh
claude mcp add x86sim -- /path/to/x86sim-*.AppImage mcp    # AppImage
claude mcp add x86sim -- /path/to/x86sim-mcp               # built from source (tools/launcher/target/release)
```

Tools that act on a device take `phone` (a name, a folder or a path); without it they use the only running device,
else the configured one. Erase, clone and keychain reset need it.

| Group | Tools |
|---|---|
| Devices | `phones_list` (`sim_status` is the same), `sim_devices`, `sim_add_device`, `sim_delete`, `sim_start`, `sim_stop`, `sim_restart`, `runtime_delete`, `aot_status` |
| Feature sets | `features_list`, `feature_get`, `feature_set`, `features_preset` |
| Apps | `app_install` (simulator or device builds), `app_uninstall`, `app_launch` (with `args` and `env`), `app_terminate`, `app_list`, `app_state`, `app_logs` |
| Tests | `xctest_run` (XCTest / XCUITest: an `.xctestrun` or bundles; per-test results, see [Tests](TESTING.md#tests-xctest-xcuitest)) |
| Debugging | `debug_start`, `debug_command`, `debug_stop` (an lldb session on an app, see [Debugging (LLDB)](DEBUGGING.md#debugging-lldb)) |
| Profiling | `profile_start`, `profile_stop` (CPU profile of an app, see [Profiling (CPU)](DEBUGGING.md#profiling-cpu)) |
| Network | `net_capture`, `net_log`, `net_request`, `net_mock` (an app's requests with headers, bodies and timings, and mock answers; no proxy: [protocols/NET.md](protocols/NET.md)) |
| Screen as text and actions | `snapshot`, `tap`, `long_press`, `type`, `fill`, `set_value`, `drag`, `key`, `scroll`, `scroll_to`, `swipe`, `pinch`, `wait_for`, `expect`, `batch`, `press`, `open_url`, `screenshot` |
| Accessibility Inspector | `ax_inspect`, `ax_audit`, `ax_action` |
| Hardware | `sim_button`, `sim_crown`, `sim_fold`, `sim_shake`, `sim_orientation`, `sim_biometric`, `sim_gamepad`, `sim_pointer`, `sim_system`, `sim_keyboard`, `sim_memory_warning` |
| Device services (as simctl) | `sim_location`, `sim_privacy`, `sim_push`, `sim_addmedia` |
| Settings (as simctl) | `sim_ui`, `sim_status_bar`, `sim_pasteboard`, `sim_keychain_reset`, `sim_locale`, `sim_timezone`, `sim_fidelity`, `sim_gpu`, `sim_erase`, `sim_clone` |
| Capture | `sim_screenshot` (a PNG file), `sim_record_video` |
| Pool | `pool_status`, `phone_take`, `phone_release` |
| Sharing | `share_start`, `share_stop`, `share_status`, `share_link` (they return the URLs) |
| Web content | `web_targets`, `web_eval`, `web_console`, `web_dom`, `web_network` (Safari's pages and inspectable WKWebViews, see [Web Inspector](DEBUGGING.md#web-inspector)) |
| Develop | `dev_status`, `dev_setup`, `dev_setup_cancel`, `dev_new`, `dev_projects`, `dev_build`, `dev_run`, `dev_test`, `dev_reload`, `dev_device`, `dev_ship`, `dev_convert` |

103 tools in all (`tools/list` of `x86sim-mcp` at v0.7.2).
