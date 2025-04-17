import UIKit
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport

class AppDelegate: UIResponder, UIApplicationDelegate {
    static var isTrackingAuthorized: Bool = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Delay ATT request slightly to ensure app UI is ready
        let workItem = DispatchWorkItem {
            self.requestTrackingAuthorization {
                // Initialize Google Mobile Ads SDK on the main thread
                MobileAds.shared.start { initializationStatus in
                    // Log the initialization status of each adapter for debugging
                    let adapterStatuses = initializationStatus.adapterStatusesByClassName
                    var allInitializedSuccessfully = true

                    for (adapterName, status) in adapterStatuses {
                        let stateDescription: String
                        switch status.state {
                        case .notReady:
                            stateDescription = "Not Ready"
                            allInitializedSuccessfully = false
                        case .ready:
                            stateDescription = "Ready"
                        @unknown default:
                            stateDescription = "Unknown"
                            allInitializedSuccessfully = false
                        }
                        print("AdMob Adapter \(adapterName): \(stateDescription) - \(status.description)")
                    }

                    if allInitializedSuccessfully {
                        print("AdMob SDK initialized successfully")
                    } else {
                        print("AdMob SDK initialization encountered issues with some adapters")
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        return true
    }

    // MARK: - ATT Permission Request
    private func requestTrackingAuthorization(completion: @escaping () -> Void) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        print("ATT: Tracking authorized")
                        AppDelegate.isTrackingAuthorized = true
                        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                        print("IDFA: \(idfa)")
                    case .denied:
                        print("ATT: Tracking denied")
                        AppDelegate.isTrackingAuthorized = false
                    case .notDetermined:
                        print("ATT: Tracking not determined")
                        AppDelegate.isTrackingAuthorized = false
                    case .restricted:
                        print("ATT: Tracking restricted")
                        AppDelegate.isTrackingAuthorized = false
                    @unknown default:
                        print("ATT: Unknown tracking status")
                        AppDelegate.isTrackingAuthorized = false
                    }
                    completion()
                }
            }
        } else {
            AppDelegate.isTrackingAuthorized = true
            completion()
        }
    }

    // MARK: - UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }
}
