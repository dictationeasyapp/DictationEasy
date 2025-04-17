import Foundation
import RevenueCat
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var availablePackages: [RevenueCat.Package] = []
    @Published var customerInfo: CustomerInfo?

    private init() {
        // Check initial subscription status and fetch packages
        checkSubscriptionStatus()
        fetchAvailablePackages()
    }

    // Function to check status using getCustomerInfo (useful for initial load or manual refresh)
    func checkSubscriptionStatus() {
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
                print("SubscriptionManager: Error - customerInfo is nil")
                return
            }
            self.processUpdatedCustomerInfo(customerInfo)
            print("SubscriptionManager: checkSubscriptionStatus completed.")
        }
    }

    // New function to update status directly from provided CustomerInfo (e.g., from purchase callback)
    func updateStatus(with customerInfo: CustomerInfo) {
        print("SubscriptionManager: Updating status directly with provided CustomerInfo.")
        self.processUpdatedCustomerInfo(customerInfo)
    }

    // Centralized logic to process CustomerInfo and update published properties
    private func processUpdatedCustomerInfo(_ customerInfo: CustomerInfo) {
        let isActive = customerInfo.entitlements["DictationEasy Premium"]?.isActive == true
        self.customerInfo = customerInfo
        self.isPremium = isActive
        print("SubscriptionManager: Processed CustomerInfo - Updated isPremium to \(isActive), entitlement: \(String(describing: customerInfo.entitlements["DictationEasy Premium"]))")
    }

    func fetchAvailablePackages() {
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
            } else {
                print("SubscriptionManager: No available packages found")
            }
        }
    }

    func purchasePackage(_ package: RevenueCat.Package) {
        self.isLoading = true
        self.errorMessage = nil
        RevenueCat.Purchases.shared.purchase(package: package) { [weak self] transaction, customerInfo, error, userCancelled in
            guard let self = self else { return }
            self.isLoading = false
            if userCancelled {
                print("SubscriptionManager: Purchase cancelled by user")
                return
            }
            if let error = error {
                self.errorMessage = error.localizedDescription
                print("SubscriptionManager: Purchase error: \(error)")
                return
            }
            guard let customerInfo = customerInfo else {
                self.errorMessage = "Failed to retrieve customer info after purchase"
                print("SubscriptionManager: Error - customerInfo is nil after purchase")
                self.checkSubscriptionStatus() // Fallback to fetching if nil
                return
            }
            print("SubscriptionManager: Purchase successful, updating status with received CustomerInfo.")
            self.updateStatus(with: customerInfo)
        }
    }

    func restorePurchases() {
        self.isLoading = true
        self.errorMessage = nil
        RevenueCat.Purchases.shared.restorePurchases { [weak self] customerInfo, error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                self.errorMessage = error.localizedDescription
                print("SubscriptionManager: Restore error: \(error)")
                return
            }
            guard let customerInfo = customerInfo else {
                self.errorMessage = "Failed to retrieve customer info after restore"
                print("SubscriptionManager: Error - customerInfo is nil after restore")
                self.checkSubscriptionStatus() // Fallback to fetching if nil
                return
            }
            print("SubscriptionManager: Restore successful, updating status with received CustomerInfo.")
            self.updateStatus(with: customerInfo)
            if !self.isPremium {
                self.errorMessage = "No active subscription found to restore 沒有找到可恢復的活躍訂閱"
                print("SubscriptionManager: Restore completed, but no active premium entitlement found.")
            }
        }
    }
}
