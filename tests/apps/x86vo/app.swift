// x86vo: the engines' screen-reader switch (simax_engines.m). Frameworks/Flutter.framework here is a stand-in
// (engine.c, built by build-vo.sh), not Flutter: like Flutter's engine it asks UIAccessibilityIsVoiceOverRunning()
// and listens for UIAccessibilityVoiceOverStatusDidChangeNotification. Once the snapshot first reads the app, the
// engine sees VoiceOver on and was told so; the app's own code still sees it off.
import SwiftUI
import UIKit

final class Model: ObservableObject {
    @Published var line = "engine: not loaded"
    let engine: UnsafeMutableRawPointer? = dlopen(Bundle.main.bundlePath + "/Frameworks/Flutter.framework/Flutter", RTLD_NOW)
    var timer: Timer?
    init() {
        typealias State = @convention(c) () -> Int32
        typealias Count = @convention(c) () -> Int32
        guard let e = engine, let s = dlsym(e, "engine_voiceover"), let c = dlsym(e, "engine_notifications") else { return }
        let state = unsafeBitCast(s, to: State.self), count = unsafeBitCast(c, to: Count.self)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            let l = "engine voiceover: \(state() != 0 ? "on" : "off") notified: \(count()) app voiceover: \(UIAccessibility.isVoiceOverRunning ? "on" : "off")"
            if self?.line != l { self?.line = l; X86Test.log("vo", true, l) }
        }
    }
}

struct Root: View {
    @StateObject var m = Model()
    var body: some View {
        VStack { Text(m.line).accessibilityIdentifier("vo-line") }.padding()
    }
}

@main
struct X86VoApp: App {
    init() { X86Test.reset() }
    var body: some Scene { WindowGroup { Root() } }
}
