import UIKit
import RevenueCat
import AppTrackingTransparency
import GoogleMobileAds

class AppDelegate: UIResponder, UIApplicationDelegate {

    static var isTrackingAuthorized: Bool = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // --- RevenueCat Configuration ---
                Purchases.logLevel = .debug

                // Load the API key from Secrets.plist
                guard let apiKey = loadRevenueCatAPIKey() else {
                    fatalError("Failed to load RevenueCat API key from Secrets.plist")
                }

                Purchases.configure(withAPIKey: apiKey)
                Purchases.shared.delegate = PurchasesDelegateHandler.shared
                print("RevenueCat configured and delegate set in AppDelegate")

                SubscriptionManager.shared.initializeManager()
                // --- End RevenueCat Configuration ---

        // *** NEW: Initialize SubscriptionManager AFTER RevenueCat config ***
        SubscriptionManager.shared.initializeManager()
        // *** END NEW ***

        // --- End RevenueCat Configuration ---

        // --- Google Mobile Ads Configuration ---
        MobileAds.shared.start(completionHandler: { status in
             print("AdMob SDK initialization status: \(status.adapterStatusesByClassName)")
             // Check adapter status and handle initialization issues if needed
             let adapterStatuses = status.adapterStatusesByClassName
             var notReadyAdapters: [String] = []
             for (adapterClassName, status) in adapterStatuses {
                 if status.state != .ready {
                    notReadyAdapters.append("\(adapterClassName): \(status.description)")
                 }
             }
             if !notReadyAdapters.isEmpty {
                 print("AdMob SDK initialization encountered issues with some adapters:")
                 notReadyAdapters.forEach { print("  - \($0)") }
             }
         })
        // --- End Google Mobile Ads Configuration ---


        // Request App Tracking Transparency authorization
        requestTrackingAuthorization()

        return true
    }
    // Helper method to load the RevenueCat API key from Secrets.plist
        private func loadRevenueCatAPIKey() -> String? {
            guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
                  let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
                  let apiKey = dict["RevenueCatAPIKey"] as? String else {
                return nil
            }
            return apiKey
        }

    func applicationDidBecomeActive(_ application: UIApplication) {
        requestTrackingAuthorization() // Request again when app becomes active if needed
        // Optionally trigger a subscription status check when returning to foreground
        // SubscriptionManager.shared.checkSubscriptionStatus()
    }

    func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async { // Update on main thread
                    switch status {
                    case .authorized:
                        AppDelegate.isTrackingAuthorized = true
                        print("ATT: Tracking authorized")
                    case .denied:
                        AppDelegate.isTrackingAuthorized = false
                        print("ATT: Tracking denied")
                    case .notDetermined:
                        AppDelegate.isTrackingAuthorized = false
                        print("ATT: Tracking not determined")
                    case .restricted:
                        AppDelegate.isTrackingAuthorized = false
                        print("ATT: Tracking restricted")
                    @unknown default:
                        AppDelegate.isTrackingAuthorized = false
                        print("ATT: Tracking unknown status")
                    }
                    // Ensure AdMob request is updated based on status if needed here or in BannerAdView
                }
            }
        } else {
            // Fallback for earlier iOS versions (tracking is allowed by default)
            AppDelegate.isTrackingAuthorized = true
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
