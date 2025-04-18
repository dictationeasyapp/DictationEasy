import SwiftUI
import RevenueCat // <-- Keep top-level import
import RevenueCatUI

// --- REMOVED Mock Store Product Definition ---
// We will not define MockStoreProduct in this file anymore.

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var settings: SettingsModel // Add if needed by details view

    @State private var showFallbackPaywall = false
    @State private var selectedOffering: Offering? = nil
    @State private var navigateToDetails = false

    var body: some View {
        NavigationStack {
            // --- **** OUTER ZSTACK FOR LOADING OVERLAY **** ---
            ZStack {
                // --- Original Content Logic ---
                ZStack { // Inner ZStack for background color
                    Color(.systemGray6)
                        .ignoresSafeArea()

                    // Display content based on state
                    if subscriptionManager.isPremium {
                        premiumConfirmationView
                    } else if showFallbackPaywall || selectedOffering == nil {
                        FallbackPaywallView()
                            .environmentObject(subscriptionManager)
                    } else {
                        revenueCatPaywallView
                    }
                }
                // --- End Original Content Logic ---

                // --- **** LOADING OVERLAY (Conditionally Added) **** ---
                if subscriptionManager.isLoading {
                    loadingOverlay
                }
                // --- **** END LOADING OVERLAY **** ---
            }
            .navigationBarHidden(true) // Hide nav bar if RCUI paywall shows its own controls or for custom header
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToDetails) {
                SubscriptionDetailsView()
                    .environmentObject(subscriptionManager)
            }
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
             print("SubscriptionView: isPremium changed to \(isPremium)")
             if isPremium && (showFallbackPaywall || selectedOffering == nil) {
                 print("SubscriptionView: User became premium, dismissing paywall.")
                 dismiss()
             }
        }
        .onAppear {
            // These calls are okay, they have internal checks for Purchases.isConfigured
            subscriptionManager.checkSubscriptionStatus()
            subscriptionManager.fetchAvailablePackages()
        }
    } // End body

    // --- Extracted Subviews for Clarity ---

    private var premiumConfirmationView: some View {
        VStack(spacing: 20) {
            Text("Subscription Successful! 訂閱成功！")
                .font(.title).fontWeight(.bold).padding(.top, 20)
            Text("You are now a Premium user. 您現在是高級用戶。")
                .font(.body)
                .foregroundColor(.primary) // Corrected color
                .multilineTextAlignment(.center).padding(.horizontal)
            Button(action: { navigateToDetails = true }) {
                Text("View Subscription Details 查看訂閱詳情")
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                    .background(Color.blue).cornerRadius(12).shadow(radius: 3)
            }.padding(.horizontal)
            Button(action: { dismiss() }) {
                Text("Back to App 返回應用")
                    .font(.subheadline).foregroundColor(.blue).padding().frame(maxWidth: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
            }.padding(.horizontal).padding(.bottom, 20)
        }
        .padding().background(Color.white).cornerRadius(15).shadow(radius: 5)
        .padding(.horizontal).onAppear { print("SubscriptionView: Showing confirmation because isPremium is true") }
    }

    private var revenueCatPaywallView: some View {
        PaywallView(offering: selectedOffering!, displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                print("PaywallView: Purchase completed: \(customerInfo.entitlements)")
                subscriptionManager.updateStatus(with: customerInfo)
            }
            .onRestoreCompleted { customerInfo in
                print("PaywallView: Restore completed: \(customerInfo.entitlements)")
                subscriptionManager.updateStatus(with: customerInfo)
            }
            .onAppear { // Fetch offerings when PaywallView appears
                print("PaywallView: Fetching offerings")
                guard Purchases.isConfigured else {
                    print("PaywallView: Purchases not configured. Cannot fetch offerings.")
                    DispatchQueue.main.async { showFallbackPaywall = true }
                    return
                }
                RevenueCat.Purchases.shared.getOfferings { offerings, error in
                    if let error = error {
                        print("PaywallView: Error fetching offerings: \(error)")
                        DispatchQueue.main.async { showFallbackPaywall = true }
                        return
                    }
                    if let offering = offerings?.offering(identifier: "default") {
                        DispatchQueue.main.async { selectedOffering = offering }
                    } else {
                        print("PaywallView: Default offering not found")
                        DispatchQueue.main.async { showFallbackPaywall = true }
                    }
                }
            }
    }

    // --- Loading Overlay View ---
    private var loadingOverlay: some View {
        ZStack {
            // Semi-transparent background to dim content and block interaction
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .allowsHitTesting(true) // Ensure it blocks taps

            VStack(spacing: 15) {
                ProgressView() // Standard spinner
                    .progressViewStyle(CircularProgressViewStyle(tint: .white)) // Make spinner white
                    .scaleEffect(1.5) // Make spinner slightly larger

                Text("Processing...\n正在處理...")
                    .foregroundColor(.white)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            .background(.regularMaterial) // Use a material background for the box
            .cornerRadius(15)
            .shadow(radius: 5)
        }
        .zIndex(1) // Ensure overlay is on top
    }

} // End struct SubscriptionView


// --- FallbackPaywallView Definition (Keep as is) ---
struct FallbackPaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            // Header
            ZStack {
                 Text("Go Premium 升級高級版").font(.largeTitle).fontWeight(.bold)
                 HStack {
                     Spacer()
                     Button { dismiss() } label: {
                         Image(systemName: "xmark").foregroundColor(.gray).padding(8)
                            .background(Color.gray.opacity(0.2)).clipShape(Circle())
                     }
                 }
             }.padding()
             // Scrollable Content
            ScrollView {
                 VStack(spacing: 20) {
                    cardContentSection // Use the computed property
                    Spacer()
                 }
            }
        }.background(Color(.systemGray6).ignoresSafeArea())
    }

    // --- RESTORED Computed Properties (ensure implementations are present) ---
    var cardContentSection: some View {
        VStack(spacing: 20) {
            Text("Unlock Premium Features 解鎖高級功能")
                .font(.title2).fontWeight(.semibold).padding(.top)
            featuresSection // Use computed property
            subscriptionOptionsSection // Use computed property
            restoreButtonSection // Use computed property
            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                    .padding(.horizontal).padding(.bottom)
            }
        }
        .padding().background(Color.white).cornerRadius(15).shadow(radius: 5)
        .padding(.horizontal).padding(.bottom, 20)
    }

    var featuresSection: some View {
        VStack(spacing: 12) {
            Text("Premium Benefits 高級優勢")
                .font(.headline).fontWeight(.bold).foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
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

    var subscriptionOptionsSection: some View {
        Group {
            if subscriptionManager.isLoading && subscriptionManager.availablePackages.isEmpty {
                 ProgressView().padding(.vertical, 10)
            } else if !subscriptionManager.isLoading && subscriptionManager.availablePackages.isEmpty {
                 Text("No subscription options available. Please check your connection and try again later.\n目前沒有可用的訂閱選項。請檢查您的網絡連接並稍後再試。")
                    .font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                    .padding(.horizontal).padding(.vertical, 10)
            } else {
                ForEach(subscriptionManager.availablePackages) { package in
                    Button(action: {
                        if !subscriptionManager.isLoading { subscriptionManager.purchasePackage(package) }
                    }) {
                        Text(getButtonLabel(for: package)) // Use helper function
                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                            .padding().background(Color.blue).cornerRadius(12).shadow(radius: 3)
                    }
                    .padding(.horizontal).disabled(subscriptionManager.isLoading)
                }
            }
        }
    }

     // --- Helper function for button labels ---
     func getButtonLabel(for package: RevenueCat.Package) -> String {
        let price = package.localizedPriceString
        var durationLabel = package.storeProduct.localizedTitle
        if let period = package.storeProduct.subscriptionPeriod {
            switch period.unit {
            case .day: durationLabel = "\(period.value) day\(period.value > 1 ? "s" : "")"
            case .week: durationLabel = "\(period.value) week\(period.value > 1 ? "s" : "")"
            case .month: durationLabel = "\(period.value) month\(period.value > 1 ? "s" : "")"
            case .year: durationLabel = "\(period.value) year\(period.value > 1 ? "s" : "")"
            @unknown default: print("Unknown subscription period unit: \(period.unit)")
            }
        }
        return "Subscribe \(durationLabel) for \(price)"
    }

    var restoreButtonSection: some View {
        Button(action: {
            if !subscriptionManager.isLoading { subscriptionManager.restorePurchases() }
        }) {
            Text("Restore Purchases 恢復購買")
                .font(.subheadline).foregroundColor(.blue).padding().frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
        }
        .padding(.horizontal).padding(.bottom, 20).disabled(subscriptionManager.isLoading)
    }
    // --- END RESTORED Computed Properties ---
}


// --- FeatureRow Definition ---
struct FeatureRow: View {
    let text: String
    var body: some View { // Ensure body is implemented
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.blue).font(.system(size: 16))
            Text(text).lineLimit(nil).foregroundColor(.black).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}


// --- Preview Definition (Simplified - No Mocks) ---
#Preview {
     // Create a dummy manager for the preview, it won't have real packages
     let previewManager = SubscriptionManager.shared
     // You could manually set isLoading for previewing the loading state:
     // previewManager.isLoading = true
     // Or set isPremium for previewing the confirmation state:
     // previewManager.isPremium = true

    SubscriptionView()
        .environmentObject(previewManager) // Use the shared instance for preview
        .environmentObject(SettingsModel())
}
