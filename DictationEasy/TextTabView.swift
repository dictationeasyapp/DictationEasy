import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Vision // Import Vision for OCR (if not already handled in OCRManager)

struct TextTabView: View {
    @Binding var selectedTab: TabSelection
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var ocrManager: OCRManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    let isEditingPastDictation: Bool
    
    @State private var showSettingsError = false // New state for file system errors
    @State private var isLoading: Bool = false // New state for loading indicator
    @State private var ocrError: String? // New state for OCR errors
    
    // Determine if the user is on the free tier (shows ads)
    var isFreeUser: Bool {
        return !subscriptionManager.isPremium
    }
    
    init(selectedTab: Binding<TabSelection>, isEditingPastDictation: Bool = false) {
        self._selectedTab = selectedTab
        self.isEditingPastDictation = isEditingPastDictation
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Show loading indicator or text editor based on isLoading state
                if isLoading {
                    ProgressView("Extracting text... 正在提取文字...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: $settings.extractedText)
                        .font(.system(size: settings.fontSize))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .placeholder(when: settings.extractedText.isEmpty) {
                            Text("Extracted text will appear here 提取的文字將顯示在此處")
                                .foregroundColor(.gray) // Fixed syntax error: '..gray' to '.gray'
                                .padding()
                        }
                }
                
                HStack(spacing: 20) {
                    #if canImport(UIKit)
                    Button(action: {
                        UIPasteboard.general.string = settings.extractedText
                    }) {
                        Label("Copy 複製", systemImage: "doc.on.doc")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    #else
                    Button(action: {
                        // Fallback for non-UIKit platforms (e.g., macOS)
                    }) {
                        Label("Copy 複製", systemImage: "doc.on.doc")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(true)
                    #endif

                    Button(action: {
                        settings.extractedText = ""
                        ocrManager.extractedText = ""
                    }) {
                        Label("Clear 清除", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Button(action: {
                    if !settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        settings.savePastDictation(text: settings.extractedText)
                    }
                    settings.playbackMode = .sentenceBySentence
                    selectedTab = .speech
                }) {
                    Label("Confirm 確認", systemImage: "checkmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                // Add the banner ad here, conditionally shown for free users
                if isFreeUser {
                    BannerAdView()
                        .frame(height: 50) // GADAdSizeBanner is 320x50
                }
            }
            .navigationTitle("Text 文字")
            .alert("Settings Error 設置錯誤", isPresented: $showSettingsError) {
                Button("OK 確定", role: .cancel) {
                    settings.error = nil // Clear the error after dismissal
                }
            } message: {
                Text(settings.error ?? "Unknown error 未知錯誤")
            }
            .alert("OCR Error 文字識別錯誤", isPresented: Binding(
                get: { ocrError != nil },
                set: { if !$0 { ocrError = nil } }
            )) {
                Button("OK 確定", role: .cancel) {}
            } message: {
                Text(ocrError ?? "Unknown error 未知錯誤")
            }
            .onChange(of: settings.error) { newError in
                if newError != nil {
                    showSettingsError = true
                }
            }
            .onChange(of: ocrManager.error) { newError in
                if let error = newError {
                    DispatchQueue.main.async {
                        ocrError = error
                    }
                }
            }
            .onAppear {
                // If editing past dictation, don't overwrite the text
                if isEditingPastDictation {
                    if settings.editingDictationId == nil {
                        settings.extractedText = ocrManager.extractedText
                    }
                } else {
                    // If not editing, always sync with OCRManager
                    if ocrManager.isProcessing {
                        // OCR is still processing, show loading indicator
                        isLoading = true
                    } else if !ocrManager.extractedText.isEmpty {
                        // OCR has completed, update the text immediately
                        settings.extractedText = ocrManager.extractedText
                        isLoading = false
                    } else {
                        // No text available yet, ensure the text is cleared
                        settings.extractedText = ""
                        isLoading = false
                    }
                    settings.editingDictationId = nil
                }
                
                #if DEBUG
                print("TextTabView.onAppear - editingDictationId: \(String(describing: settings.editingDictationId))")
                print("TextTabView.onAppear - isEditingPastDictation: \(isEditingPastDictation)")
                print("TextTabView.onAppear - isLoading: \(isLoading)")
                #endif
            }
            .onChange(of: ocrManager.extractedText) { newText in
                // When OCRManager updates its extractedText, sync it with settings and update UI
                DispatchQueue.main.async {
                    settings.extractedText = newText
                    isLoading = false
                }
            }
            .onChange(of: ocrManager.isProcessing) { isProcessing in
                // Update loading state based on OCRManager's processing status
                DispatchQueue.main.async {
                    isLoading = isProcessing
                }
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            if shouldShow { placeholder() }
            self
        }
    }
}

#Preview {
    TextTabView(selectedTab: .constant(.text), isEditingPastDictation: false)
        .environmentObject(SettingsModel())
        .environmentObject(OCRManager())
        .environmentObject(SubscriptionManager.shared)
}
