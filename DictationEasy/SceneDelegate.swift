import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)

        // Create the root view using ContentView with environment objects
        let contentView = ContentView()
            .environmentObject(SettingsModel())
            .environmentObject(OCRManager())
            .environmentObject(TTSManager.shared) // Use shared instance
            .environmentObject(PlaybackManager())
            .environmentObject(SubscriptionManager.shared) // Add SubscriptionManager

        // Create a UIHostingController to host the SwiftUI ContentView
        let hostingController = UIHostingController(rootView: contentView)

        // Set the hosting controller as the root view controller
        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
