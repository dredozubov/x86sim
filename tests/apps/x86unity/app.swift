// x86unity: simax's Unity reader (host/simax/simax_unity.m) against a stand-in engine. Frameworks/UnityFramework.framework
// here is fakeunity.m (built by build-unity.sh), NOT Unity: it exports IL2CPP's API over a tiny uGUI scene and a
// UnityView that draws it with layers. The view has no accessibility of its own, as a Unity game without the
// accessibility plugin: everything the snapshot lists in it comes from the reader (tests/ax/games_e2e.py unity-fake).
import SwiftUI
import UIKit

struct UnityBox: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let path = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework/UnityFramework"
        guard dlopen(path, RTLD_NOW) != nil, let cls = NSClassFromString("UnityView") as? UIView.Type else {
            X86Test.log("engine", false, String(cString: dlerror()))
            return UIView()
        }
        return cls.init(frame: .zero)
    }
    func updateUIView(_ v: UIView, context: Context) {}
}

@main
struct X86UnityApp: App {
    init() { X86Test.reset() }
    var body: some Scene { WindowGroup { UnityBox().ignoresSafeArea(edges: .bottom) } }
}
