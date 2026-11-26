# simax: the accessibility reader

`host/simax/simax.m` (`libsimax.dylib`, arm64 per platform) shows a phone's screen to agents as accessibility
elements. The host side is `tools/launcher/core/src/ax.rs`: the MCP tools `snapshot`, `tap` and the others, and
`x86sim snapshot` / `x86sim-ax`.

## Loading

`mksimdevice.py` sets `X86SIM_AX_DYLIB` in every simulator process's environment. libsimshim's `shim_ax_init`
dlopens that dylib only when UIKitCore is among the images loaded at launch, so daemons never load it. Its
constructor waits for `UIApplicationDidFinishLaunchingNotification`, which means many daemons that link UIKit
(sharingd, mobileassetd and others) never open a socket. An app whose executable links no UIKit and loads it later
(a Unity app: its `main` loads UnityFramework, which links UIKit) gets it too: libsimshim watches image loads and
dlopens it from the main queue once UIKitCore arrives, and the reader, finding the application already running,
starts at once. `X86SIM_AX_OFF=1` turns it off, and `X86SIM_AX_LOG=1` logs to stderr.

The first `tree` request in a process loads UIKit's accessibility bundles by turning accessibility automation on,
as XCUITest does (`_AXSApplicationAccessibilitySetEnabled`, `_AXSSetAutomationEnabled`, `_UIAccessibilityInitialize`).
Without the bundles, SpringBoard icons, SwiftUI views and most system UI have no labels. The setting is stored in
the device, so apps launched later load the bundles at startup. It costs about 0.1-0.2 s on the first snapshot of a
running process.

## Endpoints

Each application listens on a Unix socket next to the phone's frame ring:

```
/run/user/<uid>/x86sim-ax-<SIMULATOR_UDID>-<pid>.sock     (in Darling: /Volumes/SystemRoot/run/user/...)
/run/user/<uid>/x86sim-ax-<SIMULATOR_UDID>-<pid>.fg       exists while the process is on screen
```

