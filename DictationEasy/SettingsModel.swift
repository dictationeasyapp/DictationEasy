import SwiftUI
import AVFoundation

// String extension for sentence splitting (No changes needed here)
extension String {
    func splitIntoSentences() -> [String] {
        let punctuationSet = CharacterSet(charactersIn: ".!?。！？")
        var sentences: [String] = []
        var currentSentence = ""
        var characters = self[...]

        while !characters.isEmpty {
            if let range = characters.unicodeScalars.firstIndex(where: { punctuationSet.contains($0) }) {
                let endIndex = characters.index(after: range)
                currentSentence += String(characters[..<endIndex])
                characters = characters[endIndex...]

                // Try to find the start of the next non-whitespace character
                if let nextNonWhitespace = characters.unicodeScalars.firstIndex(where: { !CharacterSet.whitespacesAndNewlines.contains($0) }) {
                    // Append the current sentence (trimmed) if it's not empty
                     let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                     if !trimmedSentence.isEmpty {
                         sentences.append(trimmedSentence)
                     }
                     currentSentence = ""
                     characters = characters[nextNonWhitespace...] // Start next sentence from non-whitespace
                } else {
                    // End of string after punctuation, add remaining whitespace if needed (or trim)
                    currentSentence += String(characters)
                    characters = Substring() // Clear remaining characters
                     let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                     if !trimmedSentence.isEmpty {
                         sentences.append(trimmedSentence)
                     }
                     currentSentence = "" // Reset for safety
                }
            } else {
                // No more punctuation; the remaining text is the last part
                currentSentence += String(characters)
                characters = Substring() // Clear remaining characters
                 let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                 if !trimmedSentence.isEmpty {
                     sentences.append(trimmedSentence)
                 }
                 currentSentence = "" // Reset for safety
            }
        }

        // Final check for any remaining non-empty sentence
        let finalTrimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalTrimmed.isEmpty {
            sentences.append(finalTrimmed)
        }

        // Filter out truly empty sentences that might sneak through
        return sentences.filter { !$0.isEmpty }
    }
}


enum PlaybackMode: String, CaseIterable {
    case wholePassage = "Whole Passage 整段"
    case sentenceBySentence = "Sentence by Sentence 逐句"
    case teacherMode = "Teacher Mode 老師模式"
}

enum AudioLanguage: String, CaseIterable {
    case english = "English 英語"
    case mandarin = "Mandarin 普通話"
    case cantonese = "Cantonese 廣東話"

    var voiceIdentifier: String {
        switch self {
        case .english:
            return "en-US"
        case .mandarin:
            return "zh-CN" // Standard Mandarin
        case .cantonese:
            return "zh-HK" // Standard Cantonese
        }
    }
}

struct DictationEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String

    init(id: UUID = UUID(), date: Date = Date(), text: String) {
        self.id = id
        self.date = date
        self.text = text
    }
}

@MainActor
class SettingsModel: ObservableObject {
    @Published var playbackMode: PlaybackMode = .wholePassage
    @Published var audioLanguage: AudioLanguage = .english
    @Published var playbackSpeed: Double = 1.0 // Ensure this is within 0.0 to 1.0 range if needed by TTS
    @Published var pauseDuration: Int = 5
    @Published var repetitions: Int = 2
    @Published var showText: Bool = true
    @Published var includePunctuation: Bool = false
    @Published var extractedText: String = "" {
        didSet {
            // No need to call updateSentences explicitly here,
            // PlaybackManager calls setSentences which uses the extension
            // updateSentences()
        }
    }
   // @Published var sentences: [String] = [] // Removed, PlaybackManager handles sentence splitting
    @Published var pastDictations: [DictationEntry] = []
    @Published var editingDictationId: UUID? = nil
    @Published var error: String?

    @Published var fontSize: CGFloat = 16 {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: fontSizeKey)
        }
    }

    private let pastDictationsFileURL: URL = {
        // Use Application Support directory for potentially larger data
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent(Bundle.main.bundleIdentifier ?? "DictationEasy")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)

        return appSupportURL.appendingPathComponent("pastDictations.json")
    }()

    private let fontSizeKey = "FontSize"

    init() {
        self.fontSize = UserDefaults.standard.object(forKey: fontSizeKey) as? CGFloat ?? 16
        loadPastDictations()
        print("Past dictations file URL: \(pastDictationsFileURL)")
    }

