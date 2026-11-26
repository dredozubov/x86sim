// x86pixels: text the accessibility tree cannot see, for the agent tools' OCR (snapshot [ocr], tests/ax/pixels_e2e.py).
// Default: a full-screen MTKView (no accessibility at all) that shows a game menu: a title, a score and three buttons
// drawn as pixels (Core Graphics into a texture, blitted into the drawable by Metal), dark. A tap on a drawn button
// (a gesture on the view, hit-tested against the drawn rects) shows "Tapped <name>" and logs X86TEST tap PASS <name>.
// Launch argument "cg": a light screen whose text a plain UIView draws in draw(_:) (no accessibility elements, not a
// Metal view: read only by snapshot ocr=true) plus one real UIButton "Real Button" (its label must not come back as
// [ocr] text). The strings drawn are fixed: the e2e check scores OCR precision / recall against them.
import MetalKit
import UIKit

let menuButtons = ["Start Game", "Options", "High Scores"]

/// Lays out and draws the menu (points), shared by the Metal and the Core Graphics screens
struct Menu {
    var tapped: String?
    func buttonRects(_ size: CGSize) -> [(String, CGRect)] {
        menuButtons.enumerated().map { i, n in
            (n, CGRect(x: size.width / 2 - 110, y: size.height * 0.42 + CGFloat(i) * 84, width: 220, height: 56))
        }
    }
    func draw(_ cg: CGContext, _ size: CGSize, dark: Bool) {
        let fg = dark ? UIColor.white : UIColor.black
        (dark ? UIColor(red: 0.07, green: 0.08, blue: 0.14, alpha: 1) : UIColor(white: 0.97, alpha: 1)).setFill()
        cg.fill(CGRect(origin: .zero, size: size))
        func text(_ s: String, _ font: UIFont, _ color: UIColor, center: CGPoint) {
            let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let sz = (s as NSString).size(withAttributes: a)
            (s as NSString).draw(at: CGPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2), withAttributes: a)
        }
        text("PIXEL QUEST", .boldSystemFont(ofSize: 40), fg, center: CGPoint(x: size.width / 2, y: size.height * 0.18))
        text("Score: 1250", .systemFont(ofSize: 22), fg.withAlphaComponent(0.8), center: CGPoint(x: size.width / 2, y: size.height * 0.27))
        for (n, r) in buttonRects(size) {
            let p = UIBezierPath(roundedRect: r, cornerRadius: 14)
            (dark ? UIColor(red: 0.2, green: 0.45, blue: 0.95, alpha: 1) : UIColor(red: 0.85, green: 0.9, blue: 1, alpha: 1)).setFill()
            p.fill()
            text(n, .systemFont(ofSize: 24, weight: .semibold), fg, center: CGPoint(x: r.midX, y: r.midY))
        }
        text(tapped.map { "Tapped \($0)" } ?? "Choose an option", .systemFont(ofSize: 18), fg, center: CGPoint(x: size.width / 2, y: size.height * 0.84))
    }
    func hit(_ p: CGPoint, _ size: CGSize) -> String? { buttonRects(size).first { $0.1.contains(p) }?.0 }
}

final class MetalMenuView: MTKView, MTKViewDelegate {
    var menu = Menu()
    var queue: MTLCommandQueue?
    var texture: MTLTexture?
    var dirty = true

    init() {
        let dev = MTLCreateSystemDefaultDevice()
        super.init(frame: .zero, device: dev)
        framebufferOnly = false   // the drawable is a blit destination
        colorPixelFormat = .bgra8Unorm
        queue = dev?.makeCommandQueue()
        delegate = self
        isPaused = true
        enableSetNeedsDisplay = true
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
        X86Test.log("metal", dev != nil, dev?.name ?? "no device")
    }
    required init(coder: NSCoder) { fatalError() }

    @objc func tap(_ g: UITapGestureRecognizer) {
        guard let n = menu.hit(g.location(in: self), bounds.size) else { return }
        menu.tapped = n
        dirty = true
        X86Test.log("tap", true, n)
        setNeedsDisplay()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { dirty = true }

    func draw(in view: MTKView) {
        guard let dev = device, let q = queue, let d = currentDrawable else { return }
        let w = Int(drawableSize.width), h = Int(drawableSize.height)
        guard w > 0, h > 0 else { return }
        if dirty || texture?.width != w || texture?.height != h {
            // the menu drawn by Core Graphics at the drawable's pixel size, uploaded to a texture
            let scale = drawableSize.width / max(bounds.width, 1)
            let cs = CGColorSpaceCreateDeviceRGB()
            guard let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return }
            cg.translateBy(x: 0, y: CGFloat(h))
            cg.scaleBy(x: scale, y: -scale)
            UIGraphicsPushContext(cg)
            menu.draw(cg, bounds.size, dark: true)
            UIGraphicsPopContext()
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
            td.usage = [.shaderRead]
            guard let t = dev.makeTexture(descriptor: td), let data = cg.data else { return }
            t.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: data, bytesPerRow: w * 4)
            texture = t
            dirty = false
        }
        guard let t = texture, let cb = q.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() else { return }
        blit.copy(from: t, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: w, height: h, depth: 1),
                  to: d.texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()
        cb.present(d)
        cb.commit()
    }
}

/// Text drawn by a plain view: no elements, not a Metal view
final class DrawnMenuView: UIView {
    var menu = Menu()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func tap(_ g: UITapGestureRecognizer) {
        guard let n = menu.hit(g.location(in: self), bounds.size) else { return }
        menu.tapped = n
        X86Test.log("tap", true, n)
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        menu.draw(cg, bounds.size, dark: false)
    }
}

func makeRoot() -> UIView {
    if CommandLine.arguments.contains("cg") {
        let root = UIView()
        let drawn = DrawnMenuView()
        drawn.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(drawn)
        let b = UIButton(type: .system)
        b.setTitle("Real Button", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addAction(UIAction { _ in X86Test.log("real-button", true) }, for: .touchUpInside)
        root.addSubview(b)
        NSLayoutConstraint.activate([
            drawn.leadingAnchor.constraint(equalTo: root.leadingAnchor), drawn.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            drawn.topAnchor.constraint(equalTo: root.topAnchor), drawn.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            b.centerXAnchor.constraint(equalTo: root.centerXAnchor), b.bottomAnchor.constraint(equalTo: root.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
        return root
    }
    return MetalMenuView()
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        let vc = UIViewController()
        vc.view = makeRoot()
        w.rootViewController = vc
        w.makeKeyAndVisible()
        window = w
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        X86Test.reset()
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting s: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: nil, sessionRole: s.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}
