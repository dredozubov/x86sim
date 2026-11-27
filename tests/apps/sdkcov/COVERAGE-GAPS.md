# sdkcov coverage gaps: towards complete SDK coverage

Goal: every public framework of each platform SDK (manifest-<plat>.json = the Xcode 27.2 simulator SDK framework list, incl. sdks/XRSimulator-xcode.sdk for visionOS) has functional checks exercising its main public API with real assertions, matching Apple's simulator (the bar, not hardware). Machine-readable: `coverage-gaps.json` (`{platform: {framework: {status, existing_checks, gaps, package, rejudged, used_inside?, apple_sim_na?, apple_sim_na_done?, api_unavailable?, sdk_availability?, note?}}}`).

Refreshed 2026-11-18 (r29 round: 14 P25 checks / ports / input modes for the last [a] gaps, every one = Apple except where noted: RelevanceKit relevance() on invalidateRelevance (asked with the widget placed, never without; iPhone and iPad), Health's sheet answered by touches on iOS (Apple shows it ~80 s into a fresh boot) and watchOS (HealthKitUI trigger), PHPicker selection by a tap, VisionKit Live Text selection, a control placed in Control Center by touches (its intent never runs on either: iOS ControlWidget intents now [c]), an AVRoutePickerView tap (nothing presented, the discovery extension never starts), the BrowserEngineKit objects on iOS, PassKit per-button ink, a watchOS toolbar button, the watch photos picker ("Unable to Load Photos in Simulator" on both: [c]), widget placement on the iPad; Darling now opens /.vol/<fsid>/<id> paths (volfs) and fpsim2host answers sim2host protocol version 1 as Apple's Mac does (no sim_openByID calls; Files, document picker, DocumentGroup, FSEvents unchanged); found, open: File Provider eviction refused by x86Sim (nonEvictable -2008 after the same stale post-materialization docID lookup that causes the double fetch: /.vol was not its cause), watchOS currentConfigurations empty where Apple's fresh watch lists the widget, visionOS chronod asks relevance() with no widget placed; r28 round: every remaining [a] gap classified: SDK-unavailable ones dropped (tvOS / visionOS ControlWidget, tvOS WidgetRelevance and photo pickers, watchOS PHPicker / credential provider extension, watchOS / visionOS call directory), [c] where Apple's simulator can't (Siri intent handling, Messages for Business, iOS credential provider objects, ClockKit data sources), new tag [d] where the input or host feature exists on neither side here (visionOS gaze / pinch, Simulator.app pointer capture and CarPlay display, a KDC, a pass signing certificate, host audio device changes), stale gamepad gaps removed; 7 P24 checks / ports, no x86Sim bug found, every one = Apple: GCKeyboard keys on tvOS / visionOS, watchOS LocationButton tap and List swipe actions (revealed as buttons, a full swipe runs none), the notification service extension on watchOS / visionOS (never runs on either), a ComputeGraphResource on an entity (iOS / tvOS / visionOS); GCMouse moves on the iPad x86Sim only (Apple unreachable); r27 round: 5 P23 checks / ports, no x86Sim bug found, every one = Apple: a widget placed on the home screen by touches (inputs.sh widget, ref-mac.sh PRE=) reaches currentConfigurations and reloads its timeline, UIKit scene lifecycle on tvOS (sdkcovDoc built there), watchOS app lifecycle by the Digital Crown + a host launch, the CryptoTokenKit token extension on tvOS / watchOS (no driver configuration on Apple) and visionOS, GCKeyboard key input; r26 round: 9 P22 checks + the DocumentGroup check ported to visionOS, no x86Sim bug found, every one = Apple on every platform it runs on: UIKit scene lifecycle through the companion app sdkcovDoc (iOS: Apple's notification order; visionOS: the scene stays foreground-active), sdkcovDoc + DocumentGroup on visionOS, a CryptoTokenKit persistent token extension (keychain items under the token id; the extension itself never launched on either), BackgroundAssets foreground download from a loopback TLS server, CIKernel from a compiled Metal library (Metal Toolchain on the reference Mac), CompositorServices layer configuration, VenueDescriptor cameras, AVKit full screen on playback (never entered for app-started playback), watchOS chapters / playback stall from bundled movies; r24 round: 2 x86Sim bugs fixed, both visionOS daemons missing from boot-a64's job list: webbookmarksd (SSReadingList.addItem killed the app in about half the runs: the invalidated WebBookmarks connection's handler raced the add, libxpc API misuse on a nil message) and medialibraryd (MPMediaQuery died on a never-created music library database); 17 P20 checks / ports: HTTP/2 over loopback TLS, GKScene from .sks, CoreImage HEIF / RAW answers / text detector, authorized media library queries, service worker and WKWebExtension, AVContentKeySession clear key, ComputeGraph pipelines + simulation step, ARView nonAR, RealityView attachments, watchOS SwiftUI controls and SceneKit particles, FamilyActivityPicker, input checks for a PencilKit stroke, a LocationButton tap and a biometry keychain item; ref-mac.sh BIOMETRIC=1 drives Face ID on Apple's simulator (its visionOS one never enrolls Optic ID); every new check = Apple; r23 round, breadth: 29 P19 checks / ports / pinned answers for [a] gaps on all four platforms (CreateMLComponents pipeline write/read, ShaderGraphMaterial, Chart3D, Bluetooth MIDI views, voice-shortcut sheet, broadcast picker, Translation batch, AVAudioSession route changes, LinkPresentation og:video, LiveCommunicationKit, unpaired live photo, EventKitUI / ContactsUI editors through their delegates, CoreLocation updates, communication notification content, AutoFill provider objects, a Quick Look preview extension + editing mode, tvOS SwiftUI / UIKit menus, context menu, secure field and text input, watchOS DatePicker, visionOS hotspot / Reading List, CSUserQuery / PDF outline / DevicePicker / enterprise license answers pinned, FSEvents on tvOS / watchOS / visionOS); gaps for APIs missing from the SDK dropped (tvOS saved-activity deletion, watchOS CFHTTPMessage and UIKit, visionOS musicSubscriptionOffer / SFAuthenticationSession, iOS / visionOS LAAuthenticationView); Apple's fresh simulator brings EventKitUI / ContactsUI / Quick Look view services up slowly (checks wait for them); found, open: visionOS SSReadingList.addItem dies in libxpc in about half the x86Sim runs (XPC API Misuse from SafariServices); File Provider double fetch: answering sim2host protocol version 1 (Apple's path, fileproviderd opens /.vol/<fsid>/<id> itself) needs /.vol paths in Darling: without them the root folder fault retries forever, so still open; every new check = Apple; r22 round: the iPad notification prompt "never shown" by Apple was timing: SpringBoard's notification server starts ~135 s after a boot on Apple's simulator (iPhone and iPad), the iPad check now taps Allow as on the iPhone (= Apple with WAIT=150); P18 checks on all four platforms: Charts axis value labels by pixels (the trailing "100" dropped on both simulators), MKMapItemRequest for an unknown place id (MKError 5); every new check = Apple; File Provider double fetch narrowed, still open: the post-operation lookup reads the materialized file once with correct attributes, then waits 6.2 s without touching the file system; r21 round: Files showed a File Provider file 12/31/69 after its download: x86Sim fetches it twice (fileproviderd's docID lookup right after sim_materializeFile times out; open, asserted: Apple fetches once and keeps the date); fixed on the way: Darling document ids now follow renames / RENAME_SWAP as on APFS, atomic FSIOC_CAS_BSDFLAGS, the APFS mark-purgeable fsctl, fpsim2host flag races and materialized-file times; P17 checks: Call Directory extension (Apple: error 0, its store path is on the Mac; x86Sim answers disabled: open), iMessage app extension, WebPage navigation decider, Charts scrollable axes by pixels, an extra UIWindow (shown on visionOS too, both simulators); ncontent on the iPad (Apple's iPad simulator never shows the notification prompt: asserted); ActivityKit push token = Apple; tvOS / watchOS SwiftUI, StoreKit review and tvOS Speech buffer gaps dropped as SDK-unavailable; r20 round: 2 x86Sim bugs fixed: a long press in the Files browser (any pushed collection view) acted as a tap: simhid marked every no-edge touch SwipeLocked, which UIKit makes UITouch _edgeType 4, so the navigation edge-swipe pan never failed on a still finger (Apple: Range|Touch only); Files opened by shareddocuments: was killed at launch: Darling statfs(NULL) did strcpy from NULL (EFAULT on Darwin); P16 checks: UIKit collection view context menu on a navigation stack and FileProviderUI through Files (the extension handed -1000 for the domain-less location; Apple's Files never offers the custom action) on iPhone and iPad, PHASE occluder + ambient mixer, Charts rule mark by pixels, RealityKit VideoMaterial, SwiftUI TipView on tvOS / watchOS, ActivityKit push token answer, LinkPresentation icon provider, ComputeGraph assembly and INInteraction deletes asserted; P14 touch / P15 checks run on the iPad and P15 on tvOS / watchOS / visionOS; every new check = Apple; r19 round: 1 x86Sim bug fixed: ScreenTimeAgent spun ~90% CPU on iOS retrying its Catalyst connection to dmd, which Apple's simulator runs (boot-a64 job added); P15 checks: SwiftUI DocumentGroup through a companion document app (sdkcovDoc), a custom SwiftData DataStore, Screen Time configuration observer / web page controller state, MetricKit signposts vs the log store, RealityFoundation entities; tvOS INInteraction delete answers asserted; MTRegisterProfessionalVideoWorkflowFormatReaders is macOS-only; every new check = Apple; r18 round: touch input on both simulators (inputs.sh ctxmenu / swipe / sdrag / ncontent here, ref-mac.sh INPUT= Indigo touches on the Mac): SwiftUI contextMenu long press, List swipeActions, Transferable drag and drop, and a notification expanded by touch (Apple's simulator never launches the content extension: asserted); NLModel, MLState and a custom sound classifier from small models trained on the Mac (all four platforms); 1 x86Sim perf bug fixed: fp16 vector FMLA ran Dynarmic's soft-float per lane (MusicUnderstanding rhythm 121 s -> 20 s); every new check = Apple; r17 round: 39 P13 checks / ports for [a] gaps on all four platforms (braille tables, Metal parallel encoder + stencil, MPS conversion / LU, MTKMesh, light probe, display link, CIDetector, secure text field, context menu interaction, IndexedDB, find navigator, ProRes / multi-pass, loopback HTTP proxy, movie thumbnails, SCNAudioSource, GLKView, IOSurface sharing, PDFView selection, beacon ranging, caching image manager, ReplayKit recording, GameKit errors, caption notification, export limit, RemoteIO callback, marker views, Reading List, File Provider pushes, review request, LP cancel, tvOS/visionOS ports), 3 reported-only checks now asserting, tvOS P4 CoreData/StoreKit/SwiftData run on x86Sim; every new check = Apple, no x86Sim bug found; MessageUI compose init and tvOS PDFView kill the app on Apple too; r16 round: 2 x86Sim bugs fixed (visionOS Vision optical flow = CoreImage stitchable kernels: libComposeFilters dlopen through a symlinked /System directory; microphone capture: simaudio duplex aggregate), 18 P12 checks / ports for [a] gaps (BNNS Graph, microphone, SwiftUI toolbar/menus/popover, @Query hosted, TipKit, AHAP, Speech buffer, AccessibilitySettings, CGShading/CGPattern, watchOS source node, iOS accessory background); r15 round: 19 P11 checks for [a] gaps of covered frameworks on all four platforms, 1 x86Sim bug fixed (ShazamKit library: shazamd), 1 found (visionOS optical flow), the visionOS audio mismatches were a boot without audio (= Apple with X86SIM_AUDIO=1), LAPACK on all four; r14 round: 2 x86Sim bugs fixed (AlarmKit prompt; iOS document picker empty since the 2026-11-16 Darling merge: getfsstat lost its mount names), Accelerate LAPACK check; r13 round: AppClip covered, AlarmKit Apple-sim N/A done, 1 x86Sim bug found (AlarmKit prompt); r12 round: 2 x86Sim bugs fixed, 22 platform entries moved: 11 to covered, 11 to Apple-sim N/A done; before it the thin/trivial round moved 23; first pass: commit 4dfb0f4, 2026-11-15). Inputs: 838 distinct framework check ids in checks/*.swift (was 381; +457 from P1..P8, the gaps/FSEvents/FoundationModels rounds and More2 on all platforms); which ids run on which platform and their x86Sim + Apple-reference results = every sdkcov result under ~/scratch since 2026-11-15 (results.txt / sdkcov-N.err of the comb2, P-round, gaps, fse, fm and *-ref-* runs: ios 618, tvos 389, watchos 280, xros 500 ids). Every framework whose check set changed was re-judged from the check bodies (`rejudged: true`); the rest keep their first-pass judgement. Libraries (usr/lib) are out of scope.

