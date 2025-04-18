import SwiftUI
import RevenueCat

struct SubscriptionDetailsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var subscriptionStatus: String = "Loading... 正在加載..." // Initial state
    @State private var planType: String?
    @State private var renewalDate: String?
    @State private var showOpenAppStoreError: Bool = false

    private let premiumEntitlementID = "DictationEasy Premium"

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header Fix Start
                    ZStack {
                        Text("Subscription Details 訂閱詳情")
                            .font(.title).fontWeight(.bold).lineLimit(1)
                            .minimumScaleFactor(0.8).padding(.horizontal, 60)
                            .frame(maxWidth: .infinity, alignment: .center)
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.gray).padding(8)
                                    .background(Circle().fill(Color.white.opacity(0.8)).shadow(radius: 2))
                            }.padding(.trailing, 20)
                        }
                    }
                    .padding(.top, 20)
                    // Header Fix End

                    // Content Card
                    VStack(spacing: 20) {
                        // Status Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Status 狀態").font(.headline).foregroundColor(.blue)
                            Text(subscriptionStatus).foregroundColor(.black).lineLimit(1).minimumScaleFactor(0.8)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)

                        // Plan Type Section
                        if let planType = planType {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Plan Type 計劃類型").font(.headline).foregroundColor(.blue)
                                Text(planType).foregroundColor(.black)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                        }

                        // Renewal Date Section
                        if let renewalDate = renewalDate {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Renewal Date 續訂日期").font(.headline).foregroundColor(.blue)
                                Text(renewalDate).foregroundColor(.black)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                        }

                        // Manage Button
                        Button(action: { openSubscriptionManagement() }) {
                            Text("Manage Subscription in App Store 在App Store中管理訂閱")
                                .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                                .background(Color.blue).cornerRadius(12).shadow(radius: 3)
                        }.padding(.horizontal).padding(.vertical, 10)

                         // Terms Button
                        Button(action: {
                            if let url = URL(string: "https://dictationeasyapp.github.io/dictationeasyapp/terms.html"),
                               UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
                        }) {
                            Text("Terms of Service 服務條款")
                                .font(.subheadline).foregroundColor(.blue).padding().frame(maxWidth: .infinity)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
                        }.padding(.horizontal)

                        // Privacy Button
                        Button(action: {
                            if let url = URL(string: "https://dictationeasyapp.github.io/dictationeasyapp/"),
                               UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
                        }) {
                            Text("Privacy Policy 隱私政策")
                                .font(.subheadline).foregroundColor(.blue).padding().frame(maxWidth: .infinity)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
                        }.padding(.horizontal).padding(.bottom, 20)

                    }
                    .padding().background(Color.white).cornerRadius(15).shadow(radius: 5)
                    .padding(.horizontal).padding(.bottom, 20)

                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .onAppear { /* ... Keep implementation ... */ }
        .onChange(of: subscriptionManager.customerInfo) { newCustomerInfo in /* ... Keep implementation ... */ }
        .alert("Unable to Open App Store 無法打開App Store", isPresented: $showOpenAppStoreError) {
            Button("OK 確定", role: .cancel) {}
        } message: {
            Text("Please manage your subscription directly in the App Store app.\n請直接在App Store應用中管理您的訂閱。")
        }
        // Keep the onAppear and onChange blocks as they were
        .onAppear {
            print("SubscriptionDetailsView: .onAppear triggered")
            if let currentInfo = subscriptionManager.customerInfo {
                print("SubscriptionDetailsView: Found existing customerInfo on appear, updating UI.")
                updateSubscriptionDetails(with: currentInfo)
            } else {
                 print("SubscriptionDetailsView: No existing customerInfo on appear, keeping loading state.")
                 subscriptionStatus = "Loading... 正在加載..."
                 planType = nil
                 renewalDate = nil
            }
            print("SubscriptionDetailsView: Calling checkSubscriptionStatus on appear.")
            subscriptionManager.checkSubscriptionStatus()
        }
        .onChange(of: subscriptionManager.customerInfo) { newCustomerInfo in
            print("SubscriptionDetailsView: .onChange triggered for customerInfo")
            if let info = newCustomerInfo {
                updateSubscriptionDetails(with: info)
            } else {
                print("SubscriptionDetailsView: customerInfo became nil in onChange.")
                subscriptionStatus = "Not Subscribed 未訂閱"
                planType = nil
                renewalDate = nil
            }
        }
    } // End body

    // --- Keep updateSubscriptionDetails function ---
    private func updateSubscriptionDetails(with customerInfo: CustomerInfo) {
        print("SubscriptionDetailsView: updateSubscriptionDetails called.")
        if subscriptionManager.isPremium {
            print("  isPremium is true. Setting status to Active.")
            subscriptionStatus = "Active 已激活"
            if let activeEntitlement = customerInfo.entitlements[premiumEntitlementID], activeEntitlement.isActive {
                print("  Found active entitlement: \(premiumEntitlementID)")
                 if activeEntitlement.productIdentifier.contains("weekly") { planType = "Weekly 每週" }
                 else if activeEntitlement.productIdentifier.contains("annually") { planType = "Annually 每年" }
                 else { planType = activeEntitlement.productIdentifier }
                 print("    Plan Type set to: \(planType ?? "Unknown")")

                if let expirationDate = activeEntitlement.expirationDate {
                    let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
                    renewalDate = formatter.string(from: expirationDate)
                    print("    Renewal Date set to: \(renewalDate ?? "None")")
                } else {
                    renewalDate = nil
                    print("    Renewal Date: None found in entitlement.")
                }
            } else {
                 print("  Entitlement '\(premiumEntitlementID)' not found or not active in passed customerInfo.")
                 planType = "Unknown 未知"; renewalDate = nil
            }
        } else {
            print("  isPremium is false. Setting status to Not Subscribed.")
            subscriptionStatus = "Not Subscribed 未訂閱"; planType = nil; renewalDate = nil
        }
    }


    // --- **** KEEP ONLY ONE INSTANCE of openSubscriptionManagement **** ---
     private func openSubscriptionManagement() {
         Task {
             let primaryURLString = "itms-apps://apps.apple.com/account/subscriptions"
             guard let primaryURL = URL(string: primaryURLString) else { return }
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
     // --- **** END of the single openSubscriptionManagement function **** ---

} // End struct SubscriptionDetailsView


#Preview {
    let mockManager = SubscriptionManager.shared
    // Simulate premium state for preview if desired
    // mockManager.isPremium = true

    return NavigationView { // Wrap in NavigationView for the destination to work
        SubscriptionDetailsView()
            .environmentObject(mockManager)
            .environmentObject(SettingsModel()) // Add other necessary environment objects
    }
}
