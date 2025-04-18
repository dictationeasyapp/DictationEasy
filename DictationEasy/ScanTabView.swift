import SwiftUI
#if canImport(UIKit)
import PhotosUI
import Vision
import Photos
import AVFoundation
import UIKit
#endif

struct ScanTabView: View {
    #if canImport(UIKit)
    @EnvironmentObject var settings: SettingsModel
    @Binding var selectedTab: TabSelection
    @EnvironmentObject var ocrManager: OCRManager
    @Binding var isEditingPastDictation: Bool
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    let onNavigateToText: (Bool) -> Void

    // States for UI control
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPermissionAlert = false
    @State private var showLimitedAccessMessage = false
    @State private var showCameraPermissionAlert = false
    @State private var showCameraUnavailableAlert = false
    @State private var showCamera = false
    @State private var showSettingsError = false
    @State private var showUpgradePrompt = false
    @State private var showSubscriptionView = false
    @State private var selectedScanLanguage: ScanLanguage = .english

    // State for Delete Confirmation
    @State private var entryToDelete: DictationEntry? = nil


    var isFreeUser: Bool {
        return !subscriptionManager.isPremium
    }

    // ScanLanguage Enum
    enum ScanLanguage: String, CaseIterable, Identifiable {
        case english = "English英文"
        case chinese = "Chinese中文"
        var id: String { self.rawValue }
        var visionLanguageCode: String {
            switch self {
            case .english: return "en-US"
            case .chinese: return "zh-Hans"
            }
        }
    }

