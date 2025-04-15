import SwiftUI
import RevenueCat

struct SubscriptionDetailsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var subscriptionStatus: String = "Loading... 正在加載..."
    @State private var planType: String?
    @State private var renewalDate: String?
    @State private var showOpenAppStoreError: Bool = false
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Title with Close Button
                    ZStack {
                        Text("Subscription Details 訂閱詳情")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        // Close Button in the top-right corner
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
                    
                    // Card-like container
                    VStack(spacing: 20) {
                        // Subscription Status
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Status 狀態")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text(subscriptionStatus)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // Plan Type (if subscribed)
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
                        
                        // Renewal Date (if subscribed)
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
                        
                        // Manage Subscription Button
                        Button(action: {
                            let primaryURLString = "itms-services://?action=manageSubscriptions"
                            if let primaryURL = URL(string: primaryURLString),
                               UIApplication.shared.canOpenURL(primaryURL) {
                                UIApplication.shared.open(primaryURL)
                            } else {
                                let fallbackURLString = "https://apps.apple.com/account/subscriptions"
                                if let fallbackURL = URL(string: fallbackURLString),
                                   UIApplication.shared.canOpenURL(fallbackURL) {
                                    UIApplication.shared.open(fallbackURL)
                                } else {
                                    showOpenAppStoreError = true
                                }
                            }
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
                        
                        // Terms of Service Button
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
                        
                        // Privacy Policy Button
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await subscriptionManager.checkSubscriptionStatus()
            }
        }
        .onChange(of: subscriptionManager.customerInfo) { newCustomerInfo in
            if let customerInfo = newCustomerInfo {
                updateSubscriptionDetails(with: customerInfo)
            } else {
                subscriptionStatus = "Not Subscribed 未訂閱"
                planType = nil
                renewalDate = nil
            }
        }
        .alert("Unable to Open App Store 無法打開App Store", isPresented: $showOpenAppStoreError) {
            Button("OK 確定", role: .cancel) {
                showOpenAppStoreError = false
            }
        } message: {
            Text("Please manage your subscription directly in the App Store app. 請直接在App Store應用中管理您的訂閱。")
        }
    }
    
    private func updateSubscriptionDetails(with customerInfo: CustomerInfo) {
        if subscriptionManager.isPremium {
            subscriptionStatus = "Active 已激活"
            
            // Get the plan type (e.g., Weekly or Annually)
            if let activeEntitlement = customerInfo.entitlements["entlc0d28dc7a6"],
               activeEntitlement.isActive {
                if activeEntitlement.productIdentifier.contains("weekly") {
                    planType = "Weekly 每週"
                } else if activeEntitlement.productIdentifier.contains("annually") {
                    planType = "Annually 每年"
                }
            }
            
            // Get the renewal/expiration date
            if let expirationDate = customerInfo.entitlements["entlc0d28dc7a6"]?.expirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                renewalDate = formatter.string(from: expirationDate)
            }
        } else {
            subscriptionStatus = "Not Subscribed 未訂閱"
            planType = nil
            renewalDate = nil
        }
    }
}

#Preview {
    SubscriptionDetailsView()
        .environmentObject(SubscriptionManager.shared)
}
