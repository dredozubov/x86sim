# Testing apps on x86Sim

XCTest and XCUITest runs, and the Accessibility Inspector (inspection, audit, actions). For driving an app as an
agent does (snapshots, `expect`, `batch`), see [AGENT-TOOLS.md](AGENT-TOOLS.md).

## Tests (XCTest, XCUITest)

`x86sim test` runs test bundles on a phone as `xcodebuild test-without-building` does in Apple's simulator, and the
MCP tool `xctest_run` does the same for agents:

```sh
x86sim test qa --xctestrun Products/MyApp_iphonesimulator27.2-arm64.xctestrun   # what build-for-testing wrote
x86sim test qa --xctestrun F.xctestrun --only-testing MyAppTests/LoginTests/testBadPassword --junit junit.xml
x86sim test qa --app MyApp.app                          # unit tests hosted in the app (its PlugIns/*.xctest)
x86sim test qa --test-bundle MyLogicTests.xctest        # logic tests (no host app)
x86sim test qa --ui-test-runner MyAppUITests-Runner.app --app MyApp.app        # XCUITest
x86sim test qa --spm MyPackage                          # a Swift package's tests, built here (x86sim dev test --xctest)
```

- **Unit tests hosted in an app**: the app is installed and launched with `libXCTestBundleInject.dylib`, which loads
  the bundle into it, as Xcode does. **Logic tests** run in the `xctest` tool. **UI tests**: the runner and the app
  under test are installed and the runner's `XCUIApplication` launches, queries and taps the app through the
  runtime's `testmanagerd` (the phone's `xctest` feature, on by default, started only when a UI test runs; ~440 MB
  while it runs).
- Each test process gets the `.xctestconfiguration` Xcode would write (selection, target app, environment from the
  `.xctestrun`), without an IDE session. Results: XCTest's log as it runs (Swift Testing's too), a summary with each
  failure's `file:line` and message, `junit.xml` and `results.json` (per test: passed / failed / skipped, duration,
  failures) in `$X86SIM_SCRATCH/xctest/<phone>-<time>/`; exit status 0 when nothing failed, 1 otherwise.
- **Where the bundles come from**, built on Linux:
  - a Swift package: `x86sim dev test --xctest` / `x86sim test --spm`, which build its tests (`swift build
    --build-tests` for the device's simulator) with the `x86sim dev` toolchain and run them;
  - an Xcode project or workspace: the dev toolchain's `xcodebuild` stand-in on Apple's Swift Build
    (`external/omarchy-apple-dev/linux-bin/xcodebuild`, after `x86sim dev setup swiftbuild`). `xcodebuild
    build-for-testing` writes the products and the `.xctestrun`, and `xcodebuild test` goes on to run them on an
    x86Sim device through `x86sim test` (the destination's `name=`, or `$XCODEBUILD_PHONE`, names the device). Unit
    test targets build (XCTest and Swift Testing). UI-test targets do not: they need Xcode's XCTRunner.app, which the
    SDK made from Xcode.xip does not carry. A project without shared schemes gets generated schemes that leave its
    test target out: share the scheme. A fastlane lane's `scan` runs the same way (`tests/dev/xcode_e2e.py`).
  - Bundles Xcode itself built also run: copy `xcodebuild build-for-testing`'s `Build/Products` directory with the
    `.xctestrun`. That is how UI test runners get here today, and what the XCTestDemo fixture checks on purpose
    (`tests/apps/XCTestDemo/build.sh` runs `xcodebuild` on the comparison Mac, so that the test is of bundles made by
    Xcode, not of our build).
- **XCTest's frameworks** (`XCTest.framework`, `XCTestCore`, `XCUIAutomation`, `libXCTestBundleInject.dylib`) are
  Xcode's, not the runtime's: `x86sim test` takes them from the Darwin SDK `x86sim dev setup sdk --xip Xcode.xip` builds
  on Linux (Xcode.xip from developer.apple.com, a free Apple ID; Apple publishes no XCTest download without one),
  `sdks/<Platform>.platform` (`x86sim test fetch-platform` copies them there) or `--platform DIR`.
- **Every platform**: `tests/apps/XCTestDemo` builds for iOS, tvOS, watchOS and visionOS (`X86SIM_PLATFORM=tvos
  tests/apps/XCTestDemo/build.sh`; `run.sh <phone>` picks the phone's). Its unit, logic and UI tests give Apple's
  results on iPhone, iPad, Apple TV, Apple Watch and Vision Pro.

`tests/apps/XCTestDemo/run.sh <phone>` runs the fixture (hosted unit tests, logic tests, UI tests, each with a
deliberate failure) and checks every result against Apple's simulator.

## Accessibility Inspector

What Xcode's Accessibility Inspector does, for any app on a phone:

- **Inspection.** In the browser viewer (`x86sim serve`) and the launcher's phone page, *Inspect* outlines the element
  under the mouse; a click shows its properties: label, value, hint, traits, identifier, frame, activation point,
  actions and custom actions, custom rotors, input labels, language, whether it responds to user interaction, its
  class, view and view controller, the accessibility hierarchy above it, and its text's font, color and whether it is
  cut off. `x86sim ax-inspect [TARGET | X Y]` (MCP `ax_inspect`) prints the same.
- **Audit.** `x86sim ax-audit [PHONE]` (MCP `ax_audit`, the viewer's and the launcher's *Run audit*) checks the app in
  front: controls and images without a label, labels that are file names, SF Symbol names or identifiers, touch
  targets under 44 x 44 pt (60 on Vision Pro), text contrast under WCAG 4.5:1 (3:1 for large text: the app's text
  color against the background sampled from the screen), text cut off, Dynamic Type (`--dynamic-type`: the screen
  again at the largest accessibility text size, which is set for the check and put back), duplicate labels, controls
  and tap targets VoiceOver cannot reach, and views that take taps without the button trait. Each finding has a
  severity, the element's ref and frame and a fix; `--json` for tools.
- **Actions.** `x86sim ax-action NAME [TARGET]` (MCP `ax_action`, the inspector's buttons) does what VoiceOver does:
  activate, increment, decrement, scroll (`--dir`), escape, magic tap, and custom actions by name. They need no
  point on the screen, which helps on Apple TV and Vision Pro.

```sh
x86sim ax-audit qa                       # the app in front on phone qa
x86sim --phone qa ax-audit --dynamic-type --json
x86sim --phone qa ax-inspect "Message from Anna"
x86sim --phone qa ax-action custom "Message from Anna" --name Reply
```

`tests/apps/x86a11ybad` is a screen that breaks each rule on purpose. The data comes from simax's full tree
([docs/protocols/SIMAX.md](protocols/SIMAX.md)). Font, color and truncation are read from UIKit labels; for
SwiftUI text the contrast comes from the pixels alone, and clipping is not seen.

Per platform: Apple TV and Apple Watch get no touch-target check (the focus engine, the watch's own sizes), Vision
Pro checks 60 pt and no contrast (a window's place in the room is not known), and its frames are each window's own
points, so the viewer's inspector lists the elements instead of outlining them on the screen.
