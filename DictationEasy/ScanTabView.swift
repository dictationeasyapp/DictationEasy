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

    var isFreeUser: Bool {
        return !subscriptionManager.isPremium
    }

    enum ScanLanguage: String, CaseIterable, Identifiable {
        case english = "English英文"
        case chinese = "Chinese中文"

        var id: String { self.rawValue }

        var visionLanguageCode: String {
            switch self {
            case .english:
                return "en-US"
            case .chinese:
                return "zh-Hans" // Consider zh-Hant for Traditional if needed
            }
        }
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        // Language Selection Picker
                        VStack(alignment: .leading) {
                            Text("Scan Language 掃描語言")
                                .font(.headline)
                                .padding(.horizontal)
                            Picker("Language 語言", selection: $selectedScanLanguage) {
                                ForEach(ScanLanguage.allCases) { language in
                                    Text(language.rawValue).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }

                        // Photo Selection and Camera Buttons
                        HStack(spacing: 20) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Label("Select Image 選擇圖片", systemImage: "photo")
                                    .font(.title2)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .onTapGesture {
                                // Resign focus before showing picker if needed,
                                // though PhotosPicker is generally less problematic than camera
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // Shorter delay might be okay
                                    checkPhotoLibraryPermission()
                                }
                            }
                            .onChange(of: selectedItem) { newItem in
                                if let newItem = newItem {
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let image = UIImage(data: data) {
                                            selectedImage = image
                                        } else {
                                            errorMessage = "Failed to load image 無法加載圖片"
                                            showError = true
                                        }
                                    }
                                } else {
                                    selectedImage = nil
                                }
                            }

                            // --- UPDATED CAMERA BUTTON ACTION ---
                            Button(action: {
                                // Dismiss the keyboard first
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                                // Add a small delay to allow the keyboard to fully dismiss
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    checkCameraPermission()
                                }
                            }) {
                                Label("Take Photo 拍照", systemImage: "camera")
                                    .font(.title2)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            // --- END UPDATED CAMERA BUTTON ACTION ---
                        }
                        .padding(.horizontal) // Added padding for better spacing

                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                                .padding(.horizontal) // Added padding
                            Text("Scanning in \(selectedScanLanguage.rawValue) 以\(selectedScanLanguage.rawValue == "English英文" ? "英文" : "中文")掃描")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if selectedImage != nil {
                            HStack(spacing: 20) {
                                Button(action: {
                                    selectedItem = nil
                                    selectedImage = nil
                                }) {
                                    Label("Cancel 取消", systemImage: "xmark")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(10)
                                }

                                Button(action: {
                                    processImage()
                                }) {
                                    Label("Extract Text 提取文字", systemImage: "text.viewfinder")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Past Dictations Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Past Dictation 過去文章")
                                .font(.headline)
                                .padding(.horizontal)

                            if settings.pastDictations.isEmpty {
                                Text("No past dictations 沒有過去文章")
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center) // Center if empty
                            } else {
                                ForEach(settings.pastDictations) { entry in
                                    Button(action: {
                                        if subscriptionManager.isPremium {
                                            settings.editingDictationId = entry.id
                                            settings.extractedText = entry.text
                                            isEditingPastDictation = true
                                            onNavigateToText(true)
                                            #if DEBUG
                                            print("ScanTabView - Selected entry for editing: \(entry.id)")
                                            print("ScanTabView - Set editingDictationId: \(String(describing: settings.editingDictationId))")
                                            #endif
                                        } else {
                                            showUpgradePrompt = true
                                        }
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(entry.date, style: .date)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                let sentences = entry.text.splitIntoSentences()
                                                let preview = sentences.isEmpty ? String(entry.text.prefix(50)) : sentences[0]
                                                Text(preview.count > 50 ? String(preview.prefix(50)) + "..." : preview)
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.secondarySystemGroupedBackground)) // Subtle background
                                        .cornerRadius(10)
                                        .shadow(color: .gray.opacity(0.1), radius: 1, x: 0, y: 1) // Softer shadow
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) { // Prevent full swipe delete
                                        if subscriptionManager.isPremium {
                                            Button(role: .destructive) {
                                                settings.deletePastDictation(id: entry.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        } else {
                                             // Optionally show upgrade prompt on swipe delete for free users
                                             Button {
                                                 showUpgradePrompt = true
                                             } label: {
                                                 Label("Upgrade", systemImage: "lock")
                                             }
                                             .tint(.orange)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top) // Add some space above the section

                        Spacer() // Pushes content up

                    } // End Main VStack
                    .padding(.vertical) // Add padding top/bottom of scroll content
                    .frame(minHeight: geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom) // Adjust minHeight for safe area
                } // End ScrollView
                .safeAreaInset(edge: .bottom) { // Place banner ad outside scrollview but respecting safe area
                     bannerAdSection
                         .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 10) // Add padding only if no safe area
                }
                .ignoresSafeArea(.keyboard, edges: .bottom) // Ignore keyboard inset
            } // End GeometryReader
            .background(Color(.systemGroupedBackground)) // Use system background
            .navigationTitle("Scan 掃描")
            .sheet(isPresented: $showCamera) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
                    .ignoresSafeArea() // Allow camera to use full screen
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
                    .environmentObject(subscriptionManager)
                    .environmentObject(settings) // Pass necessary environment objects
            }
            .alert("Photo Library Access Denied 無法訪問照片庫", isPresented: $showPermissionAlert) {
                Button("Go to Settings 前往設置", role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Please grant photo library access in Settings to scan images.\n請在設置中授予照片庫訪問權限以掃描圖片。")
            }
            .alert("Limited Photo Access 照片訪問受限", isPresented: $showLimitedAccessMessage) {
                Button("Select More Photos 選擇更多照片", role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Continue 繼續", role: .cancel) { }
            } message: {
                Text("You have limited photo access. Select more photos to scan, or continue with the current selection.\n您已限制照片訪問。選擇更多照片進行掃描，或繼續使用當前選擇。")
            }
            .alert("Camera Access Denied 相機訪問被拒絕", isPresented: $showCameraPermissionAlert) {
                Button("Go to Settings 前往設置", role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Please enable camera access in Settings to take photos.\n請在設置中啟用相機訪問以拍攝照片。")
            }
            .alert("Camera Unavailable 相機不可用", isPresented: $showCameraUnavailableAlert) {
                Button("OK 確定", role: .cancel) { }
            } message: {
                Text("The camera is not available on this device.\n該設備上相機不可用。")
            }
            .alert("Error 錯誤", isPresented: $showError) {
                Button("OK 確定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Settings Error 設置錯誤", isPresented: $showSettingsError) {
                Button("OK 確定", role: .cancel) {
                    settings.error = nil
                }
            } message: {
                Text(settings.error ?? "Unknown error 未知錯誤")
            }
            .alert("Upgrade to Premium 升級到高級版", isPresented: $showUpgradePrompt) {
                Button("Upgrade 升級", role: .none) {
                    showSubscriptionView = true
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Unlock unlimited past dictation storage and more with a Premium subscription!\n通過高級訂閱解鎖無限過去文章存儲等功能！")
            }
            .onChange(of: settings.error) { newError in
                if newError != nil {
                    showSettingsError = true
                }
            }
            .onAppear {
                // Reset selection state when the tab appears
                if selectedImage != nil || selectedItem != nil {
                    selectedImage = nil
                    selectedItem = nil
                    #if DEBUG
                    print("ScanTabView - onAppear: Reset selectedImage and selectedItem")
                    #endif
                }
            }
        } // End NavigationView
        .navigationViewStyle(.stack) // Use stack style for consistency
    }

    private var bannerAdSection: some View {
        VStack { // Use VStack to manage padding/background if needed
            if isFreeUser {
                BannerAdContainer()
                    .frame(height: 50) // Standard banner height
                    .frame(maxWidth: .infinity) // Ensure it takes full width
            } else {
                EmptyView() // Takes no space if premium
            }
        }
        .background(Color(.systemBackground)) // Match background if needed
    }

    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized:
            print("Photo Library: Authorized")
            showLimitedAccessMessage = false // Ensure this is reset
        case .limited:
            print("Photo Library: Limited")
            showLimitedAccessMessage = true
        case .denied, .restricted:
            print("Photo Library: Denied or Restricted")
            showPermissionAlert = true
        case .notDetermined:
            print("Photo Library: Not Determined, requesting...")
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    print("Photo Library: Permission result - \(newStatus.rawValue)")
                    switch newStatus {
                    case .authorized:
                        showLimitedAccessMessage = false
                    case .limited:
                        showLimitedAccessMessage = true
                    case .denied, .restricted:
                        showPermissionAlert = true
                    default: // Should cover .notDetermined again (unlikely) & @unknown
                        showPermissionAlert = true
                    }
                }
            }
        @unknown default:
            print("Photo Library: Unknown status")
            showPermissionAlert = true
        }
    }

    // --- UPDATED checkCameraPermission ---
    private func checkCameraPermission() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera: Not available on this device.")
            showCameraUnavailableAlert = true
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            print("Camera: Authorized")
            // Ensure UI update happens on main thread
            DispatchQueue.main.async {
                self.showCamera = true
            }
        case .denied, .restricted:
            print("Camera: Denied or Restricted")
            showCameraPermissionAlert = true
        case .notDetermined:
            print("Camera: Not Determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    print("Camera: Permission result - \(granted)")
                    if granted {
                        self.showCamera = true
                    } else {
                        self.showCameraPermissionAlert = true
                    }
                }
            }
        @unknown default:
            print("Camera: Unknown status")
            showCameraPermissionAlert = true
        }
    }
    // --- END UPDATED checkCameraPermission ---

    private func processImage() {
        guard let image = selectedImage else {
             print("processImage: No image selected.")
             return
        }
        // Optionally resign focus before starting processing
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        print("processImage: Starting OCR for language \(selectedScanLanguage.visionLanguageCode)")
        Task {
            do {
                try await ocrManager.processImage(image, scanLanguage: selectedScanLanguage)
                // Check OCRManager's error property AFTER the async call completes
                if let ocrError = ocrManager.error {
                     print("processImage: OCR failed with error: \(ocrError)")
                     throw NSError(domain: "OCRManagerError", code: -1, userInfo: [NSLocalizedDescriptionKey: ocrError])
                }
                print("processImage: OCR successful. Text length: \(ocrManager.extractedText.count)")
                // Update SettingsModel and navigate
                settings.extractedText = ocrManager.extractedText
                settings.savePastDictation(text: settings.extractedText) // Save the new entry
                isEditingPastDictation = false // Ensure we are not in editing mode
                onNavigateToText(true) // Navigate programmatically
            } catch {
                print("processImage: Catch block error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showError = true
            }
            // Reset image selection regardless of success/failure
            selectedItem = nil
            selectedImage = nil
             print("processImage: Reset selectedItem and selectedImage.")
        }
    }

    #else // Fallback for non-UIKit platforms
    var body: some View {
        NavigationView {
            Text("Scan feature is only available on iOS devices.\n掃描功能僅在 iOS 設備上可用。")
                .padding()
                .multilineTextAlignment(.center)
                .navigationTitle("Scan 掃描")
        }
    }
    #endif
}

// Preview needs adjustments if not on iOS or missing dependencies
#if canImport(UIKit)
#Preview {
    // Create mock environment objects for preview
    let settings = SettingsModel()
    let ocr = OCRManager()
    let subManager = SubscriptionManager.shared // Use shared instance for preview consistency
    settings.pastDictations = [ // Add sample data
         DictationEntry(text: "This is the first past dictation preview."),
         DictationEntry(text: "这是第二篇过去文章的预览。")
    ]

    return ScanTabView(
        selectedTab: .constant(.scan),
        isEditingPastDictation: .constant(false),
        onNavigateToText: { isProgrammatic in print("Navigate to Text: \(isProgrammatic)") }
    )
    .environmentObject(settings)
    .environmentObject(ocr)
    .environmentObject(subManager)
}
#endif
