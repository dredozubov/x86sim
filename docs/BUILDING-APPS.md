# Building and shipping apps on Linux

x86Sim runs and tests apps. The other half of iOS development without a Mac, building, signing, installing on a
real iPhone and publishing, is [omarchy-apple-dev](https://github.com/joshuaswarren/omarchy-apple-dev). x86Sim
carries our fork of it ([x86sim/omarchy-apple-dev](https://github.com/x86sim/omarchy-apple-dev)) in
`external/omarchy-apple-dev`, and wraps it as `x86sim dev` (`x86sim-dev`, `tools/launcher/core/src/dev.rs`), the
launcher's **Develop** page and the MCP server's `dev_*` tools. Everything builds on Linux; no step runs on a Mac.

```sh
x86sim dev status                     # Swift, xtool, the iOS SDK, device tools, the optional pieces: what is ready
x86sim dev setup                      # install what is missing (no root): Swift from swift.org if there is none,
                                      # xtool, rcodesign, ipsw, pymobiledevice3, then a test build
x86sim dev setup sdk --xip ~/Downloads/Xcode_27.xip   # the iOS SDK, from Apple's Xcode download (free Apple ID)
x86sim dev setup xcode                # or: download Xcode.xip with the Apple Account sign-in, then the SDK from it
x86sim dev new HelloApp               # a SwiftUI app (xtool new), set up for iOS, tvOS, watchOS and visionOS
x86sim dev build HelloApp             # a simulator build; the .app's path is the last line
x86sim dev run HelloApp --phone QA    # build for that device's platform, install and launch: the edit-run loop
x86sim dev test HelloApp              # the same, then check it still runs and take a screenshot
x86sim dev test --xctest MyPackage    # a Swift package's XCTest / Swift Testing tests, built here, run on the device
x86sim dev device | ship | ship-mac | convert | auth   # real iPhones, App Store / TestFlight, Xcode projects
```

`x86sim dev help` lists every command. `--bg` runs a setup step in the background (one at a time; the Develop page
and MCP `dev_status` show its progress, `x86sim dev job --follow` its log).

## What a project can be

`x86sim dev build` / `run` hand the directory to the fork's `tools/build-project`, which detects the project's kind
(`tools/buildproject/detect.py`; the first rule that matches wins) and runs every step that kind needs. x86Sim holds
the build lock, keeps the log, and then installs and launches the `.app`.

| Project | Detected by | How it builds | Setup beyond `x86sim dev setup` | Checked by |
|---|---|---|---|---|
| Swift package app (Swift, SwiftUI, Objective-C, C, C++) | `Package.swift` + `xtool.yml` | `ship.sh --simulator` (Swift and xtool) | none | `x86sim dev setup verify` |
| Kotlin Multiplatform | an xtool app whose `xtool.env` names `KMP_GRADLE_ROOT` | `kmp/build-app.sh`: Gradle, Kotlin/Native's link for `ios_simulator_arm64`, then the app | Gradle | `tests/dev/kmp_e2e.py` (a Compose Multiplatform counter) |
| Xcode project or workspace | an `.xcodeproj` / `.xcworkspace` | Apple's open-source Swift Build through the fork's `linux-bin/xcodebuild` (scheme `$XCODE_SCHEME`, else the project's name) | `x86sim dev setup swiftbuild` (about 220 MB) | `tests/dev/xcode_e2e.py` (Objective-C, mixed workspace, widgets and watch apps, Swift packages) |
| Carthage | a `Cartfile` next to the Xcode project | `carthage bootstrap`, then the Xcode build | `x86sim dev setup carthage` (Carthage built from source) | `tests/dev/deps_e2e.py` |
| XcodeGen | `project.yml` | `xcodegen generate`, then the Xcode build | `x86sim dev setup xcodegen` | `tests/dev/deps_e2e.py` |
| Tuist | `Project.swift` importing ProjectDescription | the manifests evaluated with Tuist's ProjectDescription built for Linux, the project written by XcodeGen, then the Xcode build | `x86sim dev setup tuist` (needs xcodegen) | `tests/dev/deps_e2e.py` |
| CocoaPods | a `Podfile` | `pod install` (`x86sim dev pod ios install`), then the workspace | `x86sim dev setup cocoapods` (a pinned Ruby and CocoaPods in your home directory, about 70 MB) | `tests/dev/rn_e2e.py` |
| React Native, Expo | `package.json` with `react-native` / `expo` | npm install, `expo prebuild`, `pod install`, the CocoaPods workspace built by `tools/xcbuild.py`; iPhone and iPad only | cocoapods; node / npm | `tests/dev/rn_e2e.py` (a fresh Expo app, a bare React Native app) |
| Capacitor, Ionic | `package.json` with `@capacitor/ios` (or `@capacitor/core` and a `capacitor.config.*`) | `npx cap add/sync ios` writes the Xcode project, then the Xcode build | swiftbuild; node / npm | `tests/dev/shells_e2e.py` |
| Cordova | `package.json` with `cordova-ios`, and `config.xml` | `cordova prepare ios`, then the Xcode build | swiftbuild; node / npm | `tests/dev/shells_e2e.py` |
| NativeScript | `package.json` with `@nativescript/ios` | the fork's `shells/nativescript/ns` prepares `platforms/ios` with a Linux-built metadata generator, then the Xcode build | swiftbuild; node / npm | `tests/dev/shells_e2e.py` |
| Godot 4 | `project.godot` | `shells/godot/export.sh` exports for iOS; always a device build (the template's simulator library is x86_64 only), converted for the simulator at install | swiftbuild; Godot and its iOS export template | `tests/dev/shells_e2e.py` |
| Unity | `ProjectSettings/ProjectVersion.txt` + `Assets/` | `shells/unity/build.sh` exports (IL2CPP), then the Xcode build for the arm64 simulator | swiftbuild; the Unity editor for Linux with iOS Build Support and a license (`UNITY_EDITOR` / `UNITY_HOME`) | `tests/dev/shells_e2e.py --only unity` |
| Rust | `Cargo.toml` (or `src-tauri/Cargo.toml`) with a `[package]` name | cargo for `aarch64-apple-ios-sim` with the Darwin SDK and `ld64.lld`, then the `.app` (`rust/build.py`) | `rust/setup.sh` (rustup targets) | `tests/dev/rust_e2e.py`: UIKit through objc2, Tauri 2, Dioxus mobile, Bevy |
| .NET for iOS, MAUI | a `.csproj` whose target frameworks include `net*-ios` | `dotnet/build.sh`: the iOS workload on Linux, NativeAOT | `external/omarchy-apple-dev/dotnet/setup.sh` | `tests/dev/dotnet_e2e.py` (a UIKit counter in C#) |
| Flutter | `pubspec.yaml` | device builds only: `x86sim dev device` / `ship` (`flutter/build.sh`, `flutter/ship.sh`); `x86sim dev build` refuses and says so. A device build installs on x86Sim like any other (`x86sim install App.ipa`). Plugins that ship only a podspec build with CocoaPods | cocoapods for such plugins | |
| Bazel `rules_apple` | `MODULE.bazel` / `WORKSPACE` naming rules_apple | does not build on Linux yet; `x86sim dev build` names the reason (the fork's `bazel/README.md`) | | `tests/dev/deps_e2e.py` (the refusal) |

An Xcode project next to a `Package.swift` builds as the project. A `Package.swift` without `xtool.yml` is not an app
(add one: `version: 1` and a `bundleID`). Unreal Engine iOS projects do not build on Linux; the fork's
`docs/PROJECT-SHAPES.md` says what blocks them.

Notes per toolchain:

- **Xcode projects.** Swift Build is the build engine Xcode itself uses, with Xcode's build-setting specs: product
  types, embedding of extensions, watch apps and App Clips, signing, Info.plist processing, Swift packages. The fork's
  `linux-bin/xcodebuild` is the `xcodebuild` command line on top of it (`build`, `test`, `build-for-testing`,
  `test-without-building`, `archive`, `-exportArchive`, `-showBuildSettings`, `-list`), with `xcrun`, `xcode-select`
  and `fastlane` stand-ins beside it, so CI scripts, Makefiles and fastlane lanes run unchanged with `linux-bin` first
  on `PATH`. `xcodebuild test` runs the tests on an x86Sim device through `x86sim test` (the destination's `name=` or
  `$XCODEBUILD_PHONE` names it). Known gaps, from the fork's `swiftbuild/README.md`: UI-test targets (they need
  Xcode's XCTRunner.app), schemes Xcode would generate for a project without shared schemes (no test target), some
  App Intents metadata (the app then builds without its App Shortcuts registered, and says so), script phases that
  use BSD-only flags at absolute paths, and Interface Builder files the Linux `ibtool` refuses.
  `x86sim dev convert APP.xcodeproj` (`tools/xcodeproj2xtool.py`) turns a project into an xtool package for editing;
  it is not needed to build one.
- **React Native and Expo.** Debug builds load their JavaScript from Metro on the host, which the devices reach as
  their own localhost (port 8081); `x86sim dev run` starts it and edits arrive by Fast Refresh. `x86sim dev reload`
  reloads the JavaScript (`r` in Metro), `x86sim dev metro DIR --stop` ends Metro. `x86sim dev device` makes a
  Release device build and installs it with `xtool install`.
- **Linux versions of Xcode's tools.** `actool`, `ibtool`, `momc` and `xcstringstool` are included in the fork.
- **In the AppImage.** The AppImage carries the fork's scripts for every project kind above. Releases up to v0.7.2
  carried only the core ones (`ship.sh`, `device-run.sh`, `tools/`, `flutter/`, `kmp/`), see
  [RELEASE.md](RELEASE.md#2-what-goes-where); there, `X86SIM_OAD=<dir>` makes `x86sim dev` use a checkout of the fork.

## Real devices and publishing

- **Run on a device**: `device-run.sh` (`x86sim dev device`) pairs an iPhone, builds, signs, installs and launches the
  app over USB or the tailnet, attaches LLDB, streams its console and symbolicates crash reports.
- **Publish**: `ship.sh` (`x86sim dev ship`) builds a release `.ipa`, creates certificates and profiles, signs it and
  uploads it to App Store Connect and TestFlight (`--upload`). `ship-mac.sh` (`x86sim dev ship-mac`) does the same for
  macOS apps, with Developer ID signing and optional notarization.
- A device build made here also runs on x86Sim: `x86sim install` converts an `.ipa`, an `.xcarchive` or a device
  `.app` for the simulator ([USAGE.md](USAGE.md#device-builds)).

## Apple Account

One sign-in serves Xcode downloads and the dev toolchain's signing: `x86sim account` (`x86sim-account`,
`tools/launcher/core/src/account.rs`) and the launcher's Settings > Apple Account.

```sh
x86sim account login me@example.com          # password (no echo, never stored) and a two-factor code
x86sim account login --signing               # also sign xtool in with the same password entry, once
x86sim account status                        # who is signed in, what it can do, when it needs renewing
x86sim account download-xcode --list         # the Xcode releases this account can download
x86sim account download-xcode 27.2           # Xcode.xip (resumable), checked, then the SDK and the rest from it
x86sim account verify-xip Xcode_27.2.xip     # only the check
x86sim account logout
```

- **Sign-in.** Apple's web sign-in for developer.apple.com (idmsa.apple.com): SRP-6a with SHA-256, the password
  stretched with PBKDF2. Apple gets only the SRP proof; the password never leaves the process and is not stored.
  Two-factor is the code Apple pushes to the account's trusted devices, or an SMS (`sms` at the prompt). The session
  (cookies) goes into the Secret Service keyring (`secret-tool`), else a 0600 file under `~/.config/x86sim`. The
  account holder's name is neither kept nor shown.
- **Xcode download.** `download-xcode` takes the release from developer.apple.com's download list, downloads the
  `.xip` with curl into your download folder (a `.part` file resumes) and checks it before use: its size, the xar
  table of contents' checksum, Apple's signature (the certificate chain up to Apple Root CA, pinned by fingerprint)
  and the archived checksum of its content. Then it builds the dev SDK from it (`x86sim dev setup sdk --xip`; XCTest's
  frameworks come with it), takes Xcode's 3D device models (the iPhone Duo's, into `~/.local/share/x86sim/devicemodels`)
  and compares Xcode's device types with x86Sim's (`--update-devicetypes` writes `cli/lib`). The `.xip` is kept unless
  `--delete-xip`.
- **Signing.** xtool cannot use the web session: Apple's developer services want a GrandSlam token. `login --signing`
  drives xtool's own password sign-in once from the same password entry (and a second code if Apple asks), so the
  user signs in once. `x86sim dev auth` is xtool's sign-in by itself.
- There is no MCP tool for any of this: agents never get the user's credentials.

A free Apple ID is enough to download Xcode for the SDK and to install on your own device; TestFlight and the App Store
need a paid developer account. The toolchain installs into your home directory (`x86sim dev setup` passes the
installer `--user-only` and never runs sudo; when xtool's build needs system packages, `dev status` prints the
command for your distribution). `x86sim repos upstream-sync external/omarchy-apple-dev` reports how the fork stands
against upstream.
