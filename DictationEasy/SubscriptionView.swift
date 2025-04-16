import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction  // Explicit type to fix inference error
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showFallbackPaywall = false
    @State private var selectedOffering: Offering? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6) // Light background
                    .ignoresSafeArea()

                // Use RevenueCat Paywall
                if showFallbackPaywall || selectedOffering == nil {
                    // Fallback custom paywall if RevenueCat Paywall fails to load
                    FallbackPaywallView()
                        .environmentObject(subscriptionManager)
                } else {
                    PaywallView(
                        offering: selectedOffering!, // Force-unwrap since we know it's non-nil
                        displayCloseButton: true
                    )
                    .onPurchaseCompleted { customerInfo in
                        print("Purchase completed: \(customerInfo.entitlements)")
                        // Update subscription state
                        Task {
                            await subscriptionManager.checkSubscriptionStatus()
                        }
                        dismiss() // Dismiss the paywall after successful purchase
                    }
                    .onRestoreCompleted { customerInfo in
                        print("Restore completed: \(customerInfo.entitlements)")
                        // Update subscription state
                        Task {
                            await subscriptionManager.checkSubscriptionStatus()
                        }
                    }
                    .onAppear {
                        // Fetch the Offering
                        Purchases.shared.getOfferings { (offerings, error) in
                            if let error = error {
                                print("Error fetching offerings: \(error)")
                                showFallbackPaywall = true
                                return
                            }
                            if let offering = offerings?.offering(identifier: "default") {
                                selectedOffering = offering
                            } else {
                                print("Default offering not found")
                                showFallbackPaywall = true
                            }
                        }
                    }
                }
            }
            .navigationBarItems(leading: Button("Cancel 取消") { dismiss() })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Fallback Paywall View (in case RevenueCat Paywall fails to load)
struct FallbackPaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss: DismissAction  // Explicit type to fix inference error

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                titleSection
                cardContentSection
                Spacer()
            }
        }
    }

    // Title Section
    private var titleSection: some View {
        Text("Go Premium 升級高級版")
            .font(.title)
            .fontWeight(.bold)
            .padding(.top, 20)
    }

    // Card Content Section (subtitle, features, subscription options, restore button)
    private var cardContentSection: some View {
        VStack(spacing: 20) {
            // Subtitle
            Text("Unlock Premium Features 解鎖高級功能")
                .font(.title2)
                .fontWeight(.semibold)

            // Features Section
            featuresSection

            // Subscription Options
            subscriptionOptionsSection

            // Restore Purchases Button
            restoreButtonSection

            // Error Message
            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    // Features Section
    private var featuresSection: some View {
        VStack(spacing: 12) {
            Text("Premium Benefits 高級優勢")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(text: "Full access to Teacher Mode 完全訪問教師模式")
                FeatureRow(text: "View and edit past dictations 查看和編輯過去文章")
                FeatureRow(text: "Use the Random button 使用隨機按鈕")
                FeatureRow(text: "Include punctuations in playback 在播放中包含標點")
                FeatureRow(text: "Ad-free experience 無廣告體驗")
            }
            .padding(.horizontal)
        }
    }

    // Subscription Options Section
    private var subscriptionOptionsSection: some View {
        Group {
            if subscriptionManager.availablePackages.isEmpty {
                Text("No subscription options available. Please try again later. 目前沒有可用的訂閱選項。請稍後再試。")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
            } else {
                ForEach(subscriptionManager.availablePackages, id: \.identifier) { package in
                    Button(action: {
                        Task {
                            await subscriptionManager.purchasePackage(package)
                        }
                    }) {
                        Text("Subscribe \(package.storeProduct.localizedTitle) for \(package.localizedPriceString)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                    }
                    .padding(.horizontal)
                    .disabled(subscriptionManager.isLoading)
                }
            }
        }
    }

    // Restore Purchases Button Section
    private var restoreButtonSection: some View {
        Button(action: {
            Task {
                await subscriptionManager.restorePurchases()
            }
        }) {
            Text("Restore Purchases 恢復購買")
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding()
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 1)
                )
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
        .disabled(subscriptionManager.isLoading)
    }
}

// Custom view for feature rows with icons
struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 16))
            Text(text)
                .lineLimit(nil) // Allow text to wrap
                .foregroundColor(.black)
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionManager.shared)
}
