import Foundation
import RevenueCat
import SwiftUI
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    private let premiumEntitlementID = "DictationEasy Premium"
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var availablePackages: [RevenueCat.Package] = []
    @Published var customerInfo: CustomerInfo?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: .subscriptionStatusDidChange)
            .sink { [weak self] _ in
                print("SubscriptionManager: Received subscriptionStatusDidChange notification, checking status.")
                self?.checkSubscriptionStatus()
            }
            .store(in: &cancellables)
        print("SubscriptionManager: Initialized and observer set.")
    }

    func initializeManager() {
        print("SubscriptionManager: initializeManager() called.")
        checkSubscriptionStatus()
        // Removed fetchAvailablePackages() (deferred to SubscriptionView.onAppear)
    }

    func checkSubscriptionStatus() {
        guard Purchases.isConfigured else {
            print("SubscriptionManager: checkSubscriptionStatus skipped - Purchases not configured yet.")
            return
        }
        print("SubscriptionManager: checkSubscriptionStatus() executing...")
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

    func updateStatus(with customerInfo: CustomerInfo) {
        print("SubscriptionManager: Updating status directly with provided CustomerInfo.")
        self.processUpdatedCustomerInfo(customerInfo)
    }

    private func processUpdatedCustomerInfo(_ customerInfo: CustomerInfo) {
        print("SubscriptionManager.processUpdatedCustomerInfo: Processing CustomerInfo...")
        print("  Original Purchase Date: \(String(describing: customerInfo.originalPurchaseDate))")
        print("  First Seen: \(String(describing: customerInfo.firstSeen))")
        print("  Management URL: \(String(describing: customerInfo.managementURL))")
        print("  All Purchased Skus: \(customerInfo.allPurchasedProductIdentifiers)")
        print("  Active Subscriptions: \(customerInfo.activeSubscriptions)")
        print("  Entitlements Dictionary: \(customerInfo.entitlements.all)")
        if let premiumEntitlement = customerInfo.entitlements[premiumEntitlementID] {
            print("  Found Entitlement '\(premiumEntitlementID)':")
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
            print("  Entitlement '\(premiumEntitlementID)' NOT FOUND in customerInfo.entitlements")
        }

        let isActive = customerInfo.entitlements[premiumEntitlementID]?.isActive == true
        self.customerInfo = customerInfo
        self.isPremium = isActive
        print("SubscriptionManager: Processed CustomerInfo - Updated isPremium to \(isActive), using entitlement ID '\(premiumEntitlementID)': \(String(describing: customerInfo.entitlements[premiumEntitlementID]))")
    }

    func fetchAvailablePackages() {
        guard Purchases.isConfigured else {
            print("SubscriptionManager: fetchAvailablePackages skipped - Purchases not configured yet.")
            return
        }
        print("SubscriptionManager: fetchAvailablePackages() executing...")
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
                packages.forEach { package in
                    print("  Package: \(package.identifier), Product: \(package.storeProduct.productIdentifier), Price: \(package.localizedPriceString)")
                }
            } else {
                print("SubscriptionManager: No available packages found in current offering")
                self.availablePackages = []
            }
        }
    }

    func purchasePackage(_ package: RevenueCat.Package) {
        guard Purchases.isConfigured else {
            print("SubscriptionManager: purchasePackage skipped - Purchases not configured yet.")
            self.errorMessage = "Initialization error. Please restart the app."
            return
        }
        self.isLoading = true
        self.errorMessage = nil
        print("SubscriptionManager: Attempting to purchase package: \(package.identifier) (\(package.storeProduct.productIdentifier))")
        RevenueCat.Purchases.shared.purchase(package: package) { [weak self] transaction, customerInfo, error, userCancelled in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if userCancelled {
                print("SubscriptionManager: Purchase cancelled by user")
                self.errorMessage = nil
                return
            }
            if let error = error {
                if let rcError = error as? RevenueCat.ErrorCode {
                    print("SubscriptionManager: Purchase RevenueCat Error Code: \(rcError)")
                } else if let nsError = error as NSError?,
                          let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("SubscriptionManager: Purchase Underlying Error: Domain=\(underlyingError.domain), Code=\(underlyingError.code)")
                } else {
                    print("SubscriptionManager: Purchase encountered a non-RevenueCat or unknown error type.")
                }
                self.errorMessage = error.localizedDescription
                print("SubscriptionManager: Purchase error details: \(error)")
                return
            }
            guard let customerInfo = customerInfo else {
                self.errorMessage = "Failed to retrieve customer info after purchase"
                print("SubscriptionManager: Error - customerInfo is nil after purchase, attempting fetch.")
                self.checkSubscriptionStatus()
                return
            }
            print("SubscriptionManager: Purchase successful, updating status with received CustomerInfo.")
            self.updateStatus(with: customerInfo)
        }
    }

    func restorePurchases() {
        guard Purchases.isConfigured else {
            print("SubscriptionManager: restorePurchases skipped - Purchases not configured yet.")
            self.errorMessage = "Initialization error. Please restart the app."
            return
        }
        self.isLoading = true
        self.errorMessage = nil
        print("SubscriptionManager: Attempting to restore purchases.")
        RevenueCat.Purchases.shared.restorePurchases { [weak self] customerInfo, error in
            guard let self = self else { return }
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
                self.checkSubscriptionStatus()
                return
            }
            print("SubscriptionManager: Restore successful, updating status with received CustomerInfo.")
            self.updateStatus(with: customerInfo)
            if !self.isPremium {
                self.errorMessage = "No active subscription found to restore 沒有找到可恢復的活躍訂閱"
                print("SubscriptionManager: Restore completed, but no active premium entitlement found.")
            } else {
                self.errorMessage = nil
                print("SubscriptionManager: Restore completed, active premium entitlement found.")
            }
        }
    }
}
