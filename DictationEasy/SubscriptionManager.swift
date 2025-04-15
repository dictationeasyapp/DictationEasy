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
    @Published var customerInfo: CustomerInfo? // Add this property to store customer info

    private init() {
        // Check initial subscription status
        Task {
            await checkSubscriptionStatus()
        }
        // Fetch available subscription packages
        Task {
            await fetchAvailablePackages()
        }
        // Listen for subscription status changes
        NotificationCenter.default.addObserver(
            forName: .subscriptionStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.checkSubscriptionStatus()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await RevenueCat.Purchases.shared.customerInfo()
            self.customerInfo = customerInfo // Store the customer info
            // Check if the user has an active premium subscription using the RevenueCat entitlement identifier
            self.isPremium = customerInfo.entitlements["entlc0d28dc7a6"]?.isActive == true
        } catch {
            self.errorMessage = error.localizedDescription
            self.isPremium = false
            self.customerInfo = nil // Clear customer info on error
        }
    }

    func fetchAvailablePackages() async {
        do {
            let offerings = try await RevenueCat.Purchases.shared.offerings()
            if let packages = offerings.current?.availablePackages {
                self.availablePackages = packages
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func purchasePackage(_ package: RevenueCat.Package) async {
        isLoading = true
        errorMessage = nil
        do {
            let purchaseResult = try await RevenueCat.Purchases.shared.purchase(package: package)
            self.customerInfo = purchaseResult.customerInfo // Update customer info
            if purchaseResult.customerInfo.entitlements["entlc0d28dc7a6"]?.isActive == true {
                isPremium = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        do {
            let customerInfo = try await RevenueCat.Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo // Update customer info
            if customerInfo.entitlements["entlc0d28dc7a6"]?.isActive == true {
                isPremium = true
            } else {
                errorMessage = "No active subscription found to restore 沒有找到可恢復的活躍訂閱"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
