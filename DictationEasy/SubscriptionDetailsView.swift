import SwiftUI
import RevenueCat

struct SubscriptionDetailsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var subscriptionStatus: String = "Loading... 正在加載..." // Initial state
    @State private var planType: String?
    @State private var renewalDate: String?
    @State private var showOpenAppStoreError: Bool = false

    // --- Use the correct Entitlement ID here as well ---
    private let premiumEntitlementID = "DictationEasy Premium"

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header (No changes needed)
                    ZStack {
                        Text("Subscription Details 訂閱詳情")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 20)

                        HStack {
                            Spacer()
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.gray)
                                    .padding()
                                    .background(Circle().fill(Color.white).shadow(radius: 2))
                            }
                            .padding(.top, 20)
                            .padding(.trailing, 20)
                        }
                    }

                    // Content Card (No structural changes needed)
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Status 狀態")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text(subscriptionStatus) // Displays the @State variable
                                .foregroundColor(.black)
                                .lineLimit(1) // Prevent wrapping if long
                                .minimumScaleFactor(0.8) // Allow shrinking
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                        if let planType = planType {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Plan Type 計劃類型")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text(planType)
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }

                        if let renewalDate = renewalDate {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Renewal Date 續訂日期")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text(renewalDate)
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }

                        // Manage Button (No changes needed)
                        Button(action: {
                           openSubscriptionManagement()
                        }) {
                            Text("Manage Subscription in App Store 在App Store中管理訂閱")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                         // Terms and Privacy Buttons (No changes needed)
                        Button(action: {
                            if let url = URL(string: "https://dictationeasyapp.github.io/dictationeasyapp/terms.html"),
                               UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Terms of Service 服務條款")
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

                        Button(action: {
                            if let url = URL(string: "https://dictationeasyapp.github.io/dictationeasyapp/"),
                               UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Privacy Policy 隱私政策")
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

                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline) // Keep title inline
        .navigationBarHidden(true) // Hide the default nav bar since we have a custom one
        // --- MODIFIED .onAppear and .onChange ---
        .onAppear {
            print("SubscriptionDetailsView: .onAppear triggered")
            // 1. Try to update state immediately with current data
            if let currentInfo = subscriptionManager.customerInfo {
                print("SubscriptionDetailsView: Found existing customerInfo on appear, updating UI.")
                updateSubscriptionDetails(with: currentInfo)
            } else {
                 print("SubscriptionDetailsView: No existing customerInfo on appear, keeping loading state.")
                 // Keep the loading state if info isn't ready yet
                 subscriptionStatus = "Loading... 正在加載..."
                 planType = nil
                 renewalDate = nil
            }
            // 2. Always trigger a refresh check
            print("SubscriptionDetailsView: Calling checkSubscriptionStatus on appear.")
            subscriptionManager.checkSubscriptionStatus()
        }
        .onChange(of: subscriptionManager.customerInfo) { newCustomerInfo in
            print("SubscriptionDetailsView: .onChange triggered for customerInfo")
            if let info = newCustomerInfo {
                updateSubscriptionDetails(with: info)
            } else {
                // Handle case where customerInfo becomes nil (e.g., error)
                print("SubscriptionDetailsView: customerInfo became nil in onChange.")
                subscriptionStatus = "Not Subscribed 未訂閱"
                planType = nil
                renewalDate = nil
            }
        }
        // --- END MODIFIED .onAppear and .onChange ---
        .alert("Unable to Open App Store 無法打開App Store", isPresented: $showOpenAppStoreError) {
            Button("OK 確定", role: .cancel) {} // No need to set showOpenAppStoreError = false here
        } message: {
            Text("Please manage your subscription directly in the App Store app.\n請直接在App Store應用中管理您的訂閱。")
        }
    }

    // Renamed function for clarity
    private func updateSubscriptionDetails(with customerInfo: CustomerInfo) {
        print("SubscriptionDetailsView: updateSubscriptionDetails called.")
        // Use the manager's isPremium flag AFTER it has been processed
        if subscriptionManager.isPremium {
            print("  isPremium is true. Setting status to Active.")
            subscriptionStatus = "Active 已激活"

            // Use the correct entitlement ID to extract details
            if let activeEntitlement = customerInfo.entitlements[premiumEntitlementID], activeEntitlement.isActive {
                print("  Found active entitlement: \(premiumEntitlementID)")
                 // Determine plan type based on product identifier
                 if activeEntitlement.productIdentifier.contains("weekly") {
                     planType = "Weekly 每週"
                 } else if activeEntitlement.productIdentifier.contains("annually") {
                     planType = "Annually 每年"
                 } else {
                     planType = activeEntitlement.productIdentifier // Fallback to identifier
                 }
                 print("    Plan Type set to: \(planType ?? "Unknown")")

                // Format expiration date
                if let expirationDate = activeEntitlement.expirationDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short // Include time for clarity
                    renewalDate = formatter.string(from: expirationDate)
                    print("    Renewal Date set to: \(renewalDate ?? "None")")
                } else {
                    renewalDate = nil // No expiration date? (Shouldn't happen for auto-renewing)
                     print("    Renewal Date: None found in entitlement.")
                }
            } else {
                 print("  Entitlement '\(premiumEntitlementID)' not found or not active in passed customerInfo.")
                 // This case should ideally not happen if isPremium is true, but handle defensively
                 planType = "Unknown 未知"
                 renewalDate = nil
            }
        } else {
            print("  isPremium is false. Setting status to Not Subscribed.")
            subscriptionStatus = "Not Subscribed 未訂閱"
            planType = nil
            renewalDate = nil
        }
    }

     // Helper function for opening subscription management
     private func openSubscriptionManagement() {
         Task { // Use Task for potential async operations like canOpenURL
             // Primary URL for direct management
             let primaryURLString = "itms-apps://apps.apple.com/account/subscriptions" // Modern URL
             guard let primaryURL = URL(string: primaryURLString) else { return }

             // Fallback URL (less reliable, general account page)
             let fallbackURLString = "https://apps.apple.com/account/subscriptions"
             guard let fallbackURL = URL(string: fallbackURLString) else { return }

             let application = UIApplication.shared

             if await application.canOpenURL(primaryURL) {
                 print("Opening primary subscription management URL: \(primaryURLString)")
                 await application.open(primaryURL)
             } else if await application.canOpenURL(fallbackURL) {
                 print("Opening fallback subscription management URL: \(fallbackURLString)")
                 await application.open(fallbackURL)
             } else {
                 print("Could not open any subscription management URL.")
                 showOpenAppStoreError = true
             }
         }
     }
}

#Preview {
    // Setup mock manager for preview
    let mockManager = SubscriptionManager.shared
    // Simulate premium state for preview if desired
    // mockManager.isPremium = true
    // mockManager.customerInfo = ... // Create mock CustomerInfo if needed

    return NavigationView { // Wrap in NavigationView for title/bar items
        SubscriptionDetailsView()
            .environmentObject(mockManager)
    }
}
