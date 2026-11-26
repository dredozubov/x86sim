// x86games: SpriteKit and SceneKit content for the agent tools (tests/ax/games_e2e.py). Neither scene sets any
// accessibility: the snapshot shows their *named* nodes as `node` elements (simax_engines.m).
//   SpriteKit (top): Player (still), Enemy (moves left and right), Coin (removed when tapped), Secret (hidden: never an
//   element), Far (outside the view: never an element)
//   SceneKit (bottom): Crate (still), Ball (moves), Wall (in front of Hidden Box, which is covered: never an element),
//   Behind (behind the camera: never an element), a named camera and light (no geometry: never elements)
// Taps are counted per node name and shown in plain SwiftUI text ("sprite taps: Player=1 ...", "scene taps: ...").
import SceneKit
import SpriteKit
import SwiftUI
import UIKit

final class Model: ObservableObject {
    @Published var sprite: [String: Int] = [:]
    @Published var scene: [String: Int] = [:]
    static func line(_ d: [String: Int]) -> String { d.keys.sorted().map { "\($0)=\(d[$0]!)" }.joined(separator: " ") }
}

final class Sprites: SKScene {
    var tapped: (String) -> Void = { _ in }
    override func didMove(to view: SKView) {
        backgroundColor = .darkGray
        scaleMode = .resizeFill
        let player = SKSpriteNode(color: .systemBlue, size: CGSize(width: 60, height: 60))
        player.name = "Player"
        player.position = CGPoint(x: 70, y: 110)
        addChild(player)
        let enemy = SKSpriteNode(color: .systemRed, size: CGSize(width: 50, height: 50))
        enemy.name = "Enemy"
        enemy.position = CGPoint(x: 160, y: 60)
        enemy.run(.repeatForever(.sequence([.moveBy(x: 140, y: 0, duration: 1.5), .moveBy(x: -140, y: 0, duration: 1.5)])))
        addChild(enemy)
        let coin = SKShapeNode(circleOfRadius: 22)
        coin.fillColor = .systemYellow
        coin.name = "Coin"
        coin.position = CGPoint(x: 300, y: 150)
        addChild(coin)
        let secret = SKSpriteNode(color: .green, size: CGSize(width: 40, height: 40))
        secret.name = "Secret"
        secret.isHidden = true
        secret.position = CGPoint(x: 200, y: 150)
        addChild(secret)
        let far = SKSpriteNode(color: .green, size: CGSize(width: 40, height: 40))
        far.name = "Far"
        far.position = CGPoint(x: 5000, y: 100)
        addChild(far)
        let caption = SKLabelNode(text: "sprites")
        caption.position = CGPoint(x: 60, y: 15)
        caption.fontSize = 14
        addChild(caption)   // unnamed: no element
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let e = childNode(withName: "Enemy") else { return }
        X86Test.log("sprite-touch-down", true, "at \(t.location(in: self)) Enemy \(e.position)")
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        if let e = childNode(withName: "Enemy") { X86Test.log("sprite-touch-up", true, "at \(t.location(in: self)) Enemy \(e.position)") }
        for n in nodes(at: t.location(in: self)) {
            guard let name = n.name else { continue }
            tapped(name)
            if name == "Coin" { n.removeFromParent() }
            return
        }
    }
}

struct SpriteBox: UIViewRepresentable {
    @ObservedObject var m: Model
    func makeUIView(context: Context) -> SKView {
        let v = SKView()
        v.accessibilityIdentifier = "sprite-view"
        let s = Sprites(size: CGSize(width: 390, height: 220))
        s.tapped = { name in
            m.sprite[name, default: 0] += 1
            X86Test.log("sprite-tap", true, name)
        }
        v.presentScene(s)
        return v
    }
    func updateUIView(_ v: SKView, context: Context) {}
}

struct SceneBox: UIViewRepresentable {
    @ObservedObject var m: Model
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.accessibilityIdentifier = "scene-view"
        v.backgroundColor = .black
        let s = SCNScene()
        let cam = SCNNode()
        cam.name = "camera"
        cam.camera = SCNCamera()
        cam.position = SCNVector3(0, 0, 10)
        s.rootNode.addChildNode(cam)
        let light = SCNNode()
        light.name = "light"
        light.light = SCNLight()
        light.light!.type = .omni
        light.position = SCNVector3(0, 5, 10)
        s.rootNode.addChildNode(light)
        func box(_ name: String, _ w: CGFloat, _ h: CGFloat, _ color: UIColor, _ p: SCNVector3) -> SCNNode {
            let g = SCNBox(width: w, height: h, length: 1, chamferRadius: 0)
            g.firstMaterial?.diffuse.contents = color
            let n = SCNNode(geometry: g)
            n.name = name
            n.position = p
            s.rootNode.addChildNode(n)
            return n
        }
        _ = box("Crate", 1.6, 1.6, .brown, SCNVector3(-2.5, 0.5, 0))
        let ball = SCNNode(geometry: SCNSphere(radius: 0.7))
        ball.geometry!.firstMaterial?.diffuse.contents = UIColor.orange
        ball.name = "Ball"
        ball.position = SCNVector3(0, -1, 0)
        ball.runAction(.repeatForever(.sequence([.moveBy(x: 1.5, y: 0, z: 0, duration: 1.5), .moveBy(x: -1.5, y: 0, z: 0, duration: 1.5)])))
        s.rootNode.addChildNode(ball)
        _ = box("Wall", 2.4, 2.4, .gray, SCNVector3(2.5, 0.8, 1))
        _ = box("Hidden Box", 1, 1, .green, SCNVector3(2.5, 0.8, -2))
        _ = box("Behind", 1, 1, .purple, SCNVector3(0, 0, 14))
        v.scene = s
        v.pointOfView = cam
        v.isPlaying = true
        v.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coord.tap(_:))))
        return v
    }
    func updateUIView(_ v: SCNView, context: Context) {}
    func makeCoordinator() -> Coord { Coord(m) }
    final class Coord: NSObject {
        let m: Model
        init(_ m: Model) { self.m = m }
        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let v = g.view as? SCNView else { return }
            let name = v.hitTest(g.location(in: v), options: nil).first?.node.name ?? "nothing"
            m.scene[name, default: 0] += 1
            X86Test.log("scene-tap", true, name)
        }
    }
}

struct Root: View {
    @StateObject var m = Model()
    var body: some View {
        VStack(spacing: 6) {
            SpriteBox(m: m).frame(height: 220)
            Text("sprite taps: \(Model.line(m.sprite))").accessibilityIdentifier("sprite-taps")
            Text("scene taps: \(Model.line(m.scene))").accessibilityIdentifier("scene-taps")
            SceneBox(m: m).frame(height: 300)
            Spacer()
        }
        .onAppear { X86Test.log("start-ui", true) }
    }
}

@main
struct X86GamesApp: App {
    init() { X86Test.reset() }
    var body: some Scene { WindowGroup { Root() } }
}
