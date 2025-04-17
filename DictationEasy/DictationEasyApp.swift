import SwiftUI
import RevenueCat

// Configure RevenueCat as early as possible using a static initializer
private enum RevenueCatSetup {
    static let isConfigured: Bool = {
        Purchases.logLevel = .debug
        // Ensure you have set Purchases.configure in your AppDelegate or SceneDelegate if not here
        // Example: Purchases.configure(withAPIKey: "YOUR_API_KEY")
        // Make sure PurchasesDelegateHandler is assigned *after* configuration
        // Purchases.shared.delegate = PurchasesDelegateHandler.shared
        print("RevenueCat initialized check: Ensure Purchases.configure is called and delegate is set.")
        return true // Assume configured elsewhere for now based on original code
    }()
}

@main
struct DictationEasyApp: App {
    // If you are configuring Purchases here, do it before setting the delegate
    // Uncomment and replace YOUR_API_KEY if needed:
    // init() {
    //     Purchases.logLevel = .debug
    //     Purchases.configure(withAPIKey: "appl_JrvqFvcSqXNUHBASFBSctYGKygR") // Use your actual key
    //     Purchases.shared.delegate = PurchasesDelegateHandler.shared
    //     print("RevenueCat configured and delegate set in App init")
    // }

    // If configuring in AppDelegate:
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var settings = SettingsModel()
    @StateObject private var ocrManager = OCRManager()
    @StateObject private var ttsManager = TTSManager.shared // Use the shared instance
    @StateObject private var playbackManager = PlaybackManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    // Remove the explicit init() referencing RevenueCatSetup if configuration happens in AppDelegate
    // init() {
    //     // Ensure RevenueCat is configured by referencing the static property
    //     _ = RevenueCatSetup.isConfigured
    // }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(ocrManager)
                .environmentObject(ttsManager)
                .environmentObject(playbackManager)
                .environmentObject(subscriptionManager)
        }
    }
}

// Singleton to handle RevenueCat delegate methods
final class PurchasesDelegateHandler: NSObject, RevenueCat.PurchasesDelegate, Sendable {
    static let shared = PurchasesDelegateHandler()

    private override init() {
        super.init()
    }

    // --- Includes Debugging Print Statement ---
    nonisolated func purchases(_ purchases: RevenueCat.Purchases, receivedUpdated customerInfo: RevenueCat.CustomerInfo) {
        // Add log here to confirm the delegate method is called
        print("PurchasesDelegateHandler: Delegate receivedUpdated customerInfo.")

        // Ensure the notification is posted on the main thread
        DispatchQueue.main.async {
            print("PurchasesDelegateHandler: Posting subscriptionStatusDidChange notification on main thread.")
            NotificationCenter.default.post(name: .subscriptionStatusDidChange, object: nil)
            // Optionally, you could directly call SubscriptionManager here too,
            // but the notification pattern is generally cleaner.
            // Task { @MainActor in
            //     SubscriptionManager.shared.updateStatus(with: customerInfo)
            // }
        }
    }
}

// Notification name for subscription status changes
extension Notification.Name {
    static let subscriptionStatusDidChange = Notification.Name("subscriptionStatusDidChange")
}

// --- Ensure AppDelegate configures RevenueCat and sets the delegate ---
// Make sure your AppDelegate.swift looks something like this for configuration:
/*
import UIKit
import RevenueCat
import AppTrackingTransparency // Add if needed
import GoogleMobileAds // Add if needed


class AppDelegate: UIResponder, UIApplicationDelegate {

    static var isTrackingAuthorized: Bool = false // Make sure this exists if used

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // --- RevenueCat Configuration ---
        Purchases.logLevel = .debug
        // Make sure you are using the correct API key
        Purchases.configure(withAPIKey: "appl_JrvqFvcSqXNUHBASFBSctYGKygR")
        Purchases.shared.delegate = PurchasesDelegateHandler.shared // Assign the delegate *after* configuring
        print("RevenueCat configured and delegate set in AppDelegate")
        // --- End RevenueCat Configuration ---

        // --- Google Mobile Ads Configuration ---
        GADMobileAds.sharedInstance().start(completionHandler: { status in
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

    func applicationDidBecomeActive(_ application: UIApplication) {
        requestTrackingAuthorization() // Request again when app becomes active if needed
    }

    func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async { // Update on main thread
                    switch status {
                    case .authorized:
                        AppDelegate.isTrackingAuthorized = true
                        print("ATT: Tracking authorized")
                        // Configure ads for personalized content if needed
                    case .denied:
                        AppDelegate.isTrackingAuthorized = false
                        print("ATT: Tracking denied")
                        // Configure ads for non-personalized content (npa=1)
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
*/
