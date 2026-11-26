# Debugging, profiling and Web Inspector

LLDB on an app in a running device, a CPU profiler, and WebKit's Web Inspector for Safari and web views. For an
app's logs, crash reports and network traffic see [USAGE.md](USAGE.md#command-line) and
[AGENT-TOOLS.md](AGENT-TOOLS.md#an-apps-network-traffic).

## Debugging (LLDB)

`x86sim debug` attaches LLDB to an app (or any process) in a running phone, as Xcode's Debug > Attach to Process:

```sh
x86sim debug qa com.example.myapp                       # attach to the running app: an interactive lldb
x86sim debug qa com.example.myapp --launch              # relaunch it stopped before dyld runs: break in main, +load
x86sim debug qa com.example.myapp --wait                # attach as soon as you start it
x86sim debug qa com.example.myapp --symbols build/MyApp.app.dSYM --batch -o 'breakpoint set -n viewDidLoad' -o continue -o bt
x86sim debug qa 1234                                    # a process by pid (x86sim pidof)
```

Breakpoints (by name, file and line, address), `step` / `next` / `finish`, `bt all`, `frame variable`, `register read`,
`memory read`, `image list` / `image lookup` (every image of the dyld cache, read from the process), and stops at
crashes (`EXC_BAD_ACCESS`, Swift traps as `EXC_BREAKPOINT`) work. Detaching removes the breakpoints and the app runs on.
The MCP tools `debug_start`, `debug_command` and `debug_stop` keep an lldb session per phone. `tests/lldb/run.sh
<phone>` checks it end to end, on iPhone, iPad, Apple TV, Apple Watch and Vision Pro (it builds the test app for the
phone's platform).

Which lldb: the Swift toolchain's (swift.org's, the one `x86sim dev setup` installs, or a distribution's `swift`
package) when there is one, so Swift is debugged as in Xcode: `frame variable` shows Swift structs, classes, arrays,
strings, dictionaries, optionals and enums, and `po` / `expression` evaluate Swift (`po self`, `expression point.x + 1`).
As installed it does not start on most desktops (it links the `libpython3.X` it was built with, 3.12 for Swift 6.4), so
the first `x86sim debug` sets it up, without root and without touching the system's Python (`x86sim dev setup lldb` does
the same beforehand, `x86sim dev status` shows it):

- a private CPython of that version (python-build-standalone's shared build, pinned by sha256, trimmed: about 75 MB) in
  `~/.local/share/x86sim-dev/swift-lldb/python-3.X`, used through `LD_LIBRARY_PATH` / `PYTHONHOME` for lldb only;
- `~/.local/share/x86sim-dev/swift-lldb/toolchain`, a view of the toolchain whose Swift resource dir is the Darwin one
  of the SDK `x86sim dev setup` built (the Linux one's module maps collide with the iOS SDK's, so `po` failed). It holds
  a copy of liblldb (lldb finds its resource dir from liblldb's real path): a reflink on btrfs / XFS (no space), else
  about 230 MB.

`x86sim debug` then points lldb at the phone's simulator SDK (`target.sdk-path`) and loads the app's dSYM (next to the
`.app`, or `--symbols`): Swift's type info comes from the dSYM's `__swift_ast` and the binary's reflection metadata
(`swiftc -g` makes both). Without the Swift toolchain it falls back to the host's `/usr/bin/lldb` (LLVM 17 or later) and
says so: C and Objective-C as above, Swift frames symbolized but Swift values only as raw memory.
`X86SIM_LLDB=/path/to/lldb` runs that lldb as is; `X86SIM_SWIFT_LLDB=0` skips the Swift one.

How: the app's arm64 code runs translated by libarm64jit, so no debugserver can see it. libarm64jit has a GDB remote
stub (`linux/arm64jit/gdbstub.cpp`) that speaks debugserver's dialect on `/run/user/<uid>/x86sim-dbg-<UDID>-<pid>.sock`.
It is off until asked for: `X86SIM_A64_DEBUG=1` (or `wait`) in the launch environment, or at run time a request file
and `SIGUSR1`. The stub reports an `os_version` per platform, so lldb keeps the right loader on tvOS, watchOS and
visionOS. Breakpoints are substituted in the translator's code fetch, never written to the app's memory.

Limits:

- **Swift**: needs the Swift toolchain (above) and a dSYM or the build's `.swiftmodule` for `po` / `expression`;
  without them `frame variable` still works from the reflection metadata. The first Swift expression in a session
  imports the app's modules from the SDK (some seconds). See the Swift row of `docs/PARITY.md` for what is checked.
- **Functions run natively** never hit a breakpoint: `objc_msgSend` (inlined by the translator), everything in
  libsystem_kernel, libsystem_platform and libsystem_pthread (system calls, `pthread_*`, `_platform_memmove`: Darling's
  native code behind stubs), `malloc` and friends, and a few accelerated routines (LZFSE, ASTC, Swift conformance
  scans). Stepping into one steps over it; a thread blocked in one shows the stub's `ret` as its pc.
- **No watchpoints**, and no hardware breakpoints (they are software ones).
- **A stopped app is a stopped app**: SpringBoard's watchdog may kill an app stopped at launch for long (Apple's
  simulator does the same); system daemons stopped for long can stall the phone.
- **Attach at run time** uses `SIGUSR1`, queued with a value the translator recognises (`host.cpp` `on_usr1`), so an
  app that handles `SIGUSR1` itself is reached too; a plain `kill -USR1` still goes to the app.
- With `--launch` the app's `+load` methods and initializers run after the first `continue`, so breakpoints there hit;
  images loaded later (`dlopen`) are reported to lldb as they load.

## Profiling (CPU)

`x86sim profile` samples an app's threads while they run on a CPU and shows where the time goes, as Instruments' Time
Profiler does:

```sh
x86sim profile qa com.example.myapp                          # 10 s: top functions + a speedscope file
x86sim profile qa com.example.myapp --secs 5 --format gecko  # Firefox Profiler (https://profiler.firefox.com)
x86sim profile qa 1234 --format text --out top.txt           # a process by pid; the text summary as the file
x86sim profile --raw ~/scratch/x86sim/profiles/raw-....txt --format speedscope   # symbolicate raw samples again
```

It prints the busiest functions by self and total time for the process and per thread, and how the time splits
between the app's (guest) code, native library functions and the translator, then writes the profile (default:
speedscope JSON under `$X86SIM_SCRATCH/profiles`, open it at https://www.speedscope.app). The MCP tools `profile_start`
/ `profile_stop` do the same around anything you do meanwhile (`profile_stop` answers the summary and the file), and
the browser viewer's **Profile 5 s** button (control links) downloads a profile of the app in front.

How: the sampler is in the translator (`linux/arm64jit/prof.cpp`), off until asked for and started at run time through
the debugger's request channel (a request file and `SIGUSR1`); nothing runs while no profile is taken. It counts each
thread's CPU time with `perf_event_open` (user mode, allowed at the default `perf_event_paranoid` 2) and takes one
sample per millisecond of CPU time: the exact host instruction, mapped back to the guest code block it belongs to, and
the guest frame-pointer chain. Symbols come from the simulator's dyld cache (which keeps every library's local symbols)
and the app's binary; C++ and Swift names are demangled. Overhead: none while off; about 1% with one busy thread
sampled at 1 kHz (`tests/profile/run.sh <phone> [--settings]`, on every platform, or `--standalone` without a phone,
checks it).

