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
        // Use NavigationView to provide a title bar
        NavigationView {
            // Main container VStack
            VStack(spacing: 0) { // Use 0 spacing and manage padding manually
                if isLoading {
                    ProgressView("Extracting text... 正在提取文字...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Center the progress view
                } else {
                    // Text Editor section
                    TextEditor(text: $settings.extractedText)
                        .font(.system(size: settings.fontSize))
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow editor to expand
                        .padding(8) // Internal padding for text
                        .background(Color(.systemGray6)) // Background for the text area
                        .cornerRadius(10)
                        .padding(.horizontal) // Padding left/right of the editor
                        .padding(.top) // Padding above the editor
                        .focused($isTextEditorFocused) // Manage focus state
                        .toolbar { // Keyboard toolbar
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer() // Push button to the right
                                Button("Done 完成") {
                                    isTextEditorFocused = false // Dismiss keyboard action
                                }
                            }
                        }
                        // --- MODIFIED PLACEHOLDER ---
                        .placeholder(when: settings.extractedText.isEmpty) {
                            Text("Extracted text will appear here\n提取的文字將顯示在此處")
                                .font(.system(size: settings.fontSize))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12) // Match TextEditor internal horizontal padding
                                .padding(.vertical, 16) // Match TextEditor internal vertical padding
                                .allowsHitTesting(false)
                                // Explicitly control opacity based on the condition
                                .opacity(settings.extractedText.isEmpty ? 1 : 0)
                        }
                        // --- END MODIFIED PLACEHOLDER ---
                        .onChange(of: settings.extractedText) { newText in
                            // Keep OCR Manager synced if user edits manually
                            if !ocrManager.hasNewOCRResult { // Avoid loop if change came from OCR
                                ocrManager.updateExtractedText(newText)
                            }
                        }

                    // Reminder Text
                    Text("For the best experience, please split your text into sentences before confirming.\n為獲得最佳體驗，請在確認前將文字分成句子。")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 8) // Space between editor and buttons

                } // End else (not isLoading)

                // Buttons and Ad Section (at the bottom)
                VStack(spacing: 10) {
                    HStack(spacing: 20) {
                        // Copy Button
                        #if canImport(UIKit)
                        Button(action: {
                            UIPasteboard.general.string = settings.extractedText
                            isTextEditorFocused = false // Dismiss keyboard on action
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
                        // Fallback for non-UIKit
                        Button(action: {}) { Label("Copy 複製", systemImage: "doc.on.doc").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.gray).cornerRadius(10) }.disabled(true)
                        #endif

                        // Clear Button
                        Button(action: {
                            settings.extractedText = ""
                            ocrManager.updateExtractedText("") // Keep OCR manager synced
                            isTextEditorFocused = false // Dismiss keyboard
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
                    .padding(.top, 10) // Space above button row

                    // Confirm Button
                    Button(action: {
                        isTextEditorFocused = false // Dismiss keyboard first
                        if !settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            settings.savePastDictation(text: settings.extractedText)
                            // No need to update ocrManager text here, already done by .onChange
                        }
                        settings.playbackMode = .sentenceBySentence // Default mode for speech tab
                        selectedTab = .speech // Navigate to speech tab
                    }) {
                        Label("Confirm 確認", systemImage: "checkmark")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue) // Use gray when disabled
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) // Disable if no text

                    // Banner Ad Container
                     if isFreeUser {
                         // Add spacer ONLY if ad is shown to push buttons up slightly
                         Spacer().frame(height: 10)
                         BannerAdContainer()
                             .frame(height: 50)
                             .frame(maxWidth: .infinity)
                     } else {
                          Spacer().frame(height: 10) // Consistent small spacing even for premium users
                     }

                } // End Button VStack
                .padding(.bottom) // Add padding below buttons/ad
                .background(Color(.systemBackground)) // Background for button area

            } // End Main VStack
            .background(Color(.systemGroupedBackground)) // Background for the whole view under the nav bar
            .navigationTitle("Text 文字")
            .navigationBarTitleDisplayMode(.inline) // Keep title smaller
            .alert("Settings Error 設置錯誤", isPresented: $showSettingsError) {
                Button("OK 確定", role: .cancel) { settings.error = nil }
            } message: { Text(settings.error ?? "Unknown error 未知錯誤") }
            .alert("OCR Error 文字識別錯誤", isPresented: Binding(
                get: { ocrError != nil },
                set: { if !$0 { ocrError = nil } }
            )) {
                Button("OK 確定", role: .cancel) {}
            } message: { Text(ocrError ?? "Unknown error 未知錯誤") }

            // --- Simplified Focus/Update Logic ---
            .onChange(of: settings.error) { newError in showSettingsError = (newError != nil) }
            .onChange(of: ocrManager.error) { newError in ocrError = newError /* No need for DispatchQueue here */ }
            .onChange(of: ocrManager.isProcessing) { isProcessing in isLoading = isProcessing /* No need for DispatchQueue here */ }
            .onChange(of: selectedTab) { newTab in
                // Dismiss keyboard if navigating away
                if newTab != .text {
                    isTextEditorFocused = false
                } else {
                     // Set focus immediately when navigating TO this tab
                     // (Removed asyncAfter)
                     isTextEditorFocused = true
                }
            }
            .onChange(of: ocrManager.extractedText) { newText in
                 if ocrManager.hasNewOCRResult {
                     // Update settings only when OCR provides a new result
                     settings.extractedText = newText
                     ocrManager.hasNewOCRResult = false // Reset flag
                     #if DEBUG
                     print("TextTabView.onChange(ocrManager.extractedText) - Updated settings from NEW OCR.")
                     #endif
                     // Set focus immediately after receiving OCR text
                     // (Removed asyncAfter)
                      isTextEditorFocused = true
                 }
            }
            .onAppear {
                 #if DEBUG
                 print("TextTabView.onAppear: Editing=\(isEditingPastDictation), HasNewOCR=\(ocrManager.hasNewOCRResult), Processing=\(ocrManager.isProcessing)")
                 #endif
                 // Simplified onAppear logic
                 isLoading = ocrManager.isProcessing // Sync loading state
                 if !isLoading && !isEditingPastDictation && !ocrManager.hasNewOCRResult {
                     // If not loading, not editing, and no *new* OCR result waiting,
                     // ensure the OCR manager has the current text from settings.
                     ocrManager.updateExtractedText(settings.extractedText)
                 }
                  // Set initial focus immediately if applicable
                  // (Removed asyncAfter)
                  isTextEditorFocused = true
            }
            // --- End Simplified Focus/Update Logic ---

        } // End NavigationView
        .navigationViewStyle(.stack) // Use stack style
        .ignoresSafeArea(.keyboard, edges: .bottom) // Allow content to go under keyboard
    }
}

// --- Placeholder View Extension (No changes needed) ---
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .topLeading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            if shouldShow {
                placeholder().opacity(shouldShow ? 1 : 0) // Control opacity explicitly
            }
            self
        }
    }
}

#Preview {
    let settings = SettingsModel()
    let ocr = OCRManager()
    let sub = SubscriptionManager.shared
    // settings.extractedText = String(repeating: "This is a long line of text for testing jumpiness. ", count: 50) // Sample long text

    return TextTabView(selectedTab: .constant(.text), isEditingPastDictation: false)
        .environmentObject(settings)
        .environmentObject(ocr)
        .environmentObject(sub)
}
