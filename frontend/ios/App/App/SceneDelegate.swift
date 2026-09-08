import UIKit
import Capacitor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = CAPBridgeViewController()
        window?.makeKeyAndVisible()

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)

        // Check if app was launched via safemesh:// deep link (from Widget or Siri)
        if let url = connectionOptions.urlContexts.first?.url {
            handleSafeMeshURL(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        SceneDelegateProxy.shared.scene(scene, openURLContexts: URLContexts)

        if let url = URLContexts.first?.url {
            handleSafeMeshURL(url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        SceneDelegateProxy.shared.scene(scene, continue: userActivity)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Broadcast app foreground notification so React permission/location state re-checks automatically
        NotificationCenter.default.post(name: Notification.Name("SafeMeshAppWillEnterForeground"), object: nil)
    }

    private func handleSafeMeshURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "safemesh" else { return }

        let target = (url.host ?? "") + url.path
        if target.contains("sos") {
            let source: EmergencyTriggerSource = target.contains("siri") ? .siri : .widget
            SafeMeshEmergencyEngine.shared.activateSOS(source: source)
        }
    }
}
