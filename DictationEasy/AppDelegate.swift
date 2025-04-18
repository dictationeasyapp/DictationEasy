import UIKit
import RevenueCat
import GoogleMobileAds
import AppTrackingTransparency

class AppDelegate: UIResponder, UIApplicationDelegate {
    static var isTrackingAuthorized: Bool = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // --- RevenueCat Configuration ---
        guard let apiKey = loadRevenueCatAPIKey() else {
            fatalError("Failed to load RevenueCat API key from Secrets.plist")
        }
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = PurchasesDelegateHandler.shared
        print("RevenueCat configured and delegate set in AppDelegate")

        // Initialize SubscriptionManager ONCE (removed duplicate call)
        SubscriptionManager.shared.initializeManager()
        print("AppDelegate: SubscriptionManager initialized")

        // --- AdMob Configuration ---
        // Run initialization on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async {
            MobileAds.shared.start { status in
                // Extract data on background thread to avoid data races
                let adapterStatuses = status.adapterStatusesByClassName
                var logLines: [String] = ["AdMob SDK initialization status: \(adapterStatuses)"]
                var notReadyAdapters: [String] = []
                for (adapterClassName, adapterStatus) in adapterStatuses {
                    if adapterStatus.state != .ready {
                        notReadyAdapters.append("\(adapterClassName): \(adapterStatus.description)")
                    }
                }
                if !notReadyAdapters.isEmpty {
                    logLines.append("AdMob SDK initialization issues: \(notReadyAdapters.joined(separator: ", "))")
                }
                // Log on main thread using captured strings
                DispatchQueue.main.async {
                    logLines.forEach { print($0) }
                }
            }
        }

        requestTrackingAuthorization()
        return true
    }

    private func loadRevenueCatAPIKey() -> String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let apiKey = dict["RevenueCatAPIKey"] as? String else {
            print("AppDelegate: Failed to load RevenueCat API key")
            return nil
        }
        return apiKey
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Avoid re-prompting if ATT status is already determined
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            if status == .notDetermined {
                requestTrackingAuthorization()
            } else {
                // Check for status changes (e.g., user modified in Settings)
                let currentAuth = status == .authorized
                if currentAuth != AppDelegate.isTrackingAuthorized {
                    AppDelegate.isTrackingAuthorized = currentAuth
                    NotificationCenter.default.post(name: .ATTStatusUpdated, object: nil)
                    print("AppDelegate: ATT status changed to \(currentAuth)")
                } else {
                    print("AppDelegate: ATT status unchanged (\(status.rawValue)), skipping request")
                }
            }
        }
    }

    func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            // Only request if status is not determined
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                ATTrackingManager.requestTrackingAuthorization { status in
                    DispatchQueue.main.async {
                        let previousStatus = AppDelegate.isTrackingAuthorized
                        AppDelegate.isTrackingAuthorized = status == .authorized
                        print("AppDelegate: ATT status set to \(AppDelegate.isTrackingAuthorized)")
                        // Notify only if status changed
                        if previousStatus != AppDelegate.isTrackingAuthorized {
                            NotificationCenter.default.post(name: .ATTStatusUpdated, object: nil)
                        }
                    }
                }
            } else {
                print("AppDelegate: ATT request skipped, status already determined")
            }
        } else {
            // Pre-iOS 14: tracking allowed by default
            if !AppDelegate.isTrackingAuthorized {
                AppDelegate.isTrackingAuthorized = true
                print("AppDelegate: Pre-iOS 14, tracking authorized by default")
            }
        }
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
