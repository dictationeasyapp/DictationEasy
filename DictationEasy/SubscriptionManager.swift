import Foundation
import RevenueCat
import SwiftUI
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // --- Define the Entitlement ID as a class constant ---
    // !!! IMPORTANT: Double-check this value matches your RevenueCat dashboard !!!
    private let premiumEntitlementID = "DictationEasy Premium"
    // --- END ---

    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var availablePackages: [RevenueCat.Package] = []
    @Published var customerInfo: CustomerInfo?

    private var cancellables = Set<AnyCancellable>()

    // *** init only sets up observer ***
    private init() {
        // Add observer in init
        NotificationCenter.default.publisher(for: .subscriptionStatusDidChange)
            .sink { [weak self] _ in
                print("SubscriptionManager: Received subscriptionStatusDidChange notification, checking status.")
                self?.checkSubscriptionStatus() // Re-check status on notification
            }
            .store(in: &cancellables)
        print("SubscriptionManager: Initialized and observer set.")
        // Calls to checkSubscriptionStatus() and fetchAvailablePackages() are deferred to initializeManager()
    }

    // *** Function to be called AFTER RevenueCat configuration ***
    func initializeManager() {
        print("SubscriptionManager: initializeManager() called.")
        // Now perform the initial fetches
        checkSubscriptionStatus()
        fetchAvailablePackages()
    }

    // Function to check status using getCustomerInfo (useful for initial load or manual refresh)
    func checkSubscriptionStatus() {
        // Add check to ensure configuration happened
        guard Purchases.isConfigured else {
             print("SubscriptionManager: checkSubscriptionStatus skipped - Purchases not configured yet.")
             return
        }
        print("SubscriptionManager: checkSubscriptionStatus() executing...") // Add log
        RevenueCat.Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isPremium = false
                self.customerInfo = nil
                print("SubscriptionManager: Error checking subscription status: \(error)")
                return
            }
            guard let customerInfo = customerInfo else {
                self.errorMessage = "Failed to retrieve customer info"
                self.isPremium = false
                self.customerInfo = nil
                print("SubscriptionManager: Error - customerInfo is nil during checkSubscriptionStatus")
                return
            }
            self.processUpdatedCustomerInfo(customerInfo)
            print("SubscriptionManager: checkSubscriptionStatus completed.")
        }
    }

    // New function to update status directly from provided CustomerInfo (e.g., from purchase callback or delegate)
    func updateStatus(with customerInfo: CustomerInfo) {
        print("SubscriptionManager: Updating status directly with provided CustomerInfo.")
        self.processUpdatedCustomerInfo(customerInfo)
    }

    // Centralized logic to process CustomerInfo and update published properties
    // --- Includes Enhanced Debugging ---
    private func processUpdatedCustomerInfo(_ customerInfo: CustomerInfo) {
        // --- Start Enhanced Debugging ---
        print("SubscriptionManager.processUpdatedCustomerInfo: Processing CustomerInfo...")
        print("  Original Purchase Date: \(String(describing: customerInfo.originalPurchaseDate))")
        print("  First Seen: \(String(describing: customerInfo.firstSeen))")
        print("  Management URL: \(String(describing: customerInfo.managementURL))")
        print("  All Purchased Skus: \(customerInfo.allPurchasedProductIdentifiers)")
        print("  Active Subscriptions: \(customerInfo.activeSubscriptions)")
        print("  Entitlements Dictionary: \(customerInfo.entitlements.all)")

        // *** Use the class constant ***
        if let premiumEntitlement = customerInfo.entitlements[premiumEntitlementID] {
            print("  Found Entitlement '\(premiumEntitlementID)':") // Use constant in log
            print("    isActive: \(premiumEntitlement.isActive)")
            print("    willRenew: \(premiumEntitlement.willRenew)")
            print("    periodType: \(premiumEntitlement.periodType)")
            print("    latestPurchaseDate: \(String(describing: premiumEntitlement.latestPurchaseDate))")
            print("    originalPurchaseDate: \(String(describing: premiumEntitlement.originalPurchaseDate))")
            print("    expirationDate: \(String(describing: premiumEntitlement.expirationDate))")
            print("    store: \(premiumEntitlement.store)")
            print("    productIdentifier: \(premiumEntitlement.productIdentifier)")
            print("    isSandbox: \(premiumEntitlement.isSandbox)")
            print("    unsubscribeDetectedAt: \(String(describing: premiumEntitlement.unsubscribeDetectedAt))")
            print("    billingIssueDetectedAt: \(String(describing: premiumEntitlement.billingIssueDetectedAt))")
        } else {
            print("  Entitlement '\(premiumEntitlementID)' NOT FOUND in customerInfo.entitlements") // Use constant in log
        }
        // --- End Enhanced Debugging ---

        // *** Use the class constant ***
        let isActive = customerInfo.entitlements[premiumEntitlementID]?.isActive == true
        self.customerInfo = customerInfo // Store the latest customer info
        self.isPremium = isActive
        // *** Use the class constant ***
        print("SubscriptionManager: Processed CustomerInfo - Updated isPremium to \(isActive), using entitlement ID '\(premiumEntitlementID)': \(String(describing: customerInfo.entitlements[premiumEntitlementID]))")
    }


    func fetchAvailablePackages() {
         // Add check to ensure configuration happened
         guard Purchases.isConfigured else {
             print("SubscriptionManager: fetchAvailablePackages skipped - Purchases not configured yet.")
             return
         }
        print("SubscriptionManager: fetchAvailablePackages() executing...") // Add log
        RevenueCat.Purchases.shared.getOfferings { [weak self] offerings, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                print("SubscriptionManager: Error fetching packages: \(error)")
                return
            }
            if let packages = offerings?.current?.availablePackages {
                self.availablePackages = packages
                print("SubscriptionManager: Fetched \(packages.count) available packages")
                 // Add logging for package details
                 packages.forEach { package in
                    print("  Package: \(package.identifier), Product: \(package.storeProduct.productIdentifier), Price: \(package.localizedPriceString)")
                 }
            } else {
                print("SubscriptionManager: No available packages found in current offering")
                self.availablePackages = [] // Ensure it's empty if none found
            }
        }
    }

    func purchasePackage(_ package: RevenueCat.Package) {
         // Add check to ensure configuration happened
         guard Purchases.isConfigured else {
             print("SubscriptionManager: purchasePackage skipped - Purchases not configured yet.")
             self.errorMessage = "Initialization error. Please restart the app." // User-facing message
             return
         }
        self.isLoading = true
        self.errorMessage = nil
        print("SubscriptionManager: Attempting to purchase package: \(package.identifier) (\(package.storeProduct.productIdentifier))")
        RevenueCat.Purchases.shared.purchase(package: package) { [weak self] transaction, customerInfo, error, userCancelled in
            guard let self = self else { return }
            // Ensure isLoading is set to false on the main thread
            DispatchQueue.main.async {
                 self.isLoading = false
            }

            if userCancelled {
                print("SubscriptionManager: Purchase cancelled by user")
                // Optionally clear error message if it was set previously
                self.errorMessage = nil
                return
            }

            if let error = error {
                 // --- Corrected Error Code Handling ---
                 if let rcError = error as? RevenueCat.ErrorCode {
                     // If the error is directly a RevenueCat.ErrorCode
                     print("SubscriptionManager: Purchase RevenueCat Error Code: \(rcError)")
                 } else if let nsError = error as NSError?, // Check if it's an NSError
                           // Corrected: Use the standard NSUnderlyingErrorKey
                           let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                     // Print the underlying error's domain and code
                     print("SubscriptionManager: Purchase Underlying Error: Domain=\(underlyingError.domain), Code=\(underlyingError.code)")
                 } else {
                     // Fallback for general errors
                     print("SubscriptionManager: Purchase encountered a non-RevenueCat or unknown error type.")
                 }
                 // --- End Corrected Error Code Handling ---

                 self.errorMessage = error.localizedDescription
                 print("SubscriptionManager: Purchase error details: \(error)") // Log the full error object
                 return
            }

            guard let customerInfo = customerInfo else {
                self.errorMessage = "Failed to retrieve customer info after purchase"
                print("SubscriptionManager: Error - customerInfo is nil after purchase, attempting fetch.")
                self.checkSubscriptionStatus() // Fallback to fetching if nil
                return
            }
            print("SubscriptionManager: Purchase successful, updating status with received CustomerInfo.")
            self.updateStatus(with: customerInfo)
        }
    }


    func restorePurchases() {
         // Add check to ensure configuration happened
         guard Purchases.isConfigured else {
             print("SubscriptionManager: restorePurchases skipped - Purchases not configured yet.")
             self.errorMessage = "Initialization error. Please restart the app." // User-facing message
             return
         }
        self.isLoading = true
        self.errorMessage = nil
        print("SubscriptionManager: Attempting to restore purchases.")
        RevenueCat.Purchases.shared.restorePurchases { [weak self] customerInfo, error in
            guard let self = self else { return }
            // Ensure isLoading is set to false on the main thread
             DispatchQueue.main.async {
                  self.isLoading = false
             }

            if let error = error {
                self.errorMessage = error.localizedDescription
                print("SubscriptionManager: Restore error: \(error)")
                return
            }
            guard let customerInfo = customerInfo else {
                self.errorMessage = "Failed to retrieve customer info after restore"
                print("SubscriptionManager: Error - customerInfo is nil after restore, attempting fetch.")
                self.checkSubscriptionStatus() // Fallback to fetching if nil
                return
            }
            print("SubscriptionManager: Restore successful, updating status with received CustomerInfo.")
            self.updateStatus(with: customerInfo) // Process the restored info
            if !self.isPremium {
                // Only set error message if restore finished BUT user is not premium
                self.errorMessage = "No active subscription found to restore 沒有找到可恢復的活躍訂閱"
                print("SubscriptionManager: Restore completed, but no active premium entitlement found.")
            } else {
                 // Clear any previous error message on successful restore with premium
                 self.errorMessage = nil
                 print("SubscriptionManager: Restore completed, active premium entitlement found.")
            }
        }
    }
}
