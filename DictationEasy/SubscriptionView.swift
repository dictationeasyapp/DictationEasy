import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var settings: SettingsModel

    // State for RCUI Paywall Offering
    @State private var selectedOffering: Offering? = nil
    // State to track loading of the RCUI offering specifically
    @State private var isLoadingOffering: Bool = true
    // State for navigation to details view
    @State private var navigateToDetails = false

    var body: some View {
        NavigationStack {
            ZStack { // Outer ZStack for the purchase/restore loading overlay
                // Main Content Area
                ZStack {
                    Color(.systemGray6)
                        .ignoresSafeArea()

                    // --- Main Content Logic ---
                    if subscriptionManager.isPremium {
                        premiumConfirmationView // Show if user is already premium
                    } else {
                        // If not premium, decide which paywall or loading state to show
                        if isLoadingOffering {
                            offeringLoadingView // Show loading indicator while fetching offering
                        } else if let offering = selectedOffering {
                            revenueCatPaywallView(offering: offering) // Show RCUI Paywall if offering loaded
                        } else {
                            FallbackPaywallView() // Show Fallback if offering failed to load
                                .environmentObject(subscriptionManager)
                        }
                    }
                    // --- End Main Content Logic ---
                }

                // --- Loading Overlay for Purchase/Restore (Uses subscriptionManager.isLoading) ---
                if subscriptionManager.isLoading {
                    purchaseLoadingOverlay // Keep the existing overlay for purchase/restore actions
                }
                // --- End Loading Overlay ---
            }
            .navigationBarHidden(true) // Hide default nav bar
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToDetails) {
                SubscriptionDetailsView()
                    .environmentObject(subscriptionManager)
            }
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
            print("SubscriptionView: isPremium changed to \(isPremium)")
            // Dismiss if user becomes premium while any non-premium view is shown
            if isPremium {
                print("SubscriptionView: User became premium, dismissing paywall.")
                dismiss()
            }
        }
        .onAppear {
            // Fetch general status and packages for fallback view on appear
            subscriptionManager.checkSubscriptionStatus()
            subscriptionManager.fetchAvailablePackages()
            // Attempt to fetch the specific offering for RCUI Paywall
            fetchOfferingForPaywall()
        }
    } // End body

    // MARK: - Subviews

    private var premiumConfirmationView: some View {
        VStack(spacing: 20) {
            Text("Subscription Successful! 訂閱成功！")
                .font(.title).fontWeight(.bold).padding(.top, 20)
            Text("You are now a Premium user. 您現在是高級用戶。")
                .font(.body).foregroundColor(.primary)
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

    // View shown while loading the offering for RCUI Paywall
    private var offeringLoadingView: some View {
        VStack {
            ProgressView("Loading Plans...\n正在加載計劃...")
                .progressViewStyle(CircularProgressViewStyle())
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
    }

    // RCUI Paywall View
    private func revenueCatPaywallView(offering: Offering) -> some View {
        PaywallView(offering: offering, displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                print("PaywallView: Purchase completed: \(customerInfo.entitlements)")
                subscriptionManager.updateStatus(with: customerInfo)
                // dismiss() // Dismiss automatically handled by isPremium change
            }
            .onRestoreCompleted { customerInfo in
                print("PaywallView: Restore completed: \(customerInfo.entitlements)")
                subscriptionManager.updateStatus(with: customerInfo)
                // dismiss() // Dismiss automatically handled by isPremium change
            }
    }

    // Loading overlay specifically for purchase/restore actions
    private var purchaseLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(true)
            VStack(spacing: 15) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.5)
                Text("Processing...\n正在處理...").foregroundColor(.white).font(.headline).multilineTextAlignment(.center)
            }
            .padding(30).background(.regularMaterial).cornerRadius(15).shadow(radius: 5)
        }
        .zIndex(1) // Ensure it's on top
    }

    // MARK: - Helper Methods

    private func fetchOfferingForPaywall() {
        print("SubscriptionView: fetchOfferingForPaywall called.")
        isLoadingOffering = true // Start loading offering state
        selectedOffering = nil // Reset offering

        guard Purchases.isConfigured else {
            print("SubscriptionView: Purchases not configured. Cannot fetch offerings.")
            subscriptionManager.errorMessage = "Initialization error. Please restart the app.\n初始化錯誤，請重新啟動應用。"
            isLoadingOffering = false
            return
        }

        RevenueCat.Purchases.shared.getOfferings { offerings, error in
            DispatchQueue.main.async { // Ensure UI updates are on main thread
                if let error = error {
                    print("SubscriptionView: Error fetching offerings: \(error)")
                    self.subscriptionManager.errorMessage = "Failed to load subscription plans. Please try again later.\n無法加載訂閱計劃，請稍後重試。"
                    self.selectedOffering = nil
                    self.isLoadingOffering = false
                    return
                }
                if let offering = offerings?.offering(identifier: "default") {
                    print("SubscriptionView: Default offering fetched successfully.")
                    self.selectedOffering = offering
                    self.isLoadingOffering = false
                    self.subscriptionManager.errorMessage = nil // Clear any previous error
                } else {
                    print("SubscriptionView: Default offering not found.")
                    self.subscriptionManager.errorMessage = "No subscription plans available. Please try again later.\n無可用訂閱計劃，請稍後重試。"
                    self.selectedOffering = nil
                    self.isLoadingOffering = false
                }
            }
        }
    }
}

// --- FallbackPaywallView Definition ---
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
                    cardContentSection
                    Spacer()
                }
            }
        }.background(Color(.systemGray6).ignoresSafeArea())
    }

    var cardContentSection: some View {
        VStack(spacing: 20) {
            Text("Unlock Premium Features 解鎖高級功能")
                .font(.title2).fontWeight(.semibold).padding(.top)
            featuresSection
            subscriptionOptionsSection
            restoreButtonSection
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
                        Text(getButtonLabel(for: package))
                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                            .padding().background(Color.blue).cornerRadius(12).shadow(radius: 3)
                    }
                    .padding(.horizontal).disabled(subscriptionManager.isLoading)
                }
            }
        }
    }

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
}

// --- FeatureRow Definition ---
struct FeatureRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.blue).font(.system(size: 16))
            Text(text).lineLimit(nil).foregroundColor(.black).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// --- Preview Definition ---
#Preview {
    let previewManager = SubscriptionManager.shared
    let settings = SettingsModel()
    // Uncomment to test different states:
    // previewManager.isPremium = true // Test premium confirmation view
    // previewManager.isLoading = true // Test purchase loading overlay
    // _isLoadingOffering = State(initialValue: true) // Test offering loading view
    // _selectedOffering = State(initialValue: Offering(identifier: "default", serverDescription: "Mock Offering", availablePackages: [])) // Test RevenueCat paywall

    return SubscriptionView()
        .environmentObject(previewManager)
        .environmentObject(settings)
}
