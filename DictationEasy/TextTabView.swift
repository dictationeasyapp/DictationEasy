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
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .focused($isTextEditorFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done 完成") {
                                    isTextEditorFocused = false
                                }
                            }
                        }
                        .placeholder(when: settings.extractedText.isEmpty) {
                            Text("Extracted text will appear here 提取的文字將顯示在此處")
                                .foregroundColor(.gray)
                                .padding()
                        }
                        .onChange(of: settings.extractedText) { newText in
                            ocrManager.updateExtractedText(newText)
                        }
                }
                
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
                        Button(action: {}) {
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
                        if !settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            settings.savePastDictation(text: settings.extractedText)
                            ocrManager.updateExtractedText(settings.extractedText)
                        }
                        settings.playbackMode = .sentenceBySentence
                        selectedTab = .speech
                        isTextEditorFocused = false
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
                        BannerAdContainer()
                            .frame(height: 50)
                    }
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Text 文字")
            .alert("Settings Error 設置錯誤", isPresented: $showSettingsError) {
                Button("OK 確定", role: .cancel) {
                    settings.error = nil
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
            .onChange(of: ocrManager.extractedText) { newText in
                if ocrManager.hasNewOCRResult {
                    DispatchQueue.main.async {
                        settings.extractedText = newText
                        isLoading = false
                        ocrManager.hasNewOCRResult = false
                        #if DEBUG
                        print("TextTabView.onChange(ocrManager.extractedText) - Updated settings.extractedText: \(newText)")
                        #endif
                        // Defer focusing the TextEditor to avoid snapshotting issues
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextEditorFocused = true
                        }
                    }
                }
            }
            .onChange(of: ocrManager.isProcessing) { isProcessing in
                DispatchQueue.main.async {
                    isLoading = isProcessing
                    #if DEBUG
                    print("TextTabView.onChange(ocrManager.isProcessing) - isLoading: \(isLoading)")
                    #endif
                }
            }
            .onChange(of: selectedTab) { newTab in
                if newTab != .text {
                    isTextEditorFocused = false
                } else {
                    // Defer focusing the TextEditor when switching to this tab
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextEditorFocused = true
                    }
                }
            }
            .onAppear {
                if isEditingPastDictation {
                    if settings.editingDictationId == nil {
                        settings.extractedText = ocrManager.extractedText
                        #if DEBUG
                        print("TextTabView.onAppear - Synced with ocrManager (editing past dictation, no editingId)")
                        #endif
                    }
                    // Defer focusing the TextEditor to avoid snapshotting issues
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextEditorFocused = true
                    }
                } else if ocrManager.hasNewOCRResult {
                    if ocrManager.isProcessing {
                        isLoading = true
                        #if DEBUG
                        print("TextTabView.onAppear - OCR is processing, showing loading")
                        #endif
                    } else {
                        settings.extractedText = ocrManager.extractedText
                        isLoading = false
                        ocrManager.hasNewOCRResult = false
                        #if DEBUG
                        print("TextTabView.onAppear - Synced with ocrManager (new OCR result): \(settings.extractedText)")
                        #endif
                        // Defer focusing the TextEditor to avoid snapshotting issues
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextEditorFocused = true
                        }
                    }
                    settings.editingDictationId = nil
                } else {
                    ocrManager.updateExtractedText(settings.extractedText)
                    isLoading = false
                    settings.editingDictationId = nil
                    #if DEBUG
                    print("TextTabView.onAppear - Preserved settings.extractedText: \(settings.extractedText)")
                    #endif
                    // Defer focusing the TextEditor to avoid snapshotting issues
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextEditorFocused = true
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