`.fg` is created when the app enters the foreground or becomes active, and removed when it enters the background
or terminates; scene and window notifications update it too, so a view service whose scene or full-screen
`_UIHostedWindow` comes up (watchOS's QuickboardViewService, the text input sheet) counts as on screen, and so does a
window of a `_UIHostedWindowScene`, the scene an ExtensionKit UI extension or remote view service draws an app's sheet
in (the photos picker of `PHPickerViewController`, SafariViewService for `SFSafariViewController`). SpringBoard
keeps its own. The host only asks processes that have one. Connections are
non-blocking, because a process RunningBoard suspended (a poster extension, for example) never accepts. A process
that did not answer is given 80 ms the next time, until it answers again. `mksimdevice.py` removes the previous
boot's files, and the host removes the files of a socket that refuses connections.

One listener thread serves one client at a time. Threads that exit (`pthread_exit`) are avoided on purpose.

## Requests

The client sends one JSON object per line and gets one JSON line back for each. Requests run on the main queue. A
request that is not answered within `timeout` seconds (default 5) gets `{"error": "busy: ..."}`. Every answer
carries `pid`, `bundle`, `process`, `state` (`active`, `inactive`, `background`, `none`), `screen`
`[w, h, scale]` in points, `orient`, `windows` (`class`, `level`, `key`, `frame`, `orient`, `screen`, back to
front), `ms` and `wait_ms`.

`screen` and `orient` are those of the process's key window (else its largest): the bounds of the screen it is on
and its scene's `UIInterfaceOrientation` (1 portrait, 2 upside down, 3 landscape left, 4 landscape right). UIKit's
screen coordinates turn with the interface, not with the device: a portrait-only app on a phone held sideways keeps
portrait coordinates, so the host turns touches by the interface orientation, not by the device's. `main_screen`
says whether that screen is `UIScreen.mainScreen` and `display` gives its display id (a two-screen phone).

| op | arguments | answer |
|---|---|---|
| `info` | | the fields above; SpringBoard's also `locked` (`SBLockScreenManager isUILocked`) and `suspended` (pids FrontBoard suspended) |
| `tree` | `fg` (only walk when on screen), `all` (include elements scrolled out of view), `noax`, `timeout` | plus `elements`, `focus` (oid of the first responder), `focus_item` (the focus engine's item: `oid`, `class`, `frame`, `label`; tvOS's remote focus), `animating`, `web_pending`, `pixels` (below) |
| `type` | `text`, `clear`, `submit` (the host sends no `submit` nor newlines: it presses the Return key itself) | `typed`, `field` (class), `oid` (the field), `value` |
| `focus` | | the first responder (see below) |
| `control` | `oid` | what control the element is and the values it takes (see below) |
| `setvalue` | `oid`, `value` (text, or a list: one per picker wheel), `quiet` | sets it as a touch would (see below) |
| `scroll` | `oid` | `ok` (`accessibilityScrollToVisible`, else `scrollRectToVisible` in the nearest scroll view) |
| `activate` | `oid`, `tap` | `ok` (`accessibilityActivate`); with `tap`, when that answers NO, a tap made in the process at the element's activation point (a UITouch with an IOHIDEvent digitizer event through `sendEvent:`): `tapped`, `at` |
| `scrollby` | `dir` (up down left right), `amount` (part of the view) | scrolls the largest visible scroll view that scrolls that way: `ok`, `moved`, `view` |
| `probe` | | every scene (`state`) and window (hidden or not) of the process, for debugging |
| `ax` | | loads the accessibility bundles |
| `action` | `oid`, `name` (`increment`, `decrement`, `scroll` with `dir`, `escape`, `magic_tap`, `custom` with `custom`: the action's name) | `ok`, `by` (the class that took it), `value` (the element's value after it), `note` |

An element contains `oid` (the object's address in hex; web elements use `<webview oid>#<key>`), `role`,
`label`, `value`, `id`, `hint`, `frame` `[x, y, w, h]` in screen points (an iPadOS window's elements offset by
its scene's place on the display, the FBSSceneSettings frame; on visionOS the window's own points), `traits`,
`enabled` (only when
false), `selected`, `focused`, `offscreen`, `win` (an index into `windows`), `depth`, `in` (the label of the
enclosing container), `class`, `key` and, for web elements, `web`, `href` and `frame_url` (content of an iframe).

`key` names what stays when the object does not. A table or collection view recycles its cells while it scrolls,
so the same object shows another row. An element inside a cell gets `<list oid>:<section>.<item>/<role><n>`, its
row's index path and the n-th element of that role in the cell. A web element gets `dom:<tag>.<n>`: a number the
DOM node keeps for the life of its document (a `WeakMap` in the isolated world), prefixed by a random tag of that
document.

The walk follows the containment VoiceOver uses. An accessibility element is a leaf, except that a cell holding a
text field or switch is looked into. A container provides `accessibilityElements`, or a count and an index. A
plain view provides its subviews. Hidden views and `accessibilityElementsHidden` are skipped. A child with
`accessibilityViewIsModal` hides its siblings. Off-screen elements are dropped unless `all` is set.

Roles: `textfield`, `searchfield`, `switch`, `adjustable`, `key`, `tabbar`, `link`, `button`, `heading`,
`image`, `text`, `icon` (SpringBoard), `node` (a game's object: Engines below), `element` (anything else with a label,
value or identifier), and the web roles below.

### `focus`: who has the keyboard

`focus` (simax_actions.m) answers the process's first responder without a walk: `focused` (false: none, nothing
else), `oid`, `class`, `text_input` (it takes typed text: `UIKeyInput`), `kind` (`textfield`, `securefield`,
`searchfield`, `textview`, `web` (WebKit's content view: the page's `document.activeElement` is the field),
`keyinput`, `other`), `frame` (screen points), `inside` (the oids of the views it is in, nearest first, up to 40),
and for a native field `value` (a secure field's as dots), `placeholder`, `label`, `id`. The host's `type` with a
target (core/src/axact.rs) taps the element, then asks this on every new frame until the field is the element, inside
it, or under its centre (a SwiftUI node over its UITextField); a web field: until the DOM's focus is on it.

### `control` and `setvalue`: sliders, switches, pickers

`control` (simax_controls.m) finds the UIKit control an element stands for: the element itself, a view it is inside
(a segment of a UISegmentedControl; a date picker's own wheels stand for the UIDatePicker), or, for a SwiftUI node, the
control under it (the same place, its centre on it, or inside it: a Toggle's node is its whole row). It answers
`kind` (`slider`, `switch`, `stepper`, `segmented`, `picker`, `datepicker`, `adjustable` for any other element with
the adjustable trait, `none`), `class` and the values: `min` / `max` / `value` (slider; a SwiftUI slider's UISlider
runs 0 to 1 whatever the app's range), `min` / `max` / `step` / `value` (stepper), `values` and `value` (segment titles;
switch on / off), `mode` / `value` / `min` / `max` (date picker: ISO dates, `HH:mm` for times), `components` (each
wheel's row titles), `titles` (false: the rows draw no text simax can read, SwiftUI's wheels) and `value`.

`setvalue` sets it the way a touch leaves it: the control's value, then its ValueChanged actions (a UIKit target, a
SwiftUI binding), one step at a time for a stepper, and for a picker `selectRow:inComponent:` followed by the
delegate's `pickerView:didSelectRow:inComponent:` (what the end of a scroll calls). Values: a number or a percentage
of the range (`"50%"`) for a slider; `on` / `off` for a switch; a number, or `+N` / `-N` steps, for a stepper (SwiftUI's
Stepper keeps its count in the app: absolute values answer an error with `swiftui`, and the host steps toward the
number the stepper's label shows); a segment's title (or `#index`); per picker wheel a row's title, exact, prefix or
part of it (`""` keeps a wheel); for a date picker `2026-05-01`, `2026-05-01T14:30` or `14:30`; for an adjustable
element the value it should read (increments / decrements until it does). A picker without titles takes `#row` on the
wheel the element is (`quiet`: the delegate is not told, while the host reads each row's text from the wheel's
accessibility value); text answers an error with `titles: false`, `rows`, `row`, `component`. The answer is the
control's `kind` and `value` afterwards and `was`, or an `error` naming what the control takes.

### The inspector (`tree` with `full`)

The Accessibility Inspector (`tools/launcher/core/src/axinspect.rs`, the audit `axaudit.rs`) asks `tree` with
`full`. Every element then has `more`: `class`, `traits_raw` and `traits_all` (every trait's name, private text entry
and editing bits too), `lang` (`accessibilityLanguage`), `custom_actions` and `rotors` (their names), `input_labels`,
`interactive` (`accessibilityRespondsToUserInteraction`), `activation` (the activation point on the screen), `modal`,
`view` and `controller` (the view the element is, or the nearest one among its containers, and that view's view
controller), `path` (the containers above it as VoiceOver sees them: classes with their label or identifier, plain
`UIView`s and UIKit's private wrappers left out, the last 12), `tap` (`control`: a `UIControl`; `gesture`: a view with
a tap or long press recognizer), and for the text it draws (a label, field, text view, a button's title, a cell's
labels) `font` (`size`, `bold`, `name`), `dynamic_type` (`adjustsFontForContentSizeCategory`), `fg` (the text color
resolved for the view's traits, RGBA 0-255 and alpha) and `truncated` (the text of a label cut off: one line wider than
its bounds, or more lines than its height shows). The answer also has `hidden`: interactive views VoiceOver cannot
reach, that is controls and views with a tap or long press recognizer that are not an element, not inside one and hold
none, with `class`, `kind`, `frame`, `why` (`accessibilityElementsHidden` on it or an ancestor, or
`isAccessibilityElement` NO with nothing inside), `oid` and `controller`. Views as large as half the window (a tap to
dismiss the keyboard), scroll views, windows and UIKit's private classes are left out. A full tree costs roughly twice a
plain one.

`action` is what VoiceOver does to an element: `increment` / `decrement` call `accessibilityIncrement` /
`accessibilityDecrement` (`ok` when the value changed); `scroll` calls `accessibilityScroll:` on the element and up its
containers and responders until one takes it (VoiceOver's three-finger swipe directions: `up` shows what is below,
`next`, `previous`), else moves the nearest scroll view by most of a page; `escape` and `magic_tap` call
`accessibilityPerformEscape` / `accessibilityPerformMagicTap` up the responder chain to the application's delegate
(without an `oid`: from the first responder or the front window), and an escape nobody takes pops the navigation stack
or dismisses the presented controller, as UIKit's own handler does; `custom` runs the custom action with that name
(exact, then a part of it, case blind). Activate stays the `activate` op.

`animating` is true while a one-shot Core Animation animation runs in one of the process's windows, such as a push,
a sheet or an alert appearing. Looping animations, such as spinners or the caret, do not count. The host waits
for it after an action.

### WebKit

The accessibility tree of a web page lives in the WebContent process, so each `WKWebView` on screen is read through
its DOM instead. A script runs in an isolated content world (`WKContentWorld.defaultClientWorld`), so page scripts
and CSP do not affect it. It returns the visible links, buttons, form fields (with values), selects,
headings, images with alt text, ARIA roles and text blocks. Their CSS rects are converted to screen points through
the web view's scroll view (content = page coordinates times `zoomScale`). The web view itself is reported as a
`webview` element whose label is the page title and whose value is its URL.

Every frame is read, iframes of the same or another origin included: WebKit's frame tree (`-[WKWebView _frames:]`)
gives each frame's `WKFrameInfo`, and the script runs in each (`evaluateJavaScript:inFrame:inContentWorld:`). A
frame's walk also reports its `<iframe>` elements: URL, content box (border and padding excluded) and whether they
are shown. A child frame is matched to its `<iframe>` by URL, else in document order, and its elements are moved by
the content box and clipped to it. Elements of a hidden iframe, or of one that cannot be placed, are left out.

Web content gets about 80% of the request's `timeout`. Frames that have not answered by then are left out and
counted in `web_pending`, so a busy WebContent process does not cost the whole snapshot.

## Engines

Content UIKit's accessibility does not describe: game views and engines that draw everything themselves. Their readers
are `host/simax/simax_engines.m` (and one file per engine), hooked into the walk: a game view's elements are added where
the view is, in the view's window, with frames in screen points as any other.

### Game views: SpriteKit and SceneKit nodes

`host/simax/simax_engines.m`. A game draws its world in one view, so UIKit's accessibility sees one view and nothing in
it unless the developer gave nodes accessibility. In an `SKView` or `SCNView`, every *named* node that shows becomes an
element besides what the view's own accessibility lists (SpriteKit lists label nodes' text by itself; a node listed
that way is not listed twice): role `node`, `label` the node's name, `class` the node's class, `oid` the node.

- SpriteKit: the presented scene's tree. Hidden nodes, nodes with alpha under 0.01 and their subtrees are skipped. The
  frame is `calculateAccumulatedFrame` (the node with its children) taken from its parent's coordinates through the
  scene to the view (`convertPoint:toNode:`, `convertPointToView:`), clipped to the view; a node outside the view is not
  listed.
- SceneKit: the root node's tree, by presentation node (where actions and animations put it now). A node's bounding box
  (its subtree's) is projected corner by corner (`projectPoint:`); corners behind the camera are dropped and a node with
  none in front is not listed, nor is one without geometry (a camera, a light). A node is covered, and not listed, when
  a hit test through its center (`SCNHitTestSearchModeAll`, hidden nodes ignored) meets another node first and it only
  later.
- `key` is `sk:<name>#<n>` / `scn:<name>#<n>`, the n-th node of that name in the tree, so a moving node keeps its ref,
  and `tap "Player"`, `wait_for "Enemy" gone=true` work on games built with names.


### Engines that wait for a screen reader

Flutter builds its accessibility tree (the `SemanticsObject`s under a `FlutterView`) only while it believes an assistive
technology runs; so do Unity 2023.2+ (`AccessibilityHierarchy`, `AssistiveSupport`), Unreal's Slate accessibility and
Godot 4.5+ (AccessKit). Flutter's own simulator builds turn semantics on anyway. A device build converted for the
simulator (tests/apps/flutter_demo, Flutter stable with Dart 3.14) turned out to show its tree in x86Sim without the
switch too, since accessibility automation is on in the process; the switch is there for engine versions and engines that
ask only whether VoiceOver runs. At the first `tree` request of a process (none for `noax`), simax
looks for those engines' images: `Flutter.framework`, `UnityFramework.framework`, and the image that defines Unreal's
`FIOSView` or Godot's `GDTView` / `GodotView` (both link into the app's executable). In each, the pointers its calls to
`UIAccessibilityIsVoiceOverRunning` go through (`__got`, `__auth_got`, `__la_symbol_ptr`) are rebound to a function
that answers yes, and `UIAccessibilityVoiceOverStatusDidChangeNotification` is posted, so the engine looks again and
builds its tree. Nothing else in the process sees VoiceOver on: UIKit, the app's own code and other frameworks still get
no. A process without those engines is not touched. Flutter's `Semantics(identifier:)` is the element's `id`
(`tap id:...`). `X86SIM_AX_LOG=1` logs `engines: screen reader on for flutter:<pointers rebound>`.


### Unity (IL2CPP)

`host/simax/simax_unity.m`. A `UnityView` that lists no accessibility elements of its own (a game without an
accessibility plugin or `AccessibilityHierarchy`) is read through IL2CPP's reflection API, which `UnityFramework`
exports (`il2cpp_*`), on the main thread, where Unity's player loop runs:

- uGUI and TextMeshPro: active `Button` (role `button`, label: its first `Text` / `TMP_Text` child), `Toggle` (`switch`,
  value `1` / `0`), `Slider` (`adjustable`, value, `min`, `max`), `InputField` / `TMP_InputField` (`textfield`: the
  placeholder's text as label, the text as value, `focused` from `isFocused`), and `Text` / `TMP_Text` (`text`) that is
  not part of a control. `enabled` false when `IsInteractable()` is false. The frame is the `RectTransform`'s world
  corners through its root canvas: a screen space overlay canvas draws in screen pixels; a camera or world space one
  goes through its camera (`WorldToScreenPoint`; world space without one: `Camera.main`). Unity's screen pixels (origin
  bottom left, `Screen.width` / `height`) are scaled to the `UnityView`'s points.
- UI Toolkit: each `UIDocument`'s visual tree: `Button`, `Toggle`, `Slider` / `SliderInt`, `TextField`, `Label`, their
  `worldBound` from the panel to the screen through `RuntimePanelUtils.ScreenToPanel`. A control's insides are part of
  it.
- Game objects: active ones with a name and an enabled renderer that a camera sees (`isVisible`) or an enabled
  collider (3D or 2D) are `node` elements, as SpriteKit's and SceneKit's: their `bounds` projected with `Camera.main`,
  corners behind it dropped.
- Objects are found with `Object.FindObjectsByType` (2023.1+) or `FindObjectsOfType`. A game that never calls them
  has both managed wrappers stripped (a real Unity 6.3 IL2CPP build); the engine still registers the native call
  behind them, which `il2cpp_resolve_icall` finds by name
  (`UnityEngine.Object::FindObjectsByType(System.Type,UnityEngine.FindObjectsInactive,UnityEngine.FindObjectsSortMode)`).
  Without that too, the loaded scenes' root objects are walked down their transforms (`SceneManager.GetSceneAt`,
  `Scene.GetRootGameObjects`, `GetComponents`).
- `key` is `unity:<instance id>` (`GetInstanceID`: the object's for its life), `uitk:<document id>/<child indexes>` for
  UI Toolkit; `oid` is the component (the game object for a node).

`type` goes to Unity first: a focused `InputField` / `TMP_InputField` gets the text through its `text` setter (which
fires `onValueChanged`; `clear` replaces, else it appends), the field's `TouchScreenKeyboard`, when it has one up, the
same text (the field reads it back every frame), and then `onEndEdit` is invoked. A focused UI Toolkit `TextField` gets
its `value` set (a `ChangeEvent`). `insertText:` reaches neither. Without a focused Unity field, `type` goes on as for
any app. Engines without exported reflection (Unreal, Godot, cocos2d) have no reader of their own.

### Views that draw their own pixels (`pixels`)

`tree` also lists the views on screen that render without UIKit's views (`simax_pixels.m`): a view whose layer is a
`CAMetalLayer` or `CAEAGLLayer` (MTKView, GLKView, game engines such as Unity's, Flutter), an `SKView` or an `SCNView`,
covering at least 1/16 of its window. They are noted while the walk passes them, also when they set
`accessibilityElementsHidden` (a game hiding nothing but saying so). Each has `frame` (screen points, clipped to the
window), `class`, `kind` (`metal`, `opengl`, `spritekit`, `scenekit`), `win` and `oid`; at most 16. The DOM walk gives a
`<canvas>` the role `canvas`.

The host (`core/src/ocr.rs`) reads the text of each one that covers a quarter of the screen and has no element of its
app inside (an element as large as the view itself does not count) from the frame with OCR, and adds it as `text`
elements with `ocr: true`. A canvas element without an accessible name becomes such a view (one with a name stays, as
an `image`). Text in the status bar's area is left out (its elements say it). The snapshot's `ocr` says which frame was
read (`frame`, the ring's sequence number), how long it took (`ms`), whether that frame had been read before
(`cached`), the views read and what failed (`error`: no models, offline). `snapshot` with `ocr` reads the whole screen
and keeps the text no element says: not inside a labelled element smaller than a quarter of the screen, not an
element's label within 60 x 40 points. An OCR element's `key` and `oid` are `ocr:<text>@<x/32>,<y/32>`.

The engine is ocrs (rten runtime, pure Rust) with its text detection and recognition models, downloaded once into
`~/.cache/x86sim/ocr` and checked by SHA-256 (`X86SIM_OCR_MODELS_URL`: another place to fetch them from). The picture is
read at one pixel per point (`X86SIM_OCR_PPP`); the detector's fixed input size is met by tiles overlapping by a third.
Results are cached per frame (in the process and in `<state dir>/ocr-cache.json`), keyed by the ring, the boot and the
frame number. `X86SIM_OCR=0` turns it off; a Vision Pro has no flat screen to read.

## Host

`ax.rs` asks every `.fg` process in parallel and merges the answers into one `Snapshot`. It assigns layers:
SpringBoard windows are `system` (alerts, banners, Control Center) or `home`, status bar elements are `status`,
SpringBoard's iPadOS window chrome is `window` (it also gives the windows' stacking order: elements under another
app's window are clipped to what shows or marked `covered`), and everything else is `app`. The other platforms'
homes: tvOS's HeadBoard (TVSystemUIService's clock corner is `status`), a watch face and Carousel's app grid,
visionOS's RealityLauncher (RealityHUD is `status`). On an Apple TV, `tap` moves the focus with arrow keys onto the
target and presses select; on a Vision Pro it uses `activate` with `tap`, and `scroll` uses `scrollby`.

Refs are kept in `<state dir>/ax-refs.json`, keyed by the frame ring's inode and
birth time, which change with every boot. An element keeps its ref while it has the same `key` in the same process
(a cell's element also needs the same label, identifier or object, or else the rows moved), or else while it is the
same object with the same role and label or identifier. Failing that, it takes the ref of the only previous element
of the same app with the same role and identifier, or of the nearest one with the same role and label. Two keyed
elements of one process with different keys never trade refs on a shared label, such as the "by" and "|" on every
row of a web page, unless that label is unique on both sides.

Touches are given in the points of an element's window, or for a bare point in the front app's (on an iPad with
windowed apps, the top window's app). Those points are the display's: simax has already moved an iPadOS window's
elements by its scene's place and turned SpringBoard's portrait-only switcher window into the interface. The host
turns them by that window's interface orientation onto the panel. An unfolded iPhone Duo's touches go to its inner
screen's display (`@<id> touch`, its native turn added), and settling and screenshots use that screen's ring. A
snapshot says `· inner screen` / `· outer screen` and `· landscape` in its first line.

A process on screen that does not answer while SpringBoard lists it as `suspended` (a poster extension, a view
service whose app closed it) is not on screen: the host removes its `.fg` without a word, and simax makes it again
when the process comes back. `locked` from SpringBoard becomes the snapshot's `locked` and a `locked:` line. The status
bar's time is the text it draws (its accessibility label is the wall clock, also under a status bar override), unless
the label starts with that text (it adds AM / PM).

A process on screen that does not answer is reported in `busy` by bundle and pid the first time ("no answer in
6.0 s"). After that it gets 80 ms per snapshot and is not reported again until it answers. When no process on
screen answers at all, the snapshot fails and names them.

`type` sends the text without its newlines and presses the Return key (HID) for each newline and for `submit`:
`insertText:` of a newline is a space in a SwiftUI `TextField` and submits no web form, while Return submits a
single-line field and is a new line in a text view. simhid can hold a key up to about a second (keyboard attach, the
guard after a touch) and does not say when it went, so the host waits 1-1.2 s after each Return.

After an action, the host waits for the frame ring to go quiet (350 ms, at most 4 s) and for `animating` to clear
(at most 6 s), then takes the snapshot.
