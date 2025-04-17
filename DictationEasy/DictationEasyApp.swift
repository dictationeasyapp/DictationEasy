import SwiftUI
import RevenueCat

// Configure RevenueCat as early as possible using a static initializer
private enum RevenueCatSetup {
    static let isConfigured: Bool = {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_JrvqFvcSqXNUHBASFBSctYGKygR")
        Purchases.shared.delegate = PurchasesDelegateHandler.shared as PurchasesDelegate
        print("RevenueCat initialized in RevenueCatSetup")
        return true
    }()
}

@main
struct DictationEasyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var settings = SettingsModel()
    @StateObject private var ocrManager = OCRManager()
    @StateObject private var ttsManager = TTSManager.shared // Use the shared instance
    @StateObject private var playbackManager = PlaybackManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        // Ensure RevenueCat is configured by referencing the static property
        _ = RevenueCatSetup.isConfigured
    }

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

    nonisolated func purchases(_ purchases: RevenueCat.Purchases, receivedUpdated customerInfo: RevenueCat.CustomerInfo) {
        // Ensure the notification is posted on the main thread
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .subscriptionStatusDidChange, object: nil)
        }
    }
}

// Notification name for subscription status changes
extension Notification.Name {
    static let subscriptionStatusDidChange = Notification.Name("subscriptionStatusDidChange")
}