Round 30 (2026-11-26): API depth. Every framework already had checks, so this round measures public types: `apisurf.py <platform>` counts the ObjC `@interface`s in each framework's headers and the top-level public Swift types in its `.swiftinterface`, and which of them the app's sources use. Referenced public types, before -> after: iOS 1374 -> 8346 / 8399, tvOS 1017 -> 6880 / 6943, watchOS 912 -> 6245 / 6291, visionOS 1215 -> 7698 / 7769. What is left is unavailable on that platform (macOS-only SwiftUI / AVKit / AVFAudio / ManagedAppDistribution types), `NonSendableClass` (a name in a Foundation header comment) and RealityFoundation's empty `InternalBindPath`. New checks in `checks/P27_*.swift` (UIKit, SwiftUI, Media, Data, Services) and `checks/P28_*.swift` (SwiftUI, Intents, AV, ML3D, Tail): constructed, used and asserted; families of value classes (Matter's 1490 cluster types, Intents' 307 classes, MetricKit, Sensor/HealthKit samples) table-driven (construct, set and read back, copy, secure coding). Quick tests (`--only`) of each file on x86Sim and Apple (`ref-mac.sh --only`): equal except the x86Sim differences marked (r30) below. x86Sim fixes: boot-a64.sh runs merchantd (ProximityReader), webbookmarksd on iOS (SFSafariExtensionManager.stateOfExtension never answered; Apple SFErrorDomain 1; the content blocker 4099 is Apple's answer too), itunescloudd (MusicKit; iOS, visionOS), sensorkitd (SensorKit) and biomed (AppIntents relevant entities via CascadeSets; iOS, visionOS) on demand; Darling's iokitd publishes the Neural Engine node IODeviceTree:/arm-io/ane (ane-type 0x40, as every Apple-silicon host: MobileGestalt HasAppleNeuralEngine, so Vision picks the E5RT path and person segmentation answers VNError 1 as on Apple, not 9 from the Espresso path); Darling answers the security.mac.sandbox.sentinel sysctl (`.sb-` + 8 hex digits per boot, as on the Mac: libsystem_sandbox's _amkrtemp names MediaToolbox's multi-pass temp file with it, so AVAssetWriter startWriting failed -3000 / -12148 without it); Darling's proc_pidinfo short BSD info says PROC_FLAG_LP64 (was P_LP64 = 0x4, PROC_FLAG_INEXIT there: logd marked every process 32-bit in the tracev3 catalog, so OSLogStore decoded %ld / %p arguments as undefined and `log show` printed `<decode: mismatch ...>`); simshim's exception hook no longer sends -name to an NSError (Core Image's barcode generator raised and caught its own NSError).

