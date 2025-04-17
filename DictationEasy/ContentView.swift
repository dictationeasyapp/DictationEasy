import SwiftUI

struct ContentView: View {
    @StateObject private var settings = SettingsModel()
    @StateObject private var ocrManager = OCRManager()
    @StateObject private var ttsManager = TTSManager.shared // Use shared instance
    @StateObject private var playbackManager = PlaybackManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared // Add SubscriptionManager

    @State private var selectedTab: TabSelection = .scan
    @State private var isEditingPastDictation: Bool = false
    @State private var isProgrammaticNavigation: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanTabView(
                selectedTab: $selectedTab,
                isEditingPastDictation: $isEditingPastDictation,
                onNavigateToText: { isProgrammatic in
                    isProgrammaticNavigation = isProgrammatic
                    selectedTab = .text
                }
            )
            .tabItem {
                Label("Scan 掃描", systemImage: "camera")
            }
            .tag(TabSelection.scan)

            TextTabView(selectedTab: $selectedTab, isEditingPastDictation: isEditingPastDictation)
                .tabItem {
                    Label("Text 文字", systemImage: "doc.text")
                }
                .tag(TabSelection.text)

            SpeechTabView()
                .tabItem {
                    Label("Speech 朗讀", systemImage: "speaker.wave.2")
                }
                .tag(TabSelection.speech)
            
            SettingsTabView()
                .tabItem {
                    Label("Settings 設置", systemImage: "gear")
                }
                .tag(TabSelection.settings)
        }
        .environmentObject(settings) // Inject at root level
        .environmentObject(ocrManager)
        .environmentObject(ttsManager)
        .environmentObject(playbackManager)
        .environmentObject(subscriptionManager) // Inject SubscriptionManager
        .onChange(of: selectedTab) { newTab in
            #if DEBUG
            print("ContentView - selectedTab changed to: \(newTab.rawValue), isProgrammaticNavigation: \(isProgrammaticNavigation), isEditingPastDictation: \(isEditingPastDictation)")
            #endif
            
            if newTab == .text && !isProgrammaticNavigation {
                isEditingPastDictation = false
            }
            
            isProgrammaticNavigation = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsModel())
        .environmentObject(OCRManager())
        .environmentObject(TTSManager.shared)
        .environmentObject(PlaybackManager())
        .environmentObject(SubscriptionManager.shared)
}
