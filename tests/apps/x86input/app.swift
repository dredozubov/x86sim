// x86input: text entry and hosted system UI for the agent tools (tests/ax/mcp_e2e.py: type, picker, safari).
// A UIKit UITextField (Return counted by textFieldShouldReturn), a SwiftUI TextField (onSubmit), a multi-line
// UITextView (Return is a newline there), an SFSafariViewController (SafariViewService) and a PHPickerViewController
// (the photos picker, an extension hosted in the app's window). Each event is logged as an X86TEST line and shown on
// screen, so the agent can read it in a snapshot.
import PhotosUI
import SafariServices
import SwiftUI
import UIKit

final class Model: ObservableObject {
    @Published var uikitReturns = 0
    @Published var uikitText = ""
    @Published var swiftText = ""
    @Published var swiftSubmits = 0
    @Published var swiftSubmitted = ""
    @Published var viewText = ""
    @Published var picked = "none"
    @Published var safari = "closed"
}

struct UIKitField: UIViewRepresentable {
    @ObservedObject var m: Model
    func makeUIView(context: Context) -> UITextField {
        let f = UITextField()
        f.placeholder = "UIKit field"
        f.borderStyle = .roundedRect
        f.accessibilityIdentifier = "uikit-field"
        f.returnKeyType = .done
        f.delegate = context.coordinator
        f.addTarget(context.coordinator, action: #selector(Coord.changed(_:)), for: .editingChanged)
        return f
    }
    func updateUIView(_ v: UITextField, context: Context) {}
    func makeCoordinator() -> Coord { Coord(m) }
    final class Coord: NSObject, UITextFieldDelegate {
        let m: Model
        init(_ m: Model) { self.m = m }
        @objc func changed(_ f: UITextField) { m.uikitText = f.text ?? "" }
        func textFieldShouldReturn(_ f: UITextField) -> Bool {
            m.uikitText = f.text ?? ""
            m.uikitReturns += 1
            X86Test.log("uikit-return", true, "\(m.uikitReturns) \(m.uikitText)")
            return false
        }
    }
}

struct TextViewBox: UIViewRepresentable {
    @ObservedObject var m: Model
    func makeUIView(context: Context) -> UITextView {
        let v = UITextView()
        v.font = .preferredFont(forTextStyle: .body)
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.separator.cgColor
        v.accessibilityIdentifier = "textview"
        v.delegate = context.coordinator
        return v
    }
    func updateUIView(_ v: UITextView, context: Context) {}
    func makeCoordinator() -> Coord { Coord(m) }
    final class Coord: NSObject, UITextViewDelegate {
        let m: Model
        init(_ m: Model) { self.m = m }
        func textViewDidChange(_ v: UITextView) { m.viewText = v.text }
    }
}

final class Presenter: NSObject, PHPickerViewControllerDelegate, SFSafariViewControllerDelegate {
    static let shared = Presenter()
    var m: Model?
    func top() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
    func picker() {
        var c = PHPickerConfiguration()
        c.selectionLimit = 1
        c.filter = .images
        let p = PHPickerViewController(configuration: c)
        p.delegate = self
        top()?.present(p, animated: true)
        X86Test.log("picker-open", true)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        m?.picked = results.isEmpty ? "cancelled" : "\(results.count) picked"
        X86Test.log("picker-done", true, m?.picked ?? "")
        picker.dismiss(animated: true)
    }
    func safari() {
        let s = SFSafariViewController(url: URL(string: "http://127.0.0.1:9/x86input")!)
        s.delegate = self
        top()?.present(s, animated: true)
        m?.safari = "open"
        X86Test.log("safari-open", true)
    }
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        m?.safari = "closed again"
        X86Test.log("safari-done", true)
    }
}

struct Root: View {
    @StateObject var m = Model()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                UIKitField(m: m).frame(height: 36)
                Text("uikit returns: \(m.uikitReturns) text: \(m.uikitText)").accessibilityIdentifier("uikit-returns")
                TextField("SwiftUI field", text: $m.swiftText).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("swiftui-field")
                    .onSubmit {
                        m.swiftSubmits += 1
                        m.swiftSubmitted = m.swiftText
                        X86Test.log("swiftui-submit", true, "\(m.swiftSubmits) \(m.swiftText)")
                    }
                Text("swiftui submits: \(m.swiftSubmits) submitted: \(m.swiftSubmitted)").accessibilityIdentifier("swiftui-submits")
                TextViewBox(m: m).frame(height: 90)
                Text("textview lines: \(m.viewText.components(separatedBy: "\n").count)").accessibilityIdentifier("textview-lines")
                Button("Open Safari") { Presenter.shared.safari() }
                Text("safari: \(m.safari)").accessibilityIdentifier("safari-state")
                Button("Pick Photo") { Presenter.shared.picker() }
                Text("picked: \(m.picked)").accessibilityIdentifier("picked")
            }.padding()
        }
        .onAppear {
            Presenter.shared.m = m
            X86Test.log("start-ui", true)
        }
    }
}

@main
struct X86InputApp: App {
    init() { X86Test.reset() }
    var body: some Scene { WindowGroup { Root() } }
}
