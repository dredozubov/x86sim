// x86perm: a permission prompt whose app goes away (tests/ax/perm_e2e.py). On launch it logs the current authorization
// ("X86TEST x86perm status PASS location=<n>", CLAuthorizationStatus: 0 not determined, 2 denied, 4 when in use) and
// asks for it (requestWhenInUseAuthorization: the system's location prompt), then logs every change. Launch argument
// "contacts": the same for Contacts (CNAuthorizationStatus) instead of Core Location.
import Contacts
import CoreLocation
import UIKit

final class VC: UIViewController, CLLocationManagerDelegate {
    let lm = CLLocationManager()
    let label = UILabel()
    let contacts = CommandLine.arguments.contains("contacts")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                                     label.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48)])
        if contacts {
            let s = CNContactStore.authorizationStatus(for: .contacts)
            show("contacts=\(s.rawValue)")
            CNContactStore().requestAccess(for: .contacts) { ok, err in
                DispatchQueue.main.async {
                    self.show("contacts=\(CNContactStore.authorizationStatus(for: .contacts).rawValue) granted=\(ok)\(err.map { " \($0.localizedDescription)" } ?? "")")
                }
            }
        } else {
            lm.delegate = self   // locationManagerDidChangeAuthorization reports the initial status too
            show("location=\(lm.authorizationStatus.rawValue)")
            lm.requestWhenInUseAuthorization()
        }
    }

    func show(_ s: String) {
        label.text = "x86perm\n\(s)"
        X86Test.log("status", true, s)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        show("location=\(manager.authorizationStatus.rawValue) changed")
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = VC()
        w.makeKeyAndVisible()
        window = w
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        X86Test.reset()
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting s: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: nil, sessionRole: s.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}
