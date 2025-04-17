import Foundation
import AVFoundation
import SwiftUI

@MainActor
class TTSManager: NSObject, ObservableObject, TTSManagerProtocol {
    static let shared = TTSManager() // Add a shared instance to reuse across the app

    private let synthesizer = AVSpeechSynthesizer()
    @Published var isPlaying: Bool = false
    @Published var error: String?
    var onSpeechCompletion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
        #if DEBUG
        print("TTSManager.init: Initialized")
        #endif
        // Note: The following warnings might appear in logs due to AVSpeechSynthesizer's internal use of private frameworks:
        // - NSBundle file:///System/Library/PrivateFrameworks/TextToSpeech.framework/ principal class is nil because all fallbacks have failed
        // - NSBundle file:///System/Library/PrivateFrameworks/AccessibilityUtilities.framework/ principal class is nil because all fallbacks have failed
        // These are system-level warnings and can be ignored as long as TTS functionality works. Monitor for future iOS updates.
    }

    func speak(text: String, language: AudioLanguage, rate: Double) {
        guard !text.isEmpty else {
            error = "No text to speak 沒有文字可朗讀"
            #if DEBUG
            print("TTSManager.speak: Error - Empty text")
            #endif
            return
        }

        // Validate rate
        let clampedRate = min(max(rate, 0.0), 1.0) // Ensure rate is between 0.0 and 1.0
        if rate != clampedRate {
            #if DEBUG
            print("TTSManager.speak: Warning - Rate \(rate) was out of bounds, clamped to \(clampedRate)")
            #endif
        }

        // Log available voices for debugging
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        #if DEBUG
        print("TTSManager.speak: Available voices: \(availableVoices.map { "\($0.language) (\($0.name))" })")
        #endif

        // Check if the requested language voice is available
        let selectedVoice = AVSpeechSynthesisVoice(language: language.voiceIdentifier)
        
        if selectedVoice == nil {
            // Voice not available, provide actionable error
            error = "Voice for \(language.rawValue) not available. Please go to Settings > Accessibility > Spoken Content > Voices to download it. \(language.rawValue)語音不可用，請前往設置 > 輔助功能 > 語音內容 > 語音下載"
            #if DEBUG
            print("TTSManager.speak: Error - Voice for \(language.voiceIdentifier) not found")
            #endif
            return
        }

        // Ensure at least one voice is available
        guard !availableVoices.isEmpty else {
            error = "No speech voices available. Please check Settings > Accessibility > Spoken Content > Voices to download a voice. 無可用語音，請檢查設置 > 輔助功能 > 語音內容 > 語音下載"
            #if DEBUG
            print("TTSManager.speak: Error - No voices available at all")
            #endif
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = Float(clampedRate) * AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        #if DEBUG
        print("TTSManager.speak: Speaking '\(text)' in \(language.rawValue) (\(language.voiceIdentifier)) at rate \(clampedRate)")
        #endif

        synthesizer.speak(utterance)
        isPlaying = true
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        #if DEBUG
        print("TTSManager.stopSpeaking: Stopped")
        #endif
    }

    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .immediate)
        isPlaying = false
        #if DEBUG
        print("TTSManager.pauseSpeaking: Paused")
        #endif
    }

    func continueSpeaking() {
        let success = synthesizer.continueSpeaking()
        if success {
            isPlaying = true
            #if DEBUG
            print("TTSManager.continueSpeaking: Continued")
            #endif
        } else {
            error = "Failed to continue speaking. No speech in progress. 無法繼續朗讀，沒有正在進行的語音"
            isPlaying = false
            #if DEBUG
            print("TTSManager.continueSpeaking: Failed - No speech in progress")
            #endif
        }
    }

    // Check voice availability
    func isVoiceAvailable(for language: AudioLanguage) -> Bool {
        let isAvailable = AVSpeechSynthesisVoice(language: language.voiceIdentifier) != nil
        #if DEBUG
        print("TTSManager.isVoiceAvailable: Language \(language.rawValue) (\(language.voiceIdentifier)) - Available: \(isAvailable)")
        #endif
        return isAvailable
    }
}

extension TTSManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            #if DEBUG
            print("TTSManager.delegate: Speech finished")
            #endif
            self.onSpeechCompletion?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            #if DEBUG
            print("TTSManager.delegate: Speech paused")
            #endif
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = true
            #if DEBUG
            print("TTSManager.delegate: Speech continued")
            #endif
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = true
            #if DEBUG
            print("TTSManager.delegate: Speech started")
            #endif
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            #if DEBUG
            print("TTSManager.delegate: Speech canceled")
            #endif
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        #if DEBUG
        print("TTSManager.delegate: Will speak range \(characterRange)")
        #endif
    }
}