Limits:

- **Timings are of the translated x86-64 code**: relative costs differ from a device (floating point, atomics and
  `objc_msgSend` cost differently than on arm64). Time the translator spends on itself shows up as `[translator]`
  (compiling, libarm64jit) and `[translator: code cache runtime]` (the dispatcher between blocks).
- **Frame-pointer stacks only**: a leaf function without a frame shows its caller through LR; code built without frame
  pointers loses callers (Apple's arm64 code keeps them).
- A library function the translator runs natively (libsystem, `pthread_*`, `memmove`, `malloc`) is one `[native] name`
  frame; time blocked in a system call is not CPU time and is not sampled (nor is kernel time).
- Threads are named by their Linux name (`pthread_setname_np`); dispatch queue labels are not shown.
- No allocations / Leaks instrument.

## Web Inspector

Safari's pages and apps' web views can be inspected as from Safari's Develop menu on a Mac: WebKit's own Web
Inspector (Elements, Console, Network, Sources, Timelines, Storage, ...) opens in your browser.

```sh
x86sim inspect                      # the running phone's pages, and the inspector page in the browser
x86sim inspect qa --url example.com # straight to the inspector on the first page whose URL or title has it
x86sim inspect qa --list            # only list them (id, app, kind, title, URL)
```

The viewer of `x86sim serve` has the same under **Web pages…** (control links only: an inspector runs code in the
page). Agents get MCP tools that need no browser: `web_targets` (pages per app), `web_eval` (JavaScript, its value;
promises are awaited), `web_console` (the page's messages, then new ones for `follow_s`), `web_dom` (outerHTML of a
CSS selector or the document) and `web_network` (every request since the page loaded, then live ones). WebKit keeps
a page's console messages only from its first inspection on; `reload: true` reloads the page and collects its load's
console messages or requests (with status codes).

- Safari's pages are always inspectable. An app's `WKWebView` (or `JSContext`) is listed only when the app sets
  `isInspectable = true`, as in Apple's simulator.
- iPhone, iPad and Vision Pro have Safari and `WKWebView`. Apple TV has neither (no WebKit in tvOS): an app's
  inspectable `JSContext` is what there is to inspect (`web_eval`, `web_console`). Apple Watch has no web content to
  inspect.
- The phone side is the runtime's `webinspectord`, started on demand at the first inspect (the `webinspector`
  feature, on by default; nothing runs until then). Its socket is `/run/user/<uid>/x86sim-rwi-<UDID>.sock` and speaks
  Apple's Remote Web Inspector protocol (`tools/launcher/core/src/rwi.rs`). On a Mac launchd hands
  webinspectord that socket; here libsimshim binds the listener at the host-visible path instead (`shim_rwi_listen` in
  `host/simshim/compat/simshim.c`). webinspectord exits when its last debugger leaves and is started again at the
  next inspect.
- The frontend is WebKit's own (WebInspectorUI, as built in WebKitGTK 2.54.3). The AppImage carries it, so nothing
  needs installing. Lookup order: `X86SIM_INSPECTOR_UI` (a WebInspectorUI directory, e.g. a WebKit checkout's),
  the AppImage's copy, a checkout's `tools/launcher/target/webinspector` (made by `build/webinspector.sh`: a pinned
  WebKitGTK package, sha256 checked), then the host's WebKitGTK (webkit2gtk-4.1 or webkitgtk-6.0, extracted once into
  `~/.cache/x86sim/webinspector`). `x86sim serve`'s log names the copy in use. It is a newer or older WebKit than the
  phone's, so a panel may miss a command now and then. The MCP tools work without it.
