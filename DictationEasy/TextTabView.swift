import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Vision

struct TextTabView: View {
    @Binding var selectedTab: TabSelection
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var ocrManager: OCRManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    let isEditingPastDictation: Bool

    @State private var showSettingsError = false
    @State private var isLoading: Bool = false
    @State private var ocrError: String?
    @FocusState private var isTextEditorFocused: Bool

    var isFreeUser: Bool {
        return !subscriptionManager.isPremium
    }

    init(selectedTab: Binding<TabSelection>, isEditingPastDictation: Bool = false) {
        self._selectedTab = selectedTab
        self.isEditingPastDictation = isEditingPastDictation
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Extracting text... 正在提取文字...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: $settings.extractedText)
                        .font(.system(size: settings.fontSize))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8) // Internal padding
                        .background(Color(.systemGray6)) // Background for the text area
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top)
                        .focused($isTextEditorFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done 完成") {
                                    isTextEditorFocused = false
                                }
                            }
                        }
                        // Apply the placeholder modifier
                        .placeholder(when: settings.extractedText.isEmpty) {
                            // Placeholder View Builder
                            Text("Extracted text will appear here\n提取的文字將顯示在此處")
                                .font(.system(size: settings.fontSize))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12) // Align with TextEditor padding + internal padding
                                .padding(.vertical, 16) // Align with TextEditor padding + internal padding
                                .allowsHitTesting(false) // Let taps pass through to TextEditor
                        }
                        .onChange(of: settings.extractedText) { newText in
                             // Keep OCR Manager synced if user edits manually
                            if !ocrManager.hasNewOCRResult {
                                ocrManager.updateExtractedText(newText)
                            }
                        }


                    // Reminder Text (No changes needed here)
                    Text("For the best experience, please split your text into sentences before confirming.\n為獲得最佳體驗，請在確認前將文字分成句子。")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                } // End else

                // Buttons and Ad Section (No changes needed here)
                VStack(spacing: 10) {
                    HStack(spacing: 20) {
                        #if canImport(UIKit)
                        Button(action: {
                            UIPasteboard.general.string = settings.extractedText
                            isTextEditorFocused = false
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
                        Button(action: {}) { Label("Copy 複製", systemImage: "doc.on.doc").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.gray).cornerRadius(10) }.disabled(true)
                        #endif
                        Button(action: {
                            settings.extractedText = ""
                            ocrManager.updateExtractedText("")
                            isTextEditorFocused = false
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
                    .padding(.top, 10)

                    Button(action: {
                        isTextEditorFocused = false
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
                            .background(settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if isFreeUser {
                        Spacer().frame(height: 10)
                        BannerAdContainer()
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                    } else {
                         Spacer().frame(height: 10)
                    }

                }
                .padding(.bottom)
                .background(Color(.systemBackground))

            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Text 文字")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Settings Error 設置錯誤", isPresented: $showSettingsError) {
                Button("OK 確定", role: .cancel) { settings.error = nil }
            } message: { Text(settings.error ?? "Unknown error 未知錯誤") }
            .alert("OCR Error 文字識別錯誤", isPresented: Binding(
                get: { ocrError != nil },
                set: { if !$0 { ocrError = nil } }
            )) {
                Button("OK 確定", role: .cancel) {}
            } message: { Text(ocrError ?? "Unknown error 未知錯誤") }
            .onChange(of: settings.error) { newError in showSettingsError = (newError != nil) }
            .onChange(of: ocrManager.error) { newError in ocrError = newError }
            .onChange(of: ocrManager.isProcessing) { isProcessing in isLoading = isProcessing }
            .onChange(of: selectedTab) { newTab in
                if newTab != .text {
                    isTextEditorFocused = false
                } else {
                    isTextEditorFocused = true // Focus when switching to tab
                }
            }
            .onChange(of: ocrManager.extractedText) { newText in
                 if ocrManager.hasNewOCRResult {
                     settings.extractedText = newText
                     ocrManager.hasNewOCRResult = false
                     #if DEBUG
                     print("TextTabView.onChange(ocrManager.extractedText) - Updated settings from NEW OCR.")
                     #endif
                      isTextEditorFocused = true // Focus after OCR
                 }
            }
            .onAppear {
                 #if DEBUG
                 print("TextTabView.onAppear: Editing=\(isEditingPastDictation), HasNewOCR=\(ocrManager.hasNewOCRResult), Processing=\(ocrManager.isProcessing)")
                 #endif
                 isLoading = ocrManager.isProcessing
                 if !isLoading && !isEditingPastDictation && !ocrManager.hasNewOCRResult {
                     ocrManager.updateExtractedText(settings.extractedText)
                 }
                 isTextEditorFocused = true // Focus on appear
            }

        }
        .navigationViewStyle(.stack)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}


// --- UPDATED Placeholder View Extension ---
extension View {
    // Apply this modifier to a TextEditor
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .topLeading, // Default alignment
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            // Place the TextEditor (self) first
            self

            // Place the placeholder on top
            // Control its visibility using opacity
            placeholder()
                .opacity(shouldShow ? 1 : 0) // Fade in/out
                .animation(.easeInOut(duration: 0.15), value: shouldShow) // Add subtle animation
        }
    }
}
// --- END UPDATED Placeholder View Extension ---


#Preview {
    let settings = SettingsModel()
    let ocr = OCRManager()
    let sub = SubscriptionManager.shared
    // settings.extractedText = "" // Ensure empty for previewing placeholder

    return TextTabView(selectedTab: .constant(.text), isEditingPastDictation: false)
        .environmentObject(settings)
        .environmentObject(ocr)
        .environmentObject(sub)
}