    var body: some View {
        NavigationView {
            // Use VStack as the main container
            VStack(spacing: 0) {
                languagePickerSection // Extracted
                    .padding(.vertical)

                photoAndCameraButtons // Extracted

                // --- Image Preview & Action Buttons (Conditional) ---
                 VStack { // Group these related items
                     if let image = selectedImage {
                         imagePreviewSection(image: image)
                         actionButtonsSection
                     }
                 }
                 .padding(.top, selectedImage != nil ? 10 : 0) // Add space only if image is shown


                // --- Past Dictations Section (Using List) ---
                Section {
                    List {
                        if settings.pastDictations.isEmpty {
                            Text("No past dictations 沒有過去文章")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(settings.pastDictations) { entry in
                                dictationEntryRow(entry) // Use ViewBuilder function
                            }
                        }
                    }
                    .listStyle(.plain)
                    // Add explicit background if needed with plain style
                    // .background(Color(.systemGroupedBackground))
                    .frame(maxHeight: .infinity) // Allow list to take available space

                } header: {
                    Text("Past Dictation 過去文章")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top) // Add space above the list header
                }
                // --- End Past Dictations Section ---


                // Banner Ad at the bottom
                bannerAdSection

            } // End Main VStack
            .background(Color(.systemGroupedBackground).ignoresSafeArea(.all, edges: .all))
            .navigationTitle("Scan 掃描")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCamera) { ImagePicker(selectedImage: $selectedImage, sourceType: .camera).ignoresSafeArea() }
            .sheet(isPresented: $showSubscriptionView) { SubscriptionView().environmentObject(subscriptionManager).environmentObject(settings) }
            // --- Alerts ---
            .alert("Photo Library Access Denied 無法訪問照片庫", isPresented: $showPermissionAlert) { alertButtonsGoToSettings() } message: { alertMessagePhotoLibraryDenied() }
            .alert("Limited Photo Access 照片訪問受限", isPresented: $showLimitedAccessMessage) { alertButtonsLimitedPhotoAccess() } message: { alertMessageLimitedPhotoAccess() }
            .alert("Camera Access Denied 相機訪問被拒絕", isPresented: $showCameraPermissionAlert) { alertButtonsGoToSettings() } message: { alertMessageCameraDenied() }
            .alert("Camera Unavailable 相機不可用", isPresented: $showCameraUnavailableAlert) { alertButtonsOk() } message: { alertMessageCameraUnavailable() }
            .alert("Error 錯誤", isPresented: $showError) { alertButtonsOk() } message: { Text(errorMessage) }
            .alert("Settings Error 設置錯誤", isPresented: $showSettingsError) { alertButtonsOk { settings.error = nil } } message: { Text(settings.error ?? "Unknown error") }
            .alert("Upgrade to Premium 升級到高級版", isPresented: $showUpgradePrompt) { alertButtonsUpgrade() } message: { alertMessageUpgrade() }
            .alert("Delete Dictation Entry?", isPresented: .constant(entryToDelete != nil), presenting: entryToDelete)
                   { entryData in alertButtonsDeleteEntry(entryData: entryData) }
                   message: { entryData in alertMessageDeleteEntry(entryData: entryData) }
            // --- End Alerts ---
            .onChange(of: settings.error) { newError in showSettingsError = (newError != nil) }
            .onAppear {
                if selectedImage != nil || selectedItem != nil {
                    selectedImage = nil; selectedItem = nil
                    #if DEBUG
                    print("ScanTabView - onAppear: Reset selectedImage and selectedItem")
                    #endif
                }
            }
        } // End NavigationView
        .navigationViewStyle(.stack)
    } // End body


    // MARK: - Subviews (Computed Properties)

    // --- **** RESTORED IMPLEMENTATIONS **** ---
    private var languagePickerSection: some View {
        VStack(alignment: .leading) {
            Text("Scan Language 掃描語言").font(.headline).padding(.horizontal)
            Picker("Language 語言", selection: $selectedScanLanguage) {
                ForEach(ScanLanguage.allCases) { language in Text(language.rawValue).tag(language) }
            }.pickerStyle(.segmented).padding(.horizontal)
        }
    }

    private var photoAndCameraButtons: some View {
        HStack(spacing: 20) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Select Image 選擇圖片", systemImage: "photo")
                   .font(.body).padding().frame(maxWidth: .infinity)
                   .background(Color.blue).foregroundColor(.white).cornerRadius(10)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { checkPhotoLibraryPermission() }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                   if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        selectedImage = image
                   } else if newItem != nil {
                       errorMessage = "Failed to load image 無法加載圖片"; showError = true
                   } else {
                       selectedImage = nil
                   }
                }
            }

            Button(action: {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { checkCameraPermission() }
            }) {
                Label("Take Photo 拍照", systemImage: "camera")
                   .font(.body).padding().frame(maxWidth: .infinity)
                   .background(Color.blue).foregroundColor(.white).cornerRadius(10)
            }
        }.padding(.horizontal)
    }

    private func imagePreviewSection(image: UIImage) -> some View {
        VStack {
            Image(uiImage: image)
                 .resizable().scaledToFit().frame(height: 150)
                 .cornerRadius(10).padding(.horizontal).padding(.top)
             Text("Scanning in \(selectedScanLanguage.rawValue) 以\(selectedScanLanguage.rawValue == "English英文" ? "英文" : "中文")掃描")
                 .font(.caption).foregroundColor(.secondary)
        }
    }

    private var actionButtonsSection: some View {
         HStack(spacing: 20) {
             Button(action: { selectedItem = nil; selectedImage = nil }) {
                 Label("Cancel", systemImage: "xmark")
                     .font(.body).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                     .background(Color.red).cornerRadius(10)
             }
             Button(action: { processImage() }) {
                 Label("Extract Text", systemImage: "text.viewfinder")
                    .font(.body).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                    .background(Color.blue).cornerRadius(10)
             }
         }.padding(.horizontal).padding(.bottom) // Add bottom padding
    }

    // NOTE: pastDictationsListSection was integrated into the main body with List

    // Helper View Builder for individual dictation row
    @ViewBuilder
    private func dictationEntryRow(_ entry: DictationEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.date, style: .date).font(.subheadline).foregroundColor(.primary)
                let sentences = entry.text.splitIntoSentences()
                let preview = sentences.isEmpty ? String(entry.text.prefix(50)) : sentences[0]
                Text(preview.count > 50 ? String(preview.prefix(50)) + "..." : preview)
                    .font(.body).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if subscriptionManager.isPremium {
                settings.editingDictationId = entry.id
                settings.extractedText = entry.text
                isEditingPastDictation = true
                onNavigateToText(true)
                #if DEBUG
                print("ScanTabView - Tapped entry for editing: \(entry.id)")
                #endif
            } else {
                showUpgradePrompt = true
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if subscriptionManager.isPremium {
                Button(role: .destructive) { entryToDelete = entry } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                 Button { showUpgradePrompt = true } label: {
                     Label("Upgrade", systemImage: "lock")
                 }.tint(.orange)
            }
        }
    }

    private var bannerAdSection: some View {
        VStack {
            if isFreeUser {
                BannerAdContainer().frame(height: 50).frame(maxWidth: .infinity)
            } else {
                EmptyView()
            }
        }
        .background(Color(.systemBackground))
    }
    // --- **** END RESTORED IMPLEMENTATIONS **** ---


    // MARK: - Alert Components (Restored Implementations)
    @ViewBuilder private func alertButtonsGoToSettings() -> some View {
         Button("Go to Settings 前往設置") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
         Button("Cancel 取消", role: .cancel) {}
    }
    @ViewBuilder private func alertButtonsLimitedPhotoAccess() -> some View {
         Button("Select More Photos 選擇更多照片") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
         Button("Continue 繼續", role: .cancel) {}
    }
    @ViewBuilder private func alertButtonsOk(action: (() -> Void)? = nil) -> some View {
        Button("OK 確定") { action?() }
    }
     @ViewBuilder private func alertButtonsUpgrade() -> some View {
         Button("Upgrade 升級") { showSubscriptionView = true }
         Button("Cancel 取消", role: .cancel) {}
    }
    @ViewBuilder private func alertButtonsDeleteEntry(entryData: DictationEntry) -> some View {
        Button("Delete 刪除", role: .destructive) { settings.deletePastDictation(id: entryData.id); entryToDelete = nil }
        Button("Cancel 取消", role: .cancel) { entryToDelete = nil }
    }

    private func alertMessagePhotoLibraryDenied() -> some View { Text("Please grant photo library access...") }
    private func alertMessageLimitedPhotoAccess() -> some View { Text("You have limited photo access...") }
    private func alertMessageCameraDenied() -> some View { Text("Please enable camera access...") }
    private func alertMessageCameraUnavailable() -> some View { Text("The camera is not available...") }
    private func alertMessageUpgrade() -> some View { Text("Unlock unlimited past dictation storageand more with a Premium subscription!\n通過高級訂閱解鎖無限過去文章存儲等功能！") }
    private func alertMessageDeleteEntry(entryData: DictationEntry) -> some View {
        Text("Are you sure you want to delete this entry dated \(entryData.date.formatted(date: .numeric, time: .omitted))?\n您確定要刪除此日期為 \(entryData.date.formatted(date: .numeric, time: .omitted)) 的條目嗎？")
    }
    // --- **** END RESTORED ALERT COMPONENTS **** ---


    // MARK: - Permission & Processing Logic (Restored Implementations)
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized: print("Photo Library: Authorized"); showLimitedAccessMessage = false
        case .limited: print("Photo Library: Limited"); showLimitedAccessMessage = true
        case .denied, .restricted: print("Photo Library: Denied or Restricted"); showPermissionAlert = true
        case .notDetermined:
            print("Photo Library: Not Determined, requesting...")
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    print("Photo Library: Permission result - \(newStatus.rawValue)")
                    switch newStatus {
                    case .authorized: showLimitedAccessMessage = false
                    case .limited: showLimitedAccessMessage = true
                    case .denied, .restricted: showPermissionAlert = true
                    default: showPermissionAlert = true
                    }
                }
            }
        @unknown default: print("Photo Library: Unknown status"); showPermissionAlert = true
        }
    }

    private func checkCameraPermission() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera: Not available on this device."); showCameraUnavailableAlert = true; return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: print("Camera: Authorized"); DispatchQueue.main.async { self.showCamera = true }
        case .denied, .restricted: print("Camera: Denied or Restricted"); showCameraPermissionAlert = true
        case .notDetermined:
            print("Camera: Not Determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    print("Camera: Permission result - \(granted)")
                    if granted { self.showCamera = true } else { self.showCameraPermissionAlert = true }
                }
            }
        @unknown default: print("Camera: Unknown status"); showCameraPermissionAlert = true
        }
    }

    private func processImage() {
        guard let image = selectedImage else { print("processImage: No image selected."); return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        print("processImage: Starting OCR for language \(selectedScanLanguage.visionLanguageCode)")
        Task {
            do {
                try await ocrManager.processImage(image, scanLanguage: selectedScanLanguage)
                if let ocrError = ocrManager.error {
                     print("processImage: OCR failed with error: \(ocrError)")
                     throw NSError(domain: "OCRManagerError", code: -1, userInfo: [NSLocalizedDescriptionKey: ocrError])
                }
                print("processImage: OCR successful. Text length: \(ocrManager.extractedText.count)")
                settings.extractedText = ocrManager.extractedText
                settings.savePastDictation(text: settings.extractedText)
                isEditingPastDictation = false
                onNavigateToText(true)
            } catch {
                print("processImage: Catch block error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription; showError = true
            }
            selectedItem = nil; selectedImage = nil
            print("processImage: Reset selectedItem and selectedImage.")
        }
    }
    // --- **** END RESTORED FUNCTIONS **** ---


    #else // Fallback for non-UIKit platforms
    // Fallback Body
    var body: some View {
        NavigationView {
            Text("Scan feature is only available on iOS devices.\n掃描功能僅在 iOS 設備上可用。")
                .padding().multilineTextAlignment(.center).navigationTitle("Scan 掃描")
        }
    }
    #endif // End #if canImport(UIKit)
} // End struct ScanTabView


// Preview needs adjustments if not on iOS or missing dependencies
#if canImport(UIKit)
#Preview {
    // --- Create instances needed for the view ---
    let settings = SettingsModel()
    let ocr = OCRManager()
    let subManager = SubscriptionManager.shared

    // --- Conditionally set up mock data for preview ---
    #if DEBUG
    settings.pastDictations = [ // Add sample data
         DictationEntry(text: "This is the first past dictation preview."),
         DictationEntry(text: "这是第二篇过去文章的预览。")
    ]
    // subManager.isPremium = true // Uncomment to test premium swipe actions
    print("Preview setup complete with mock data.")
    #endif

    // --- Always return the main view ---
    return ScanTabView( // Use explicit return
        selectedTab: .constant(.scan),
        isEditingPastDictation: .constant(false),
        onNavigateToText: { isProgrammatic in print("Navigate to Text: \(isProgrammatic)") }
    )
    .environmentObject(settings)
    .environmentObject(ocr)
    .environmentObject(subManager)
}
#endif
