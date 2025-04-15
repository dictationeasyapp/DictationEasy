import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var feedbackText: String
    let onSendFeedback: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 200)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding()
                
                Button(action: onSendFeedback) {
                    Label("Send Feedback 發送反饋", systemImage: "paperplane")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .navigationTitle("Feedback 反饋")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel 取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsTabView: View {
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showDeleteConfirmation = false
    @State private var showSettingsError = false
    @State private var showFeedbackSheet = false
    @State private var showEmailError = false
    @State private var feedbackText = ""
    @State private var showSubscriptionDetails = false
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "App Version: \(version) (\(build)) 應用版本：\(version) (\(build))"
    }
    
    private func sendFeedback() {
        let emailAddress = "dictationeasyapp@gmail.com"
        let subject = "DictationEasy Feedback"
        let body = feedbackText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "mailto:\(emailAddress)?subject=\(subject)&body=\(body)"
        
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else {
            showEmailError = true
            return
        }
        
        UIApplication.shared.open(url) { success in
            if success {
                feedbackText = ""
                showFeedbackSheet = false
            } else {
                showEmailError = true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete All Past Dictations 刪除所有過去文章", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(settings.pastDictations.isEmpty ? Color.gray : Color.red)
                            .cornerRadius(10)
                    }
                    .disabled(settings.pastDictations.isEmpty)
                    .accessibilityLabel("Delete All Past Dictations Button 刪除所有過去文章按鈕")
                } header: {
                    Text("Data Management 數據管理")
                }
                
                Section {
                    Button(action: {
                        showFeedbackSheet = true
                    }) {
                        Label("Feedback 功能改善反映", systemImage: "envelope")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Send Feedback Button 發送反饋按鈕")
                } header: {
                    Text("Feedback 反饋")
                }
                
                Section {
                    Button(action: {
                        showSubscriptionDetails = true
                    }) {
                        Label("Manage Subscription 管理訂閱", systemImage: "creditcard")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Manage Subscription Button 管理訂閱按鈕")
                } header: {
                    Text("Account 帳戶")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Font Size 字體大小: \(Int(settings.fontSize))pt")
                        
                        Slider(
                            value: $settings.fontSize,
                            in: 12...28,
                            step: 1
                        )
                        .accessibilityLabel("Font Size Slider 字體大小滑塊")
                    }
                } header: {
                    Text("Font Size 字體大小")
                }
                
                Section {
                    // New: FAQ Button
                    NavigationLink {
                        FAQView()
                    } label: {
                        Label("FAQ 常見問題", systemImage: "questionmark.circle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("FAQ Button 常見問題按鈕")
                    
                    Text(appVersion)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("App Version 應用版本")
                } header: {
                    Text("About 關於")
                }
            }
            .padding(.horizontal)
            .navigationTitle("Settings 設置")
            .alert("Delete All Past Dictations 刪除所有過去文章", isPresented: $showDeleteConfirmation) {
                Button("Delete 刪除", role: .destructive) {
                    settings.deleteAllPastDictations()
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete all past dictations? This action cannot be undone. 您確定要刪除所有過去文章嗎？此操作無法撤銷。")
            }
            .alert("Settings Error 設置錯誤", isPresented: $showSettingsError) {
                Button("OK 確定", role: .cancel) {
                    settings.error = nil
                }
            } message: {
                Text(settings.error ?? "Unknown error 未知錯誤")
            }
            .alert("Email Error 電子郵件錯誤", isPresented: $showEmailError) {
                Button("OK 確定", role: .cancel) {
                    showEmailError = false
                }
            } message: {
                Text("Unable to send email. Please set up an email account in the Mail app. 無法發送電子郵件。請在郵件應用中設置電子郵件帳戶。")
            }
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackSheet(
                    feedbackText: $feedbackText,
                    onSendFeedback: sendFeedback
                )
            }
            .sheet(isPresented: $showSubscriptionDetails) {
                SubscriptionDetailsView()
                    .environmentObject(subscriptionManager)
            }
            .onChange(of: settings.error) { newError in
                if newError != nil {
                    showSettingsError = true
                }
            }
        }
    }
}

#Preview {
    SettingsTabView()
        .environmentObject(SettingsModel())
        .environmentObject(SubscriptionManager.shared)
}
