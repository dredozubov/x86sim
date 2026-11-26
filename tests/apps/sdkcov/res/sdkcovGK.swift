// makes res/sdkcovGK.sks: an iOS simulator program, built on Linux and run on a phone (or under Darling) by
// res/sdkcovRes.sh (`sdkcovGK [DIR]` writes DIR/sdkcovGK.sks, default the program's own directory). An SKScene archived
// as Xcode's scene editor does with a GameplayKit scene (keys root + _gkScene): one entity with a node component and a
// 2D agent
import SpriteKit
import GameplayKit
let scene = SKScene(size: CGSize(width: 320, height: 240)); scene.name = "sdkcovScene"
let s = SKNode(); s.name = "hero"; s.position = CGPoint(x: 40, y: 50); scene.addChild(s)
let l = SKNode(); l.name = "spawn"; l.position = CGPoint(x: 200, y: 100); scene.addChild(l)
let gk = GKScene(); gk.rootNode = scene
let e = GKEntity(); e.addComponent(GKSKNodeComponent(node: s)); e.addComponent(GKAgent2D()); gk.addEntity(e)
let a = NSKeyedArchiver(requiringSecureCoding: false)
a.encode(scene, forKey: "root"); a.encode(gk, forKey: "_gkScene"); a.finishEncoding()
let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
try! a.encodedData.write(to: URL(fileURLWithPath: dir).appendingPathComponent("sdkcovGK.sks"))
// read back as GKScene(fileNamed:) does (that one looks only in the main bundle)
let u = try! NSKeyedUnarchiver(forReadingFrom: a.encodedData); u.requiresSecureCoding = false
let g = u.decodeObject(forKey: "_gkScene") as? GKScene
g?.rootNode = u.decodeObject(forKey: "root") as? SKScene
print(g.map { "root \(String(describing: ($0.rootNode as? SKScene)?.name)) children \(($0.rootNode as? SKScene)?.children.map { $0.name ?? "?" } ?? []) entities \($0.entities.count) comps \($0.entities.first?.components.map { "\(type(of: $0))" } ?? []) node \(String(describing: $0.entities.first?.component(ofType: GKSKNodeComponent.self)?.node.name))" } ?? "nil")
