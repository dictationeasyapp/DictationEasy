import UIKit
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport
import RevenueCat

class AppDelegate: UIResponder, UIApplicationDelegate {
    static var isTrackingAuthorized: Bool = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Request ATT permission before initializing AdMob and RevenueCat
        requestTrackingAuthorization {
            // Initialize the Google Mobile Ads SDK
            MobileAds.initialize()
            print("AdMob SDK initialized")

            // Initialize RevenueCat
            Purchases.logLevel = .debug
            Purchases.configure(withAPIKey: "appl_JrvqFvcSqXNUHBASFBSctYGKygR")
            print("RevenueCat initialized")
        }
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