//    // Removed updateSentences as PlaybackManager handles it now
//    private func updateSentences() {
//        let paragraphs = extractedText.components(separatedBy: .newlines)
//            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
//            .filter { !$0.isEmpty }
//
//        sentences = paragraphs.flatMap { $0.splitIntoSentences() }
//    }

    func isSelectedVoiceAvailable() -> Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.contains { $0.language == audioLanguage.voiceIdentifier }
    }

    // --- UPDATED processTextForSpeech ---
    func processTextForSpeech(_ text: String) -> String {
        // Early exit if punctuation should not be included
        guard includePunctuation else {
            // Remove all specified punctuation marks using regex
            let regex = try! NSRegularExpression(pattern: "[.!?。！？「」、⋯⋯,，:：;；]")
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }

        // Proceed with replacing punctuation with spoken words
        var processedText = text
        let punctuationMappings: [(pattern: String, replacement: String)] = {
            switch audioLanguage {
            case .english:
                return [
                    ("\\.", " full stop "),    // Period
                    ("!", " exclamation mark "), // Exclamation mark
                    ("\\?", " question mark "), // Question mark
                    (",", " comma "),          // Comma
                    (":", " colon "),          // Colon
                    (";", " semicolon ")       // Semicolon
                    // Add more English punctuation if needed
                ]
            case .mandarin, .cantonese:
                // Use standard spoken forms
                return [
                    ("。", " 句號 "),         // Chinese full stop
                    ("！", " 感嘆號 "),        // Chinese exclamation mark
                    ("？", " 問號 "),         // Chinese question mark
                    ("，", " 逗號 "),         // Chinese comma
                    ("：", " 冒號 "),         // Chinese colon
                    ("；", " 分號 "),         // Chinese semicolon (ADDED)
                    ("、", " 頓號 "),         // Chinese enumeration comma (ADDED)
                    ("「", " 開引號 "),        // Opening quotation mark (ADDED)
                    ("」", " 閉引號 "),        // Closing quotation mark (ADDED - Using 閉引號 as it's more standard than 刪引號)
                    ("⋯⋯", " 省略號 ")       // Chinese ellipsis (two characters)
                    // Add more Chinese punctuation if needed
                ]
            }
        }()

        for mapping in punctuationMappings {
             // Use regex for pattern matching to handle potential special characters correctly
             if let regex = try? NSRegularExpression(pattern: mapping.pattern) {
                 let range = NSRange(processedText.startIndex..., in: processedText)
                 processedText = regex.stringByReplacingMatches(in: processedText, options: [], range: range, withTemplate: mapping.replacement)
             }
        }

        // Trim extra whitespace that might result from replacements
        return processedText.trimmingCharacters(in: .whitespaces)
    }
    // --- END UPDATED processTextForSpeech ---


    func loadPastDictations() {
        do {
             if FileManager.default.fileExists(atPath: pastDictationsFileURL.path) {
                 let data = try Data(contentsOf: pastDictationsFileURL)
                 let decoded = try JSONDecoder().decode([DictationEntry].self, from: data)
                 self.pastDictations = decoded
                 print("Loaded \(decoded.count) past dictations.")
             } else {
                 print("Past dictations file not found at \(pastDictationsFileURL.path). Starting fresh.")
                 self.pastDictations = []
             }
         } catch {
             print("Failed to load past dictations: \(error)")
             self.error = "Failed to load past entries: \(error.localizedDescription)"
             self.pastDictations = [] // Start fresh if decoding fails
         }
    }

    func savePastDictation(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        #if DEBUG
        print("SettingsModel.savePastDictation - Current editingDictationId: \(String(describing: editingDictationId))")
        #endif

        // Remove existing entry if editing
        if let editingId = editingDictationId {
            #if DEBUG
            print("SettingsModel.savePastDictation - Removing original entry with id: \(editingId)")
            #endif
            // Use the dedicated delete function to ensure consistency
            deletePastDictation(id: editingId, shouldWriteToFile: false) // Don't write yet, we'll write the full list
        }

        // Create new entry and insert at the beginning
        let entry = DictationEntry(text: trimmedText)
        pastDictations.insert(entry, at: 0)

        // Save the entire updated list
        writePastDictationsToFile()

        #if DEBUG
        print("SettingsModel.savePastDictation - Saved new/updated entry with id: \(entry.id)")
        #endif

        // Clear editing state *after* successful save
        editingDictationId = nil

        #if DEBUG
        print("SettingsModel.savePastDictation - Cleared editingDictationId")
        #endif
    }

    // Modified delete function to control file writing
     func deletePastDictation(id: UUID, shouldWriteToFile: Bool = true) {
         let initialCount = pastDictations.count
         pastDictations.removeAll { $0.id == id }
         let removedCount = initialCount - pastDictations.count
         print("Deleted \(removedCount) entry(ies) with ID: \(id)")

         if shouldWriteToFile {
             writePastDictationsToFile()
         }
     }

    func deleteAllPastDictations() {
        #if DEBUG
        print("SettingsModel.deleteAllPastDictations - Deleting all past dictations")
        #endif

        pastDictations = []
        writePastDictationsToFile() // Save the empty array

        // Clear any editing state
        editingDictationId = nil
    }

    // Helper function to write the current pastDictations array to file
    private func writePastDictationsToFile() {
         do {
             let encoder = JSONEncoder()
             encoder.outputFormatting = .prettyPrinted // Makes JSON file readable for debugging
             let data = try encoder.encode(pastDictations)
             try data.write(to: pastDictationsFileURL, options: [.atomic, .completeFileProtection])
             print("Successfully wrote \(pastDictations.count) past dictations to file.")
         } catch {
             print("Failed to write past dictations to file: \(error)")
             self.error = "Failed to save dictations: \(error.localizedDescription)"
         }
     }
}