Status: **covered** = real assertions on the main API and its main areas; **thin** = real checks but main areas untested; **trivial** = only existence / availability / authorization status / construction, or values reported but not asserted; **none** = no check on that platform; **apple-sim-na** = the main API cannot work in Apple's simulator (hardware, entitlement, missing service): the check must assert the simulator answer (*done* when such an asserting check passes on Apple, *open* otherwise); **api-unavailable** = the SDK marks the whole public API unavailable on that platform (Swift `@available(<os>, unavailable)` / `API_UNAVAILABLE(<os>)` on every declaration; visionOS inherits iOS unavailability): only loading is possible, the load check covers it; **excluded** = headers-only / re-export-only / not in the runtime.

Gap tags: **[a]** doable as a check; **[b: ...]** blocked by an x86Sim bug (named); **[c]** Apple's simulator can't do it - assert its answer; **[d: ...]** needs input or a host feature neither x86Sim nor the reference Mac setup provides (named); **[run]** no new check needed, a run is missing or stale.

## Counts per platform

| platform | frameworks | covered | thin | trivial | none | apple-sim-na (done / open) | api-unavailable | excluded |
|---|---|---|---|---|---|---|---|---|
| iOS/iPadOS | 285 | 199 | 4 | 0 | 0 | 75 (75 / 0) | 0 | 7 |
| tvOS | 167 | 133 | 0 | 0 | 0 | 18 (18 / 0) | 10 | 6 |
| watchOS | 140 | 111 | 0 | 0 | 0 | 15 (15 / 0) | 11 | 3 |
| visionOS | 230 | 170 | 5 | 1 | 0 | 38 (38 / 0) | 9 | 7 |

First pass (2026-11-15) for comparison:

| platform | covered | thin | trivial | none | apple-sim-na | excluded |
|---|---|---|---|---|---|---|
| iOS/iPadOS | 81 | 24 | 47 | 98 | 29 | 6 |
| tvOS | 80 | 22 | 23 | 30 | 6 | 6 |
| watchOS | 46 | 15 | 14 | 52 | 10 | 3 |
| visionOS | 69 | 27 | 35 | 77 | 16 | 6 |

Not counted (Swift runtime modules, not SDK frameworks, all covered): Swift, Dispatch, Observation, Distributed, os.

## Remaining actionable work, by area

Entries = framework [platforms] with status thin / trivial / none / apple-sim-na *open*. Full gap text in the tables below.

### P3 App extensions, system services, communication & parental controls

2026-11-18 r16: WatchConnectivity visionOS isSupported() false asserted (Apple-sim N/A done). 2026-11-18 r14: AlarmKit prompt fixed on x86Sim (BaseBoard's system-partition test answered as on Apple's cryptex-mounted runtime). 2026-11-18 r13: App Clip launched by the host with _XCAppClipURL (covered), AlarmKit request/schedule asserts Apple's instant denial (Apple-sim N/A done; x86Sim shows the prompt: open bug). 2026-11-17 r12: ManagedSettingsUI default shield, DeviceActivity report placeholder, AccessoryLiveActivities unpaired refusal (Apple-sim N/A done), ExtensionFoundation watchOS Apple-point refusal, NotificationCenter widget update. Left: system-UI-only extensions (FileProviderUI from the Files app; UserNotificationsUI iOS done r18 by touch: Apple's simulator never launches the content extension), WidgetKit visionOS timelines (needs a placed widget), BrowserEngineCore visionOS (C-only BEMemory).

- **thin**: FileProviderUI [IV], UserNotificationsUI [V], WidgetKit [V]
- **trivial**: BrowserEngineCore [V]

### P4 Data, cloud, contacts/calendars & commerce

Done 2026-11-17: ATT request flow on iOS/tvOS/visionOS via inputs.sh tracking (host-written TCC row, removed after: fresh-install check intact), AddressBookUI answers. Left: _MarketplaceKit_UIKit (ActionButton blocks on Apple).

- **thin**: _MarketplaceKit_UIKit [I]

### P8 Foundation, networking, security, identity & device management

Done 2026-11-17: _ManagedAppDistribution_SwiftUI accessibility (x86Sim Redownload label fixed: framework linked at its host path), AutomatedDeviceEnrollment presentation, _SecureElementCredential overlays (no session: featureUnavailable), Twitter. Left: ClassKitUI assigned documents, IdentityLookupUI reporting UI (system UI).

- **thin**: ClassKitUI [IV], IdentityLookupUI [IV]

## Remaining x86Sim-only differences (vs Apple's 27.2 simulator)

Open x86Sim bugs / missing pieces:

