import Foundation
import AVFoundation
import SwiftUI

@MainActor
class TTSManager: NSObject, ObservableObject, TTSManagerProtocol {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isPlaying: Bool = false
    @Published var error: String?
    var onSpeechCompletion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, language: AudioLanguage, rate: Double) {
        guard !text.isEmpty else {
            error = "No text to speak 沒有文字可朗讀"
            #if DEBUG
            print("TTSManager.speak: Error - Empty text")
            #endif
            return
        }

        // Log available voices for debugging
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        #if DEBUG
        print("TTSManager.speak: Available voices: \(availableVoices.map { $0.language })")
        #endif

        // Try the requested language first
        var selectedVoice = AVSpeechSynthesisVoice(language: language.voiceIdentifier)
        
        // Fallback to default voice if the selected one is unavailable
        if selectedVoice == nil {
            selectedVoice = AVSpeechSynthesisVoice(language: "en-US") // Fallback to English
            error = "Voice for \(language.rawValue) not available, using default (en-US). 請下載\(language.rawValue)語音"
            #if DEBUG
            print("TTSManager.speak: Warning - Voice for \(language.voiceIdentifier) not found, falling back to en-US")
            #endif
        }

        guard let voice = selectedVoice else {
            error = "No speech voices available. Please check Settings > Accessibility > Spoken Content > Voices 無可用語音，請檢查設置"
            #if DEBUG
            print("TTSManager.speak: Error - No voices available")
            #endif
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Float(rate) * AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        #if DEBUG
        print("TTSManager.speak: Speaking '\(text)' in \(language.rawValue) at rate \(rate)")
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
        synthesizer.continueSpeaking()
        isPlaying = true
        #if DEBUG
        print("TTSManager.continueSpeaking: Continued")
        #endif
    }

    // New method to check voice availability
    func isVoiceAvailable(for language: AudioLanguage) -> Bool {
        return AVSpeechSynthesisVoice(language: language.voiceIdentifier) != nil
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
}
