import SwiftUI

struct SpeechTabView: View {
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var ttsManager: TTSManager
    @EnvironmentObject var playbackManager: PlaybackManager // Use this for sentences
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var showUpgradePrompt = false
    @State private var showSubscriptionView = false

    var isFreeUser: Bool {
        return !subscriptionManager.isPremium
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    togglesSection
                    textDisplaySection
                    playbackModePickerSection
                    teacherModeSettingsSection
                    speedSliderSection
                    languagePickerSection
                    playbackControlsSection
                    progressTextSection
                    voiceAvailabilityWarningSection
                    bannerAdSection
                }
                .padding(.vertical) // Add vertical padding to the main VStack
            }
            .background(Color(.systemGroupedBackground)) // Set background for the whole scroll view
            .navigationTitle("Speech 朗讀")
            .onChange(of: settings.playbackMode) { newMode in
                playbackManager.stopPlayback()
                ttsManager.stopSpeaking()
                if newMode == .teacherMode {
                    // Reset index when switching to teacher mode
                    playbackManager.currentSentenceIndex = 0
                    playbackManager.currentRepetition = 1 // Reset repetition too
                } else if newMode == .wholePassage {
                    // Restore order if switching to whole passage and shuffle was active
                    if playbackManager.isShuffled {
                        playbackManager.restoreOriginalOrder()
                    }
                }
                 // No specific reset needed for sentenceBySentence mode here
            }
            .onAppear {
                 // Ensure sentences are set based on the current text when the view appears
                playbackManager.setSentences(settings.extractedText)
                #if DEBUG
                print("SpeechTabView.onAppear: Initial extractedText = '\(settings.extractedText.prefix(50))...', sentences count = \(playbackManager.sentences.count)")
                #endif
            }
            .onChange(of: settings.extractedText) { newText in
                // Update sentences when the source text changes
                playbackManager.stopPlayback() // Stop current playback
                ttsManager.stopSpeaking()
                playbackManager.setSentences(newText) // Update sentences in PlaybackManager
                #if DEBUG
                print("SpeechTabView.onChange(extractedText): New text = '\(newText.prefix(50))...', sentences count = \(playbackManager.sentences.count)")
                #endif
            }
            .sheet(isPresented: $showSubscriptionView) {
                // Pass environment objects if needed by SubscriptionView or its children
                SubscriptionView()
                    .environmentObject(subscriptionManager)
                    .environmentObject(settings) // Pass if needed
            }
            .alert("Upgrade to Premium 升級到高級版", isPresented: $showUpgradePrompt) {
                Button("Upgrade 升級", role: .none) {
                    showSubscriptionView = true
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Unlock this feature and more with a Premium subscription!\n通過高級訂閱解鎖此功能等更多功能！")
            }
            .alert("Speech Error 語音錯誤", isPresented: Binding(
                get: { ttsManager.error != nil },
                set: { if !$0 { ttsManager.error = nil } } // Clear error when dismissed
            )) {
                Button("OK 確定", role: .cancel) { }
            } message: {
                Text(ttsManager.error ?? "Unknown error 未知錯誤")
            }
             .alert("Playback Error 播放錯誤", isPresented: Binding( // Alert for PlaybackManager errors
                 get: { playbackManager.error != nil },
                 set: { if !$0 { playbackManager.error = nil } }
             )) {
                 Button("OK 確定", role: .cancel) { }
             } message: {
                 Text(playbackManager.error ?? "Unknown playback error 未知播放錯誤")
             }
        }
        .navigationViewStyle(.stack) // Use stack style
    }

    private var togglesSection: some View {
        VStack(spacing: 15) { // Adjust spacing
            Toggle("Show Text 顯示文字", isOn: $settings.showText)
                .padding(.horizontal)

            Toggle("Including Punctuations 包含標點符號", isOn: $settings.includePunctuation)
                .onChange(of: settings.includePunctuation) { newValue in
                    if newValue && !subscriptionManager.isPremium {
                        settings.includePunctuation = false // Prevent toggle if not premium
                        showUpgradePrompt = true
                    }
                }
                .padding(.horizontal)
        }
    }

    private var textDisplaySection: some View {
        Group {
            if settings.showText {
                if settings.playbackMode != .wholePassage {
                    Button(action: {
                        if subscriptionManager.isPremium {
                            playbackManager.stopPlayback() // Stop before shuffling/restoring
                            ttsManager.stopSpeaking()
                            if playbackManager.isShuffled {
                                playbackManager.restoreOriginalOrder()
                            } else {
                                playbackManager.shuffleSentences()
                            }
                        } else {
                            showUpgradePrompt = true
                        }
                    }) {
                        Label(playbackManager.isShuffled ? "Restore Order 恢復原序" : "Random 隨機調亂次序",
                              systemImage: playbackManager.isShuffled ? "arrow.clockwise" : "shuffle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(playbackManager.sentences.isEmpty ? Color.gray : Color.blue) // Use gray if disabled
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    // *** Use playbackManager.sentences ***
                    .disabled(playbackManager.sentences.isEmpty || settings.playbackMode == .wholePassage)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            // *** Use playbackManager.sentences ***
                            ForEach(Array(playbackManager.sentences.enumerated()), id: \.offset) { index, sentence in
                                Text(sentence)
                                    .font(.system(size: settings.fontSize))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading) // Ensure text takes full width
                                    .background(
                                        shouldHighlightSentence(index: index)
                                            ? Color.yellow.opacity(0.3) // Highlight color
                                            : Color.clear
                                    )
                                    .cornerRadius(8)
                                    .id(index) // ID for scrolling
                            }
                        }
                        .padding() // Padding inside the ScrollView content
                    }
                    .frame(maxHeight: 200) // Limit height
                    .background(Color(.secondarySystemGroupedBackground)) // Use a slightly different background
                    .cornerRadius(10)
                    .overlay( // Add a subtle border
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .onChange(of: playbackManager.currentSentenceIndex) { newIndex in
                        // Scroll logic remains the same, just checking conditions
                        if settings.showText &&
                           playbackManager.isPlaying &&
                           (settings.playbackMode == .teacherMode || settings.playbackMode == .sentenceBySentence) {
                            withAnimation(.easeInOut) { // Add animation
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            } else {
                 // Optional: Show a placeholder if text is hidden but sentences exist
                 if !playbackManager.sentences.isEmpty {
                      Text("Text hidden. Tap Play to listen.\n文字已隱藏。點擊播放收聽。")
                          .font(.caption)
                          .foregroundColor(.secondary)
                          .frame(height: 50) // Give it some space
                          .padding(.horizontal)
                 }
            }
        }
    }

    private var playbackModePickerSection: some View {
        Picker("Mode 模式", selection: $settings.playbackMode) {
            ForEach(PlaybackMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var teacherModeSettingsSection: some View {
        Group {
            // Only show if Teacher Mode is selected
            if settings.playbackMode == .teacherMode {
                // Use DisclosureGroup for better UI if needed, or keep VStack
                VStack(spacing: 10) {
                    Stepper("Pause Duration 暫停時間: \(settings.pauseDuration)s",
                            value: $settings.pauseDuration,
                            in: 1...15) // Range 1 to 15 seconds

                    Stepper("Repetitions 重複次數: \(settings.repetitions)",
                            value: $settings.repetitions,
                            in: 1...5) // Range 1 to 5 repetitions
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .scale)) // Add transition
            }
        }
        .animation(.easeInOut, value: settings.playbackMode) // Animate changes based on mode
    }

    private var speedSliderSection: some View {
        VStack(alignment: .leading) {
            Text("Speed 速度: \(String(format: "%.2f", settings.playbackSpeed))x")
                 .padding(.leading) // Align with slider start
            Slider(value: $settings.playbackSpeed,
                   in: 0.1...1.0, // Adjust min speed if needed, AVSpeechUtteranceMinimumSpeechRate is 0.0
                   step: 0.05) { editing in
                        // Optional: Stop playback if user starts dragging slider
                        if editing {
                             if playbackManager.isPlaying {
                                 playbackManager.stopPlayback()
                                 ttsManager.stopSpeaking()
                             }
                        }
                   }
                   .padding(.horizontal)
        }
    }

    private var languagePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
             HStack { // Use HStack for label and picker
                 Text("Language 語言:")
                 Spacer() // Push picker to the right
                 Picker("Language 語言", selection: $settings.audioLanguage) {
                     ForEach(AudioLanguage.allCases, id: \.self) { language in
                         Text(language.rawValue).tag(language)
                     }
                 }
                 .pickerStyle(.menu) // Use menu style for compactness
                 .onChange(of: settings.audioLanguage) { _ in
                      // Stop playback when language changes
                     if playbackManager.isPlaying {
                          playbackManager.stopPlayback()
                          ttsManager.stopSpeaking()
                     }
                 }
             }
             .padding(.horizontal)


            if settings.audioLanguage == .mandarin || settings.audioLanguage == .cantonese {
                Text("Check Settings > Accessibility > Spoken Content > Voices to ensure the correct Chinese variant is selected.\n請檢查設置 > 輔助功能 > 語音內容 > 語音，確保選擇正確的中文變體。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading) // Align text left
                    .padding(.horizontal)
            }
        }
    }

    private var playbackControlsSection: some View {
        // Use adaptive layout for controls
        ViewThatFits {
             // Horizontal layout for wider screens
             HStack(spacing: 10) {
                 playbackButtons()
             }
             .padding(.horizontal)

             // Vertical layout for narrower screens
             VStack(spacing: 10) {
                 playbackButtons()
             }
             .padding(.horizontal)
        }
    }

    // Helper function to create buttons, avoiding repetition
    @ViewBuilder
    private func playbackButtons() -> some View {
        // Play/Stop Button (Common to all modes except SentenceBySentence image)
        Button(action: handlePlayStop) {
             // Use Image for SentenceBySentence, Label for others
             if settings.playbackMode == .sentenceBySentence {
                 Image(systemName: playbackManager.isPlaying ? "stop.fill" : "play.fill")
                     .imageScale(.large) // Make icon larger
                     .frame(width: 50, height: 50) // Fixed size touch target
                     .foregroundColor(.white)
                     .background(Color.blue)
                     .clipShape(Circle()) // Use circle shape
             } else {
                 Label(playbackManager.isPlaying ? "Stop 停止" : "Play 播放",
                       systemImage: playbackManager.isPlaying ? "stop.fill" : "play.fill")
                     .font(.headline)
                     .foregroundColor(.white)
                     .frame(maxWidth: .infinity) // Expand horizontally
                     .frame(height: 50) // Fixed height
                     .background(playbackManager.sentences.isEmpty ? Color.gray : Color.blue)
                     .cornerRadius(10)
             }
        }
        // *** Use playbackManager.sentences ***
        .disabled(playbackManager.sentences.isEmpty)

        // Restart Button (Modes: Whole Passage, Teacher Mode)
         if settings.playbackMode == .wholePassage || settings.playbackMode == .teacherMode {
             Button(action: handleRestart) {
                 Label("Restart 重新開始", systemImage: "arrow.clockwise")
                     .font(.headline)
                     .foregroundColor(.white)
                     .frame(maxWidth: .infinity)
                     .frame(height: 50)
                      .background(playbackManager.sentences.isEmpty ? Color.gray : Color.blue)
                     .cornerRadius(10)
             }
             // *** Use playbackManager.sentences ***
             .disabled(playbackManager.sentences.isEmpty)
         }


        // Sentence Navigation Buttons (Mode: SentenceBySentence)
        if settings.playbackMode == .sentenceBySentence {
            // Restart Sentence
            Button(action: handleRestart) {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.large)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
                    .background(playbackManager.sentences.isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            // *** Use playbackManager.sentences ***
            .disabled(playbackManager.sentences.isEmpty)

            // Previous Sentence
            Button(action: handlePrevious) {
                Image(systemName: "backward.fill")
                    .imageScale(.large)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
                     .background(playbackManager.sentences.isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
             // *** Use playbackManager.sentences ***
             .disabled(playbackManager.sentences.isEmpty)


            // Next Sentence
            Button(action: handleNext) {
                Image(systemName: "forward.fill")
                    .imageScale(.large)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
                    .background(playbackManager.sentences.isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
             // *** Use playbackManager.sentences ***
             .disabled(playbackManager.sentences.isEmpty)
        }
    }


    // --- Action Handlers for Playback Buttons ---

    private func handlePlayStop() {
        #if DEBUG
        print("SpeechTabView: Play/Stop button tapped, mode = \(settings.playbackMode.rawValue), isPlaying = \(playbackManager.isPlaying)")
        #endif

        if playbackManager.isPlaying {
            // Stop current playback
            playbackManager.stopPlayback()
            ttsManager.stopSpeaking()
        } else {
            // Start playback based on mode
            switch settings.playbackMode {
            case .wholePassage:
                guard !playbackManager.sentences.isEmpty else {
                    ttsManager.error = "No sentences to play 無句子可播放"
                    return
                }
                playbackManager.isPlaying = true // Set playing state
                let text = settings.processTextForSpeech(playbackManager.sentences.joined(separator: " ")) // Join sentences for whole passage
                ttsManager.speak(
                    text: text,
                    language: settings.audioLanguage,
                    rate: settings.playbackSpeed
                )

            case .sentenceBySentence:
                guard let sentence = playbackManager.getCurrentSentence() else {
                    ttsManager.error = "No sentence available 無可用句子"
                    return
                }
                playbackManager.isPlaying = true // Set playing state
                ttsManager.speak(
                    text: settings.processTextForSpeech(sentence),
                    language: settings.audioLanguage,
                    rate: settings.playbackSpeed
                )

            case .teacherMode:
                if subscriptionManager.isPremium {
                    // Start teacher mode from the current index (or beginning if stopped)
                     if playbackManager.currentSentenceIndex >= playbackManager.sentences.count {
                          playbackManager.currentSentenceIndex = 0 // Reset if past the end
                          playbackManager.currentRepetition = 1
                     }
                    playbackManager.startTeacherMode(ttsManager: ttsManager, settings: settings)
                } else {
                    showUpgradePrompt = true
                }
            }
        }
    }

    private func handleRestart() {
        #if DEBUG
        print("SpeechTabView: Restart button tapped, mode = \(settings.playbackMode.rawValue)")
        #endif
        playbackManager.stopPlayback() // Stop any current playback first
        ttsManager.stopSpeaking()
         playbackManager.currentSentenceIndex = 0 // Always reset index on restart
         playbackManager.currentRepetition = 1 // Reset repetition too

        switch settings.playbackMode {
        case .wholePassage:
            // Start from beginning
            let text = settings.processTextForSpeech(playbackManager.sentences.joined(separator: " "))
            playbackManager.isPlaying = true
            ttsManager.speak(text: text, language: settings.audioLanguage, rate: settings.playbackSpeed)

        case .sentenceBySentence:
             // Play the first sentence
            if let sentence = playbackManager.getCurrentSentence() {
                playbackManager.isPlaying = true
                ttsManager.speak(text: settings.processTextForSpeech(sentence), language: settings.audioLanguage, rate: settings.playbackSpeed)
            } else {
                 ttsManager.error = "No sentences to restart."
            }

        case .teacherMode:
            // Start teacher mode from the beginning
             if subscriptionManager.isPremium {
                 playbackManager.startTeacherMode(ttsManager: ttsManager, settings: settings)
             } else {
                 showUpgradePrompt = true
             }
        }
    }

    private func handlePrevious() {
         #if DEBUG
         print("SpeechTabView: Previous button tapped")
         #endif
         playbackManager.stopPlayback() // Stop current before moving
         ttsManager.stopSpeaking()
        if let sentence = playbackManager.previousSentence() {
            playbackManager.isPlaying = true
            ttsManager.speak(
                text: settings.processTextForSpeech(sentence),
                language: settings.audioLanguage,
                rate: settings.playbackSpeed
            )
        }
         // If previousSentence returns nil, it means it wrapped around or list is empty
    }

    private func handleNext() {
         #if DEBUG
         print("SpeechTabView: Next button tapped")
         #endif
         playbackManager.stopPlayback() // Stop current before moving
         ttsManager.stopSpeaking()
        if let sentence = playbackManager.nextSentence() {
            playbackManager.isPlaying = true
            ttsManager.speak(
                text: settings.processTextForSpeech(sentence),
                language: settings.audioLanguage,
                rate: settings.playbackSpeed
            )
        }
         // If nextSentence returns nil, it means it reached the end (in Teacher mode) or wrapped around
    }

    // --- End Action Handlers ---


    private var progressTextSection: some View {
        Group { // Wrap the conditional logic in a Group
            // Only show progress if sentences exist
            if !playbackManager.sentences.isEmpty {
                Text(playbackManager.getProgressText())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 5) // Add a little space above
            } else {
                 EmptyView() // Don't show if no sentences
            }
        }
    }

    private var voiceAvailabilityWarningSection: some View {
        VStack(spacing: 8) {
            if !ttsManager.isVoiceAvailable(for: settings.audioLanguage) {
                Text("Please download the \(settings.audioLanguage.rawValue) voice in Settings > Accessibility > Spoken Content > Voices\n請在設置 > 輔助功能 > 語音內容 > 語音中下載\(settings.audioLanguage.rawValue)語音")
                    .font(.caption) // Make it slightly smaller
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text("Ensure silent mode is off to hear playback.\n請確保靜音模式已關閉以聽到播放。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom) // Add padding below warnings
    }

    private var bannerAdSection: some View {
        // Place the ad at the bottom
         VStack {
             Spacer() // Push ad to bottom within its section
             if isFreeUser {
                 BannerAdContainer()
                     .frame(height: 50)
                     .frame(maxWidth: .infinity)
             }
         }
         .frame(maxHeight: isFreeUser ? 50 : 0) // Only take space if ad is shown
    }

    // Highlight logic remains the same
    private func shouldHighlightSentence(index: Int) -> Bool {
        // Highlight only if playing and in sentence/teacher mode
        guard playbackManager.isPlaying else { return false }
        guard settings.playbackMode != .wholePassage else { return false }
        // Use the current index from PlaybackManager
        return index == playbackManager.currentSentenceIndex
    }
}

#Preview {
    // Setup Environment Objects for Preview
    let settings = SettingsModel()
    let tts = TTSManager.shared
    let playback = PlaybackManager()
    let subs = SubscriptionManager.shared
    // Add sample text for previewing playback controls
    settings.extractedText = "This is the first sentence.\nThis is the second sentence for testing the preview.\n這是第三句。"
    playback.setSentences(settings.extractedText) // Initialize playback manager

    return SpeechTabView()
        .environmentObject(settings)
        .environmentObject(tts)
        .environmentObject(playback)
        .environmentObject(subs)
}
