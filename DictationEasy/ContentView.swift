import SwiftUI

// Lazy container to defer view creation
struct LazyView<Content: View>: View {
    let build: () -> Content
    var body: some View {
        build()
    }
}

struct ContentView: View {
    @StateObject private var settings = SettingsModel()
    @StateObject private var ocrManager = OCRManager()
    @StateObject private var ttsManager = TTSManager.shared
    @StateObject private var playbackManager = PlaybackManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedTab: TabSelection = .scan
    @State private var isEditingPastDictation: Bool = false
    @State private var isProgrammaticNavigation: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            LazyView {
                ScanTabView(
                    selectedTab: $selectedTab,
                    isEditingPastDictation: $isEditingPastDictation,
                    onNavigateToText: { isProgrammatic in
                        isProgrammaticNavigation = isProgrammatic
                        selectedTab = .text
                    }
                )
            }
            .tabItem { Label("Scan 掃描", systemImage: "camera") }
            .tag(TabSelection.scan)

            LazyView {
                TextTabView(selectedTab: $selectedTab, isEditingPastDictation: isEditingPastDictation)
            }
            .tabItem { Label("Text 文字", systemImage: "doc.text") }
            .tag(TabSelection.text)

            LazyView {
                SpeechTabView()
            }
            .tabItem { Label("Speech 朗讀", systemImage: "speaker.wave.2") }
            .tag(TabSelection.speech)

            LazyView {
                SettingsTabView()
            }
            .tabItem { Label("Settings 設置", systemImage: "gear") }
            .tag(TabSelection.settings)
        }
        .environmentObject(settings)
        .environmentObject(ocrManager)
        .environmentObject(ttsManager)
        .environmentObject(playbackManager)
        .environmentObject(subscriptionManager)
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