- **(r30) Metal compute `[[stage_in]]`**: a kernel fed through MTLStageInputOutputDescriptor reads 0 (`[0, 0, 0]` vs Apple's `[12, 34, 56]`; func:Metal.p27-pipeline-layout-descriptors, iOS + visionOS): the descriptor is not applied in the Metal->Vulkan translation.
- **(r30) WidgetKit push info, visionOS**: WidgetCenter.currentPushInfo answers nil at once, Apple's visionOS simulator never answers (p28-configurations-controls-builders).
- **(r30, not asserted)** StoreKit PaymentMethodBinding(id:) throws at once (Apple never answers); Charts custom scroll-snap behavior asked fewer times (1 vs 3).
- **FoundationModels without a Mac**: x86 answers modelNotReady (iOS respond/guided/tools/stream SKIP, Apple PASS via its host Mac) unless X86SIM_FM_RELAY points at a Mac with Apple Intelligence; with the relay the iPad results equal Apple's. Configuration, not a bug.
- **fseventsd stand-in**: kFSEventStreamCreateFlagIgnoreSelf / MarkSelf not implemented (inotify does not say which process made a change), nor hard-link flags or extended data / document ids beyond what the client fills in. `CoreServices.fsevents-stream-file-events` has only an iOS x86 result in the harvested runs (no Apple result, no tvOS/watchOS/visionOS run).
- **BrowserEngineCore JIT witness**: `kevent-jit-restrict` / `bememory-symbols` report "JIT witness supported" 0 on x86 vs 1 on Apple (a CPU feature of the host); not asserted (0 or 1 accepted).
- **VideoSubscriberAccount** (`access-status-user-accounts`, P9 assertion): Apple's VSUserAccountManager update / query fail NSCocoaErrorDomain 4097 (videosubscriptionsd exists and its connection is interrupted); x86 fails 4099 "lookup error 3" (no com.apple.VideoSubscriberAccount.videosubscriptionsd job): x86 FAILs the new assertion until the job is there.
- **MarketplaceKit** (`distributor-requirements`, P9 assertion): x86 answers AppDistributor.current at once ("error Unknown") and eligibilityRegion nil; Apple never answers for a simctl-installed app in 15 s, now asserted: x86 FAILs until it stops answering.
- **PushKit VoIP token**: x86 has no apsd APNs-sandbox courier, so never a token; Apple's fresh devices get none (watchOS, visionOS, one iOS run) or an 80-byte one within 5 s (another iOS run, 2026-11-16): `voip-credentials` accepts both (no token and none cached, or a cached token).
- **Microphone vs Apple**: Apple's reference Mac mini has no input device, so its simulators never record (AVAudioRecorder does not start, input node 0 Hz, AudioQueue -66628); x86Sim records simaudio's microphone since r16. The P12 microphone checks assert the answer for the device they find; a Mac with a microphone is needed for a value comparison.
- **NearbyInteraction own-token updates**: Apple reports 2 nearby objects, x86Sim's nisimhost 1 on watchOS (2 on iOS); >= 1 asserted.

Unasserted value differences (both PASS; decide whether to assert):

- NaturalLanguage `embeddings-assets` iOS/visionOS: x86 has a sentence embedding and contextual-embedding assets true (mobileassetd downloads mBERT after the boot-a64 LinguisticData link); Apple's fresh devices: no sentence embedding, assets false.
- StoreKit `products-storefront` tvOS: x86 storefront none vs Apple USA (x86 run 2026-11-15 15:30, probably before amsaccountsd joined the tvOS job list in the P8 round: rerun).
- _PassKit_SwiftUI `wallet-pay-buttons` iOS: x86 pay button box 0% ink (wallet 65%); Apple's run hung, no comparison yet.

Stale x86 results (the failing run predates the fix or the check change; rerun):

- AppIntents `donations` tvOS: FAIL NSCocoaErrorDomain 4099 (com.apple.linkd.transcript) at 2026-11-15 20:04, before com.apple.linkd joined boot-a64.sh's tvOS list.
- HomeKit `home-manager-add-remove-home` and _RelevanceKit_MapKit `poi-category-contexts` watchOS: FAIL texts belong to older assertions.
- AppTrackingTransparency `status` tvOS: 1 (restricted) vs Apple 0 in the last x86 run; check comment says fixed (ManagedConfiguration profiled).

Runs missing (checks only Apple ran): tvOS 18; watchOS 31; visionOS 16 (tvOS: the P4 data checks; watchOS: P7 + a few P2; visionOS: P3). P9 round (2026-11-16): every new or changed check (p9 entries in coverage-gaps.json) passed on Apple's simulator only; the x86Sim runs are pending (device work paused). P10 round (2026-11-16): the p10 checks passed on Apple (all four) and on x86Sim iOS (App Clip: Apple only); tvOS / watchOS / visionOS x86 runs pending.

Fixed since the first pass (now = Apple): guest signal handlers (`libSystem.B.signals-sigaction-mask-itimer` PASS), MultipeerConnectivity two-peer (iOS/tvOS), NearbyInteraction discovery token (host/nisimhost), visionOS location (managedassetsd), visionOS ARKit addAnchor error text (stub ARKitCore bundle), MetricKit finishExtendedLaunchMeasurement 4 (simshim signpost id), Bonjour on device, TLS-to-loopback race, guest thread stack size, ShazamKit library (r15: shazamd on demand; addItems answered 301 at once), visionOS Vision optical flow (r16: CoreImage [[stitchable]] kernels never compiled: MTLCompiler's dlopen of GPUCompiler.framework/Libraries/libComposeFilters.dylib, a cache-only dylib behind a symlinked directory, failed under Darling; arm64jit answers dyld_sim's directory open from the runtime root), microphone capture (r16: simaudio had no duplex aggregate, so .playAndRecord input was 0 ch), visionOS realtime audio / PHASE / MediaToolbox tap / immersive-space audio (r15: the gaps/vfull4 mismatches came from a boot without X86SIM_AUDIO=1; with it all six = Apple). Host config (not x86Sim): ufw on the build host drops inbound multicast, so NWConnectionGroup loopback receive cannot be asserted on x86.

## api-unavailable (whole public API marked unavailable in the SDK)

Evidence from the Xcode 27.2 simulator SDK swiftinterface / headers (scan: ~/scratch/covgap/v2/unav2.py + header reading). Load checks (load:<Framework>) still run.

| framework | platform | SDK evidence |
|---|---|---|
| BrowserEngineCore | tvOS | BEMemory/BEkevent/BEAudioSession all API_UNAVAILABLE(tvos) |
| CoreSpotlight | tvOS | 242/242 Swift decls @available(tvOS, unavailable); every ObjC class API_UNAVAILABLE(tvos, watchos) |
| EnergyKit | tvOS | 255/255 Swift decls @available(tvOS, unavailable) |
| FoundationModels | tvOS | 838/838 Swift decls @available(tvOS, unavailable) |
| MatterSupport | tvOS | 104/104 Swift decls @available(tvOS, unavailable) |
| MetricKit | tvOS | 567/567 Swift decls + all 34 ObjC classes API_UNAVAILABLE(tvos, watchos) |
| SharedWithYouCore | tvOS | every class API_AVAILABLE(ios, macos) only: none imported for tvOS (Swift: cannot find SWCollaborationMetadata) |
| UserNotificationsUI | tvOS | UNNotificationContentExtension and its NSExtensionContext category API_UNAVAILABLE(watchos, tvos) |
| _AppIntents_HealthKit | tvOS | the module imports HealthKit, which the tvOS SDK lacks (not importable); dlopen of the runtime overlay wedges the app in Apple's tvOS simulator |
| _GameController_SwiftUI | tvOS | its 3 Swift decls @available(tvOS, unavailable) |
| BackgroundTasks | watchOS | every BGTaskScheduler / BGTaskRequest declaration API_UNAVAILABLE(watchos) |
| BrowserEngineCore | watchOS | BEMemory/BEkevent/BEAudioSession all API_UNAVAILABLE(watchos) |
| BrowserEngineKit | watchOS | processes @available(watchOS, unavailable); BETextSuggestion / text input / accessibility API_UNAVAILABLE(watchos) |
| BrowserKit | watchOS | BEAvailability, BEBrowserContentFilter, BEBrowserDataExport/ImportManager all API_UNAVAILABLE(watchos) |
| DeviceActivity | watchOS | 55/55 Swift decls @available(watchOS, unavailable) |
| EnergyKit | watchOS | 255/255 Swift decls @available(watchOS, unavailable) |
| FamilyControls | watchOS | 29/29 Swift decls @available(watchOS, unavailable) |
| FinanceKit | watchOS | 211/211 Swift decls @available(watchOS, unavailable) |
| ManagedSettings | watchOS | 166/166 Swift decls @available(watchOS, unavailable) |
| MatterSupport | watchOS | 104/104 Swift decls @available(watchOS, unavailable) |
| UserNotificationsUI | watchOS | UNNotificationContentExtension and its NSExtensionContext category API_UNAVAILABLE(watchos, tvos) |
| AutomaticAssessmentConfiguration | visionOS | all 6 ObjC classes API_UNAVAILABLE(visionos) or (ios) (visionOS inherits iOS), 6/6 Swift decls unavailable |
| BrowserKit | visionOS | both ObjC classes (BEAvailability...) API_UNAVAILABLE(..., visionos) |
| EnergyKit | visionOS | 255/255 Swift decls @available(visionOS, unavailable) |
| LockedCameraCapture | visionOS | 17/17 Swift decls @available(visionOS, unavailable) |
| OpenGLES | visionOS | OPENGLES_DEPRECATED = API_UNAVAILABLE(visionos) on every EAGL / GL declaration |
| TouchController | visionOS | all 17 ObjC classes API_UNAVAILABLE(macCatalyst, visionos) |
| TrustInsights | visionOS | 92/92 Swift decls @available(visionOS, unavailable) |
| WiFiAware | visionOS | 235/235 Swift decls @available(visionOS, unavailable) |
| _Translation_SwiftUI | visionOS | translationPresentation / translationTask @available(visionOS, unavailable) |

Partly available (not api-unavailable; the gap names what is left):

- Translation on tvOS (covered): only AttributeScopes.TranslationAttributes (skipsTranslation) is available; TranslationSession/LanguageAvailability are @available(..., unavailable)
- QuartzCore on watchOS (covered): only CACurrentMediaTime is available (every CA class and the CATransform3D functions API_UNAVAILABLE(watchos))
- Translation on watchOS (covered): only AttributeScopes.TranslationAttributes (skipsTranslation) is available; TranslationSession/LanguageAvailability are @available(..., unavailable)
- BrowserEngineCore on visionOS (trivial): only BEMemory (be_memory_inline_jit_restrict_*) is available; be_kevent and BEAudioSession are API_UNAVAILABLE(visionos)
- Translation on visionOS (covered): only AttributeScopes.TranslationAttributes (skipsTranslation) is available; TranslationSession/LanguageAvailability are @available(..., unavailable)
- NetworkExtension on watchOS: NEVPNManager / NERelayManager are API_UNAVAILABLE(watchos); the hotspot API is checked.

Platform letters: I = iOS/iPadOS, T = tvOS, W = watchOS, V = visionOS. A gap prefixed "X:" applies to that platform only.

## No check on the platform (0 frameworks)

Most are ports: the framework is checked on another platform; usually widen the `#if`.

| framework | platforms | existing checks | gaps / check ideas | package |
|---|---|---|---|---|

## Trivial checks only (1 frameworks)

| framework | platforms | existing checks | gaps / check ideas | package |
|---|---|---|---|---|
| BrowserEngineCore | V | bememory-symbols | [c] BEMemory is C-only inline asm (__SWIFT_UNAVAILABLE): from Swift only the exported _impl / _supported symbols; be_kevent / BEAudioSession are unavailable on visionOS | P3 |

## Thin coverage of main areas (6 frameworks)

| framework | platforms | existing checks | gaps / check ideas | package |
|---|---|---|---|---|
| ClassKitUI | IV | assigned-document-views, unassigned-document-views | [c] an assigned document needs a Schoolwork class (none in the simulator): only the unassigned views | P8 |
| FileProviderUI | IV | action-extension-controller, action-extension-registered, input-files-authentication-error | I: [c] the extension's custom action (NSExtensionFileProviderActions) is in no item's context menu in Apple's iOS 27.2 Files; V: [c] the action extension runs only from the Files app's action menu (system UI) | P3 |
| IdentityLookupUI | IV | classification-extension-registered, classification-view-controller | [c] the reporting UI runs only from Messages / Phone's report-junk flow (system UI) | P8 |
| UserNotificationsUI | V | content-extension-controller, content-extension-registered | [c] the content extension runs only when the user expands a notification of its category (system UI, not unattended) | P3 |
| WidgetKit | V | center, widget-extension-descriptors, widget-views-render-xros | [c] ControlCenter is unavailable on visionOS; [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (placing a widget) | P3 |
| _MarketplaceKit_UIKit | I | install-metadata-display-options | [c] ActionButton init blocks the main thread on Apple outside a marketplace app | P4 |

## Apple-sim N/A, open (no asserting check yet) (0 frameworks)

Not to be chased beyond asserting the simulator answer.

| framework | platforms | existing checks | gaps / check ideas | package |
|---|---|---|---|---|

## Apple-sim N/A, done (asserting check passes on Apple) (87 frameworks)

Remaining gaps here are optional depth.

| framework | platforms | existing checks | gaps / check ideas | package |
|---|---|---|---|---|
| ARKit | I | configurations, simulator-unsupported-answers | done (iOS: no ARKit tracking in Apple's simulator; visionOS sim supports only WorldTrackingProvider) | P2 |
| AccessoryLiveActivities | I | feature-results | done (forwarding needs an AccessorySetupKit-paired accessory) | P3 |
| AccessoryNotifications | I | forwarding-extension-registered, notification-model-codable | done (notification forwarding needs an accessory paired through AccessorySetupKit whose forwarding the user allowed: none in the simulator) | P5 |
| AccessorySetupKit | I | descriptors-display-items, session-activate | done (ASAccessorySession never activates in Apple's simulator (and traps without NSAccessorySetupKitSupports)) | P5 |
| AccessoryTransportExtension | I | extension-registered, message-builder | done (only Apple's host (private entitlement) runs a com.apple.accessory-transport-extension extension: the app's monitor is refused (extensionKit 16)) | P5 |
| AdAttributionKit | I | impression-postback-answers | done (AdAttributionKit is unsupported in the simulator (every call NSCocoaErrorDomain 3328)) | P4 |
| AdServices | IV | attribution-token, attribution-token-sim-error | done (attributionToken errors in the simulator) | P4 |
| AlarmKit | I | authorization-alarms-updates, manager-state, request-schedule-refused | done (requestAuthorization is denied without a prompt: SpringBoard's CFUserNotification server refuses mobiletimerd (no com.apple.springboard.CFUserNotification entitlement, and no runtime path counts as the system partition)) | P3 |
| AppMigrationKit | I | extension-tester, status-identifiers | done (AppMigrationTester cannot start the app's migration extension from the app: exportController throws extensionKit 2 / RBSServiceErrorDomain 1) | P3 |
| BackgroundAssets | IV | asset-pack-manager, asset-pack-status-download, download-manager-schedule-cancel, foreground-download-loopback | [a] a background BAURLDownload handled by an (unmanaged) BADownloaderExtension: the bundled extension is a ManagedDownloaderExtension; a foreground download through the app is covered (managed asset packs need App Store hosting: AssetPackManager answers each call with an error (asserted by asset-pack-status-download)) | P3 |
| BackgroundTasks | ITV | continued-processing-request, register-submit | done (BGTaskScheduler.submit -> .unavailable in Apple's simulator (asserted by register-submit)) | P3 |
| BrowserEngineKit | I | processes-without-entitlement, scroll-view-text-objects | done (browser process launches need the web-browser-engine entitlement + extensions) | P3 |
| BrowserKit | I | content-filter-import-answers, data-exchange-types | [c] BEAvailability.isEligible(for:) raises NSInvalidArgumentException in Apple's sim (XPC proxy lacks the selector): not assertable (BEAvailability.isEligible raises in Apple's simulator) | P3 |
| CallKit | WV | incoming-outgoing-calls, provider-observer | [run] rerun incoming-outgoing-calls on ref (FAIL predates the error assertion; detail matches the asserted errors) (Apple's watchOS/visionOS simulators: callservicesd refuses incoming (CallKit.error 0) and transactions (requesttransaction 1)) | P3 |
| CarKey | IW | remote-control-start-refused | done (needs Wallet car keys (NFC/UWB) and Apple's entitlement) | P5 |
| ContactProvider | I | manager-without-extension | done (needs a contact provider extension) | P4 |
| CoreBluetooth | ITWV | central-state, managers-unsupported-objects | done (no Bluetooth radio in the simulator) | P5 |
| CoreMotion | IWV | availability, unavailable-sensors-queries | done (no motion sensors in the simulator) | P5 |
| CoreNFC | I | reading-available, unavailable-ndef-model | done (no NFC in the simulator) | P5 |
| CoreTelephony | I | network-info, no-radio-answers | done (no cellular radios in the simulator) | P5 |
| DeclaredAgeRange | I | eligibility, request-age-range | done (isEligibleForAgeFeatures / requestAgeRange never answer in Apple's simulator) | P3 |
| DeviceActivity | I | center-activities, start-monitoring-schedule | done (startMonitoring needs Family Controls authorization (entitlement; no FamilyControlsAgent in the sim)) | P3 |
| DeviceCheck | ITWV | support, unsupported-errors | done (DCDevice / App Attest unsupported in Apple's simulator) | P8 |
| DeviceDiscoveryExtension | IV | device-event-types, discovery-point-xros, extension-registered | done (only Apple's host (private entitlement) runs a com.apple.discovery-extension extension: the app's monitor is refused (extensionKit 16)) | P5 |
| DeviceDiscoveryUI | T | device-picker | done (the device picker is not supported in the tvOS simulator (isSupported false; its viewDidLoad raises)) | P5 |
| EnergyKit | I | venues-guidance-answers | done (no energy venues service in the simulator) | P5 |
| ExposureNotification | I | authorization-status, manager-activate-answer | done (needs Apple's Exposure Notification entitlement (deprecated)) | P5 |
| ExtensionFoundation | W | apple-extension-point-monitor | done (watchOS installs no app extension on ExtensionKit points; Apple's points refuse an app monitor (host not entitled)) | P3 |
| ExtensionKit | TWV | app-defined-point-refused | done (tvOS/watchOS/visionOS installd refuse an app extension on a non-Apple extension point (Apple's simulator too)) | P3 |
| ExternalAccessory | ITV | manager, no-accessories-wifi-browser | done (no MFi accessories) | P5 |
| FamilyControls | I | activity-picker-render, authorization-selection, authorization-status | done (requestAuthorization(for: .individual) -> NSCocoaErrorDomain 4099 (no FamilyControlsAgent in Apple's simulator)) | P3 |
| FinanceKit | I | availability-authorization | done (FinanceStore authorization/queries trap without the Apple-granted FinanceKit entitlement) | P4 |
| FoundationModels | WV | private-cloud-compute-model, schemas-content-transcript, system-model-availability, system-model-respond-guided-tools-stream, watch-pcc-session-refused | done (no on-device model on watchOS; Private Cloud Compute: deviceNotEligible in the sim) | P7 |
| GameKit | ITWV | load-matches-entries-unauthenticated, local-player-leaderboard-objects, unauthenticated-player-leaderboards-matchmaking | done (Game Center server features need a signed-in sandbox account (Apple sim: same)) | P2 |
| GameSave | IV | synced-directory-without-icloud | done (GameSaveSyncedDirectory needs an iCloud account) | P2 |
| GroupActivities | ITV | activity-metadata-prepare, activity-sessions, no-call-activation-coding, observer | [c] GroupSessionMessenger / GroupSessionJournal need a session (FaceTime call): only the no-session answer is assertable (SharePlay sessions need FaceTime) | P4 |
| HomeExtensions | I | extension-registered, settings-model | done (only Apple's host (private entitlement) runs a com.apple.Home.HomeExtension extension: the app's monitor is refused (extensionKit 16)) | P5 |
| IdentityDocumentServices | I | registration-store-requests | done (mobile ID documents need Wallet IDs (not in the simulator)) | P8 |
| IdentityDocumentServicesUI | I | web-presentment-controller | done (web presentment needs the identity-document entitlement and Wallet IDs) | P8 |
| ImageCaptureCore | IV | browser-no-devices, device-browser | done (no cameras/scanners attached) | P5 |
| ImagePlayground | IV | availability, image-creator-unavailable | done (needs Apple Intelligence image models) | P7 |
| LinkSecurity | ITWV | flag-urls, flag-urls-port | done (flagged-URL store lives in imagent, absent from simulator runtimes) | P3 |
| LockedCameraCapture | I | manager-simulator-answers | done (camera capture extension (no cameras in the simulator)) | P1 |
| ManagedAppDistribution | IV | libraries-unmanaged-device | done (ManagedAppLibrary answers unsupportedPlatform in Apple's simulator) | P8 |
| ManagedSettings | IT | store-read-write, store-write-read-clear, tv-default-store-effective | done (store writes need Family Controls authorization (unavailable in the sim)) | P3 |
| ManagedSettingsUI | I | shield-configuration | done (shields are drawn only for apps a Family Controls-authorized store shields (none in the simulator)) | P3 |
| MarketplaceKit | I | distributor-requirements | [b: AppDistributor answers] x86 answers AppDistributor.current at once ("error Unknown") / eligibilityRegion nil; Apple never answers (now asserted) (marketplace install APIs need an EU marketplace install; AppLibrary/satisfiedByDevice block on Apple) | P4 |
| MatterSupport | IV | add-device-request-answer | done (system Matter setup flow not available in the simulator) | P5 |
| MediaIntelligence | ITV | face-group-analyzer | [c] FaceGroupAnalyzer ingest: Vision face networks fail in Apple sim and the framework double-resumes a continuation (abort) - unassertable; only the empty store lifecycle is checkable (face ingest needs Vision espresso inference contexts (absent in Apple sim, aborts)) | P7 |
| MessageUI | IV | can-send, simulator-answers-composers | [c] MFMailComposeViewController / MFMessageComposeViewController init while canSend* is false kills the app on Apple's simulator (x86Sim the same, r17): not checkable in-process (no Mail account / Messages in the simulator) | P6 |
| MetalPerformancePrimitives | ITV | tensor-matmul-shader | done (the simulator Metal compiler has no MetalPerformancePrimitives header) | P2 |
| MetalPerformanceShadersGraph | IV | build-compile-no-device, graph-run | done (MPSGraphDevice init aborts in Apple's simulator too) | P2 |
| MetricKit | IV | log-handles-signposts-launch-task, manager, signposts-in-log-store | done (no MetricKit payloads in the simulator (pastPayloads / diagnostics empty)) | P3 |
| MultipeerConnectivity | V | session, two-peer-data-stream-resource | done (Apple's visionOS simulator: the browser finds no peer in 30 s on some runs, connects on others) | P8 |
| MusicKit | IT | authorization-status, objects-subscription-catalog-answers | done (catalog/subscription need a MusicKit-enabled team-signed app + Apple Music account) | P1 |
| ProximityReader | I | reader-support, readers-answers | done (Tap to Pay needs NFC hardware + entitlement) | P5 |
| PushKit | IWV | file-provider-push-type, registry, voip-credentials | done (no VoIP token on a fresh simulator device (apsd not connected to APNs sandbox)) | P3 |
| PushToTalk | I | channel-manager | done (Push-to-Talk API not available in the simulator (com.apple.pushtotalk.instantiation 1)) | P3 |
| ReplayKit | ITV | broadcast-activity-load, capture-answer-picker, recorder, start-stop-recording-preview | done (no screen-capture sample buffers in the simulator (startCapture starts, 0 buffers in 5 s)) | P1 |
| RoomPlan | I | unsupported-model | done (needs LiDAR) | P5 |
| SafetyKit | IW | crash-detection, entitlement-gated, exception-without-entitlement | done (Apple-only entitlement) | P5 |
| SecureElementCredential | I | session-eligibility | done (needs a Secure Element (NFC)) | P8 |
| SensitiveContentAnalysis | IV | analyze-image-policy, policy, video-analysis-disabled-policy | done (needs the client entitlement and user setting (policy disabled)) | P7 |
| SensorKit | I | authorization-request-answer, reader-authorization | done (research entitlement + sensors) | P5 |
| Speech | ITV | audio-buffer-request, recognize-synthesized-file, recognizer-availability, speech-analyzer-transcribe-file, speech-transcriber-assets | done (no on-device ASR / SpeechTranscriber assets in Apple's simulator (kLSRErrorDomain 300, assets unsupported)) | P7 |
| SuggestedActions | IV | message, message-view-generate, message-view-generate-port | done (suggested actions need Apple Intelligence: none offered in the simulator) | P7 |
| SystemExtensions | I | workspace | done (DriverKit system extensions cannot be activated in the simulator) | P3 |
| TelephonyMessagingKit | I | handles-content-codable, session-without-carrier | done (needs a carrier SIM / telephony) | P3 |
| TouchController | I | layout-render-touch, simulator-unsupported-descriptor | done (TCTouchController.isSupported is false in Apple's simulator) | P2 |
| TranslationUIProvider | I | extension-registered | done (the translation UI host entitlement is Apple-private: the app's AppExtensionPoint.Monitor is refused (extensionKit 16); only the system Translate menu runs the extension) | P7 |
| TrustInsights | I | evaluator-authorization | done (InsightEvaluator answers notAvailable in Apple's simulator) | P8 |
| UserNotificationsUI | I | content-extension-controller, content-extension-registered, input-expand-content-extension | done (Apple's simulator expands a notification of the extension's category (long look) but never launches the content extension) | P3 |
| VideoSubscriberAccount | ITV | access-status-user-accounts, manager | done (no TV-provider service in the simulator (checkAccessStatus -5, user account update 4099)) | P1 |
| VisionKit | V | analyzer-scanner-support, image-analyzer-live-text | done (Apple's visionOS simulator analyzes but reads no text; no camera scanners) | P7 |
| WatchConnectivity | IWV | session-activate | W: [a] transfers need a paired iPhone + watch (two devices booted at once on each side); the watch-only app gets no session state (no paired device (iOS/visionOS); watch-only app on watchOS) | P3 |
| WeatherKit | ITWV | service-answer, service-answers | done (needs a team-signed WeatherKit entitlement; auth service absent in sim runtimes) | P5 |
| WiFiAware | I | unsupported-capabilities | done (no Wi-Fi Aware radio) | P5 |
| _AVKit_GroupActivities | V | playback-coordinator-no-session | done (needs a SharePlay session (FaceTime)) | P1 |
| _AdAttributionKit_StoreKit | I | overlay-configuration-impression | done (AdAttributionKit unsupported in the simulator) | P4 |
| _AppIntents_SwiftUI | TW | siri-tip-view, siri-tip-view-shortcuts-link | done (SiriTipView shows nothing in the simulator (no Siri phrase): it lays out at 0x0) | P7 |
| _CoreHaptics_AudioToolbox | V | intended-spatial-experience | done (no haptics engine in the visionOS simulator (CHHapticEngine -4815)) | P1 |
| _DeviceActivity_SwiftUI | I | report-view-hosted | done (report content needs a DeviceActivityReport extension + Family Controls authorization) | P3 |
| _GameController_SwiftUI | V | handles-game-controller-events-modifier | done (GCVirtualController is API_UNAVAILABLE(visionos) and Apple's visionOS simulator delivers no game controller input to apps) | P2 |
| _SecureElementCredential_SwiftUI | I | transaction-task-modifier | done (no Secure Element / NFC: CredentialSession.startSession answers featureUnavailable) | P8 |
| _SecureElementCredential_UIKit | I | window-scene-events | done (no Secure Element / NFC: CredentialSession.startSession answers featureUnavailable) | P8 |
| _TabletopKit_GroupActivities | V | coordinate-with-session-symbol | done (SharePlay needs a FaceTime call) | P2 |
| iAd | I | client-attribution-obsolete | done (iAd obsoleted: ADClient.sharedClient nil) | P4 |

## Excluded (listed, not chased)

| framework | platforms | why |
|---|---|---|
| AudioUnit | ITV | headers only (no binary): the AU API lives in AudioToolbox - covered there |
| CoreAudioTypes | ITWV | headers only: types used by AudioToolbox/AVFAudio checks (AudioStreamBasicDescription, AudioBufferList) |
| _FoundationModels_SwiftUI | IV | not in the simulator runtimes (load SKIP) |
| _GroupActivities_UIKit | T | GroupActivitySharingController (activity + lazy) builds; visionOS association interaction attached; tvOS re-export only. |
| _Intents_TipKit | ITWV | re-export only (no public declarations) |
| _LocationEssentials | ITWV | C types/functions re-exported by CoreLocation (CLLocationCoordinate2D...): used by CoreLocation/MapKit checks |
| _PhotosUI_WidgetKit | IV | swiftinterface has no public declarations (imports PhotosUI / _PhotosUI_SwiftUI only) |
| _SharedWithYou_AppIntents | ITV | re-export only (no public declarations) |

## Covered, with secondary gaps

| framework | platforms | secondary gaps |
|---|---|---|
| ARKit | V | [c] assert the simulator provider answers (world true; planes/scene/hands/images/room false) in data-providers (today reported, not asserted); [c] assert WorldTrackingProvider.addAnchor -> addWorldAnchorFailed (both simulators; today reported, not asserted) |
| AVRouting | ITV | V: [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (choosing the discovered route in the picker) |
| AdSupport | IT | [c] non-zero IDFA needs tracking authorized (ATT prompt answer) |
| AppIntents | ITWV | I: [c] ControlWidget intents: a placed control tapped in Control Center never runs its intent on Apple's simulator (func:WidgetKit.input-placed-control-perform), so toggles / SetValueIntent cannot be driven; W: [a] ControlWidget toggles / SetValueIntent (with WidgetKit) |
| AuthenticationServices | ITWV | I: [c] ASAuthorizationController.performRequests with a passkey request: Apple's iPad sim shows its passkey sheet and the app hangs (assert the sheet without blocking); I: [c] ASAuthorizationProviderExtension / ASCredentialProviderViewController objects: Apple's iOS simulator never answers the identity store's state (hung 90 s; func:AuthenticationServices.credential-provider-objects runs on visionOS) |
| BackgroundAssets | T | [a] BADownloaderExtension: a scheduled BADownload running in the downloader extension (extension registered, seen by ExtensionFoundation monitor on tvOS/visionOS) |
| BrowserEngineCore | I | [c] JIT witness supported is a CPU feature (1 Apple silicon, 0 on x86): not assertable across hosts |
| BusinessChat | I | [c] BCChatAction.openTranscript (deprecated) hands off to Messages for Business: no Messages app on Apple's simulator |
| CallKit | I | [b: Call Directory answers: x86Sim's CallKit CallDirectory service answers disabled (1) / reload error 6; Apple's fails to create its store at the Mac's /var/mobile/Library/CallDirectory (513) and answers error 0 to both] |
| CarPlay | I | [d] CPTemplateApplicationScene needs a CarPlay display: Simulator.app's I/O > External Displays > CarPlay (absent on the reference Mac; x86Sim has none) |
| ClockKit | IW | W: [c] CLKComplicationDataSource timeline: watch faces run WidgetKit complications since watchOS 10; Apple's simulator reports 0 active ClockKit complications (func:ClockKit.complication-server), so reloadTimeline / extendTimeline reach no data source |
| CloudKit | ITWV | [c] server ops (fetch/query/subscription/share accept) need team signing + account: only save -> CKError 8 asserted; [c] assert accountStatus answer instead of SKIP in account-status |
| Contacts | IWV | I: [a] limited-access (iOS 18) authorization behaviour; V: [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (the contact access picker) |
| CoreAudio | ITWV | [d] a default-device / sample-rate change: on Apple's simulator the HAL devices are the Mac's own, a change would reconfigure the host's audio hardware (r28: not driven) |
| CoreHaptics | ITV | [c] engine: no haptics hardware in the simulator (pattern API covered) |
| CoreLocation | ITWV | I: [c] CLMonitor events: Apple's simulator delivers none for a simulated location (reported, not asserted) |
| CoreMIDI | ITWV | I: [c] virtual-loopback SKIPs - assert the simulator answer of MIDISourceCreate/MIDIDestinationCreate (error code) instead of skipping; I: [c] MIDICIDiscoveryManager.discover gives no answer in 8 s (reported, not asserted) - assert the simulator answer; V: [c] virtual-loopback SKIPs - assert the simulator answer of MIDISourceCreate/MIDIDestinationCreate (error code) instead of skipping; V: [c] MIDICIDiscoveryManager.discover gives no answer in 8 s (reported, not asserted) - assert the simulator answer |
| CoreServices | ITWV | [b: fseventsd stand-in lacks IgnoreSelf/MarkSelf] FSEvents IgnoreSelf / MarkSelf flags |
| ExtensionFoundation | ITV | V: [run] x86 result missing |
| FileProvider | IV | I: [b: File Provider download fetched twice: after sim_materializeFile fileproviderd's post-operation lookup of the item reads it once (attributes fine: tracked, not dataless, document id kept) and then retries 6.2 s with no file system access at all (an in-memory wait, not mtime / gen count / flags / own-event marks), fetches the file again and takes the extension's unset date (Files: 12/31/69); Apple fetches once]; [b: File Provider eviction refused: fileproviderd's post-materialization docID lookup times out (item stale, the same cause as the double fetch), then evictItem answers nonEvictable -2008 ("content policy prevention") for 30 s; Apple evicts at once and the next read fetches again (func:FileProvider.evict-reimport-pending, r29)] |
| FoundationModels | I | [b: config] respond/guided/tools/stream need X86SIM_FM_RELAY (a Mac with Apple Intelligence); without it x86 answers modelNotReady where Apple's sim (host Mac) PASSes; with the relay iPad = Apple |
| GSS | IV | [d] Kerberos authentication needs a KDC (none on either side) |
| GameController | ITV | [d] GCMouse input handlers: Apple's simulator moves a mouse only through Simulator.app's pointer capture (absent on the reference Mac); Indigo relative pointer messages are dropped as leaf events, or break the HID port with child events (r28) |
| HealthKit | IWV | I: [c] clinical records / HKMedication: assert supportsHealthRecords() == false (reported today); V: [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (the Health authorization sheet) |
| HomeKit | ITWV | [c] HMHome rooms/accessories/action sets: Apple's simulator refuses addHome (HMErrorDomain 2040 / no answer) |
| Intents | ITWV | [c] in-app intent handling (application(_:handlerFor:) / INExtension): an intent reaches the app only from Siri, which Apple's simulator does not run |
| LocalAuthentication | ITWV | V: [c] Apple's visionOS simulator never enrolls Optic ID (no biometrickitd, the enrollment state reads back 0): canEvaluatePolicy -7; x86Sim enrolls and matches |
| NearbyInteraction | IW | [a] two-peer run: needs two devices booted at once on each side (Apple: two simulators; x86Sim: nisimhost) |
| Network | ITWV | [b: build-host ufw drops inbound multicast] NWConnectionGroup loopback receive (check only asserts group ready + send) |
| OSLog | ITWV | [c] OSLogEntrySignpost: the simulator's process store returns no signposts (0 on Apple and x86Sim); a position by date does not filter older entries (Apple too) |
| PDFKit | ITV | T: [c] PDFView(frame:) raises on tvOS (-[UIEditMenuInteraction initWithDelegate:] unrecognized selector, Apple's simulator too, r17); T: [c] assert PDFView init raises (UIEditMenuInteraction unavailable) instead of SKIP |
| PassKit | IWV | I: [c] PKIdentityAuthorizationController needs the in-app identity entitlement (Apple ends the app); [d] PKAddPassesViewController with a signed .pkpass: signing needs an Apple-issued Pass Type ID certificate |
| PencilKit | IV | V: [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) |
| PermissionKit | IV | V: [run] x86 result missing |
| Photos | ITV | [c] asset delete (PHAssetChangeRequest.deleteAssets prompts: assert simulator answer) |
| PhotosUI | ITWV | W: [c] a selection in the watch photos picker: Apple's watch simulator shows "Unable to Load Photos in Simulator" (func:_PhotosUI_SwiftUI.input-watch-picker-transferable); V: [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (a selection in the picker) |
| RelevanceKit | ITWV | W: [b: watch widget configurations: Apple's fresh watch lists the sdkcov widget as configured (currentConfigurations 1), x86Sim's none; relevance() asked on both (func:RelevanceKit.widget-relevance-invalidate, r29)]; V: [b: visionOS widget relevance: x86Sim's chronod asks relevance() after invalidateRelevance with no widget placed, Apple's never (func:RelevanceKit.widget-relevance-invalidate, r29)] |
| Security | ITWV | V: [c] needs enrolled biometry, which Apple's visionOS simulator never has (x86Sim: PASS) |
| StoreKit | ITWV | [c] purchases need a .storekit configuration (SKTestSession is Xcode-only) |
| SwiftUI | ITWV | V: [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (long press: contextMenu); V: [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (drag & drop with Transferable) |
| TabletopKit | V | [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (TabletopInteraction gestures / a dice roll) |
| Translation | ITWV | I: [c] TranslationSession.translate with installed assets (Apple sim: not installed -> error, asserted) |
| UserNotifications | ITWV | T: [c] badge delivery needs authorization whose alert never dismisses unattended (add refusal asserted) |
| VideoToolbox | ITV | [c] VTFrameProcessor (frame-rate conversion / super-resolution) isSupported answer |
| Vision | ITWV | [c] faces/landmarks/body/hand/classify/saliency: Apple sim has no inference context - checks accept the error (done) |
| WidgetKit | IW | W: [a] timelines reach currentConfigurations (0 configured today): assert a kind; W: [a] ControlCenter with a placed control |
| WorkoutKit | IW | I: [c] WorkoutScheduler.shared authorizationState / scheduledWorkouts never answer on Apple's iPhone simulator (static answers asserted only) |
| _PhotosUI_SwiftUI | IWV | I: [a] loadTransferable of a SwiftUI PhotosPicker-handed item (PHPicker's delegate path is covered: func:PhotosUI.input-picker-selection); W: [c] the watch simulator's photos picker has nothing to pick ("Unable to Load Photos in Simulator" on both); V: [d] needs visionOS gaze / pinch input: the reference Mac's Xcode has no Simulator.app, SimulatorKit's Indigo builders reach no visionOS pointer (r26) (a selection in the picker) |
| _USDKit_RealityKit | ITV | [c] USDStageComponent.render completes only on a real GPU family (simulator answers failed, no errors - asserted) |

## Check -> framework map: framework use inside checks named after another

Every check id `func:<Framework>.<name>` counts for its named framework (per-platform lists: `existing_checks` in the JSON). Extra frameworks exercised inside other checks (>= 2 SDK symbols of the framework in the body; common frameworks dropped):

| framework | exercised inside |
|---|---|
| AVFAudio | AVFoundation.sample-buffer-renderers-synchronizer, AudioToolbox.auaudiounit-effects-auv3 |
| AppIntents | _AppIntents_UIKit.display-image-system-name |
| AudioToolbox | CoreMIDI.event-list-ump, CoreMIDI.ump-ci-network, CoreMIDI.virtual-loopback, UIKit.input-shake, _CoreHaptics_AudioToolbox.intended-spatial-experience |
| Contacts | ContactsUI.picker-and-contact-view-on-screen |
| CoreAudioTypes | AudioToolbox.auaudiounit-effects-auv3, AudioToolbox.audioqueue-offline-render, AudioToolbox.components-extaudiofile |
| CoreImage | AVFoundation.video-composition-compositor-ci-export, Vision.barcodes-from-coreimage-generators |
| CoreML | CreateMLComponents.logistic-classifier-export-coreml |
| CoreText | PDFKit.document-text-render |
| CryptoKit | Security.seckey-algorithms-exchange-interop |
| EventKit | EventKitUI.event-view-calendar-chooser |
| ExtensionFoundation | ExtensionKit.app-extension-process-xpc |
| GameplayKit | RealityKit.reality-file-roundtrip-usdz-load, SceneKit.animation-player-morpher-skinner, SceneKit.offscreen-render, SceneKit.scene-write-source-load-usdz, SceneKit.scnview-onscreen-continuous, SceneKit.shader-modifier-program-technique, SpriteKit.scene-physics-actions, _SceneKit_SwiftUI.scene-view-render, _SceneKit_SwiftUI.scene-view-renders |
| HealthKit | HealthKitUI.access-request-modifier, HealthKitUI.activity-ring-view |
| HomeKit | _HomeKit_SwiftUI.camera-view-hosted |
| ImageIO | LinkPresentation.loopback-fetch-og-tags-linkview, MediaAccessibility.caption-style-audible-image-caption, libAppleEXR.imageio-openexr-roundtrip |
| Network | Foundation.urlsession-websocket-loopback |
| PermissionKit | _PermissionKit_SwiftUI.communication-limits-button |
| RealityFoundation | RealityKit.ecs-system-animation-raycast, RealityKit.entities-meshes, RealityKit.lowlevel-mesh-texture-render, RealityKit.particles-audio-resource, RealityKit.physics-collision-events, RealityKit.reality-file-roundtrip-usdz-load, RealityKit.reality-renderer-offscreen, _RealityKit_SwiftUI.reality-view-in-window, _RealityKit_SwiftUI.reality-view-make, _RealityKit_SwiftUI.reality-view-make-update, _TabletopKit_RealityKit.entity-equipment-snapshot |
| SwiftData | _SwiftData_SwiftUI.query-in-hosted-view |
| TabletopKit | _TabletopKit_RealityKit.entity-equipment-snapshot, _TabletopKit_SwiftUI.tabletop-game-modifier-in-reality-view |
| UserNotifications | _UserNotifications_AppIntents.content-entity-identifiers |
| VideoToolbox | AVFoundation.assetreader-decoded-pixels-pixel-transfer |
| Vision | SwiftUI.image-renderer-layout |
| WidgetKit | RelevanceKit.contexts-widget-relevance |
| WorkoutKit | _WorkoutKit_SwiftUI.workout-preview-modifier, _WorkoutKit_SwiftUI.workout-preview-modifier-watch |
| _PhotosUI_SwiftUI | PhotosUI.photos-picker-view |

