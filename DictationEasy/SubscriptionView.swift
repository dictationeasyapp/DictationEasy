import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionView: View {
@Environment(\.dismiss) private var dismiss
@EnvironmentObject var subscriptionManager: SubscriptionManager

@State private var showFallbackPaywall = false
@State private var selectedOffering: Offering? = nil
@State private var navigateToDetails = false

var body: some View {
NavigationStack {
ZStack {
Color(.systemGray6)
.ignoresSafeArea()

if subscriptionManager.isPremium {
VStack(spacing: 20) {
Text("Subscription Successful! 訂閱成功！")
.font(.title)
.fontWeight(.bold)
.padding(.top, 20)

Text("You are now a Premium user. 您現在是高級用戶。")
.font(.body)
.foregroundColor(.secondary)
.multilineTextAlignment(.center)
.padding(.horizontal)

Button(action: {
navigateToDetails = true
}) {
Text("View Subscription Details 查看訂閱詳情")
.font(.headline)
.foregroundColor(.white)
.frame(maxWidth: .infinity)
.padding()
.background(Color.blue)
.cornerRadius(12)
.shadow(radius: 3)
}
.padding(.horizontal)

Button(action: {
dismiss()
}) {
Text("Back to App 返回應用")
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
.onAppear {
print("SubscriptionView: Showing confirmation because isPremium is true")
}
} else if showFallbackPaywall || selectedOffering == nil {
FallbackPaywallView()
.environmentObject(subscriptionManager)
} else {
PaywallView(
offering: selectedOffering!,
displayCloseButton: true
)
.onPurchaseCompleted { customerInfo in
print("PaywallView: Purchase completed: (customerInfo.entitlements)")
subscriptionManager.updateStatus(with: customerInfo)
}
.onRestoreCompleted { customerInfo in
print("PaywallView: Restore completed: (customerInfo.entitlements)")
subscriptionManager.updateStatus(with: customerInfo)
}
.onAppear {
print("PaywallView: Fetching offerings")
RevenueCat.Purchases.shared.getOfferings { offerings, error in
if let error = error {
print("PaywallView: Error fetching offerings: (error)")
DispatchQueue.main.async {
showFallbackPaywall = true
}
return
}
if let offering = offerings?.offering(identifier: "default") {
DispatchQueue.main.async {
selectedOffering = offering
}
} else {
print("PaywallView: Default offering not found")
DispatchQueue.main.async {
showFallbackPaywall = true
}
}
}
}
}
}
.navigationBarItems(leading: Button("Cancel 取消") {
dismiss()
})
.navigationBarTitleDisplayMode(.inline)
.navigationDestination(isPresented: $navigateToDetails) {
SubscriptionDetailsView()
.environmentObject(subscriptionManager)
}
}
.onChange(of: subscriptionManager.isPremium) { newValue in
print("SubscriptionView: isPremium changed to (newValue)")
}
.onAppear {
subscriptionManager.checkSubscriptionStatus()
subscriptionManager.fetchAvailablePackages()
}
}
}

struct FallbackPaywallView: View {
@EnvironmentObject var subscriptionManager: SubscriptionManager
@Environment(\.dismiss) private var dismiss

var body: some View {
ScrollView {
VStack(spacing: 20) {
titleSection
cardContentSection
Spacer()
}
}
}

private var titleSection: some View {
Text("Go Premium 升級高級版")
.font(.title)
.fontWeight(.bold)
.padding(.top, 20)
}

private var cardContentSection: some View {
VStack(spacing: 20) {
Text("Unlock Premium Features 解鎖高級功能")
.font(.title2)
.fontWeight(.semibold)
featuresSection
subscriptionOptionsSection
restoreButtonSection
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

private var subscriptionOptionsSection: some View {
Group {
if subscriptionManager.availablePackages.isEmpty {
Text("No subscription options available. Please try again later. 目前沒有可用的訂閱選項。請稍後再試。")
.foregroundColor(.red)
.multilineTextAlignment(.center)
.padding(.horizontal)
.padding(.vertical, 10)
} else {
ForEach(subscriptionManager.availablePackages) { package in
Button(action: {
subscriptionManager.purchasePackage(package)
}) {
Text("Subscribe (package.storeProduct.localizedTitle) for (package.localizedPriceString)")
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

private var restoreButtonSection: some View {
Button(action: {
subscriptionManager.restorePurchases()
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

struct FeatureRow: View {
let text: String
var body: some View {
HStack(spacing: 10) {
Image(systemName: "checkmark.circle.fill")
.foregroundColor(.blue)
.font(.system(size: 16))
Text(text)
.lineLimit(nil)
.foregroundColor(.black)
}
}
}

#Preview {
SubscriptionView()
.environmentObject(SubscriptionManager.shared)
}
