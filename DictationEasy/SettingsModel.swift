import SwiftUI
import AVFoundation

// String extension for sentence splitting (unchanged)
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

                if let nextNonWhitespace = characters.unicodeScalars.firstIndex(where: { !CharacterSet.whitespacesAndNewlines.contains($0) }) {
                    let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedSentence.isEmpty {
                        sentences.append(trimmedSentence)
                    }
                    currentSentence = ""
                    characters = characters[nextNonWhitespace...]
                } else {
                    currentSentence += String(characters)
                    characters = Substring()
                    let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedSentence.isEmpty {
                        sentences.append(trimmedSentence)
                    }
                    currentSentence = ""
                }
            } else {
                currentSentence += String(characters)
                characters = Substring()
                let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSentence.isEmpty {
                    sentences.append(trimmedSentence)
                }
                currentSentence = ""
            }
        }

        let finalTrimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalTrimmed.isEmpty {
            sentences.append(finalTrimmed)
        }

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
        case .english: return "en-US"
        case .mandarin: return "zh-CN"
        case .cantonese: return "zh-HK"
        }
    }
}

struct DictationEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let text: String

    init(id: UUID = UUID(), date: Date = Date(), text: String) {
        self.id = id
        self.date = date
        self.text = text
    }

    // Equatable conformance
    static func == (lhs: DictationEntry, rhs: DictationEntry) -> Bool {
        return lhs.id == rhs.id &&
               lhs.date == rhs.date &&
               lhs.text == rhs.text
    }
}

@MainActor
class SettingsModel: ObservableObject {
    @Published var playbackMode: PlaybackMode = .wholePassage
    @Published var audioLanguage: AudioLanguage = .english
    @Published var playbackSpeed: Double = 1.0
    @Published var pauseDuration: Int = 5
    @Published var repetitions: Int = 2
    @Published var showText: Bool = true
    @Published var includePunctuation: Bool = false
    @Published var extractedText: String = ""
    @Published var pastDictations: [DictationEntry] = []
    @Published var editingDictationId: UUID?
    @Published var error: String?
    @Published var fontSize: CGFloat = 16 {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: fontSizeKey)
        }
    }

    private let pastDictationsFileURL: URL = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent(Bundle.main.bundleIdentifier ?? "DictationEasy")
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        return appSupportURL.appendingPathComponent("pastDictations.json")
    }()
    private let fontSizeKey = "FontSize"
    private static var hasLoadedDictations = false // Static flag for single load

    init() {
        self.fontSize = UserDefaults.standard.object(forKey: fontSizeKey) as? CGFloat ?? 16
        print("SettingsModel: Initialized, pastDictationsFileURL: \(pastDictationsFileURL)")
    }

    func loadPastDictationsIfNeeded() {
        guard !SettingsModel.hasLoadedDictations else {
            print("SettingsModel: Past dictations already loaded, skipping")
            return
        }
        SettingsModel.hasLoadedDictations = true
        print("SettingsModel: loadPastDictationsIfNeeded executing")
        loadPastDictations()
    }

    private func loadPastDictations() {
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
            self.pastDictations = []
        }
    }

    func isSelectedVoiceAvailable() -> Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.contains { $0.language == audioLanguage.voiceIdentifier }
    }

    func processTextForSpeech(_ text: String) -> String {
        guard includePunctuation else {
            let regex = try! NSRegularExpression(pattern: "[.!?。！？「」、⋯⋯,，:：;；]")
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }

        var processedText = text
        let punctuationMappings: [(pattern: String, replacement: String)] = {
            switch audioLanguage {
            case .english:
                return [
                    ("\\.", " full stop "),
                    ("!", " exclamation mark "),
                    ("\\?", " question mark "),
                    (",", " comma "),
                    (":", " colon "),
                    (";", " semicolon ")
                ]
            case .mandarin, .cantonese:
                return [
                    ("。", " 句號 "),
                    ("！", " 感嘆號 "),
                    ("？", " 問號 "),
                    ("，", " 逗號 "),
                    ("：", " 冒號 "),
                    ("；", " 分號 "),
                    ("、", " 頓號 "),
                    ("「", " 開引號 "),
                    ("」", " 閉引號 "),
                    ("⋯⋯", " 省略號 ")
                ]
            }
        }()

        for mapping in punctuationMappings {
            if let regex = try? NSRegularExpression(pattern: mapping.pattern) {
                let range = NSRange(processedText.startIndex..., in: processedText)
                processedText = regex.stringByReplacingMatches(in: processedText, options: [], range: range, withTemplate: mapping.replacement)
            }
        }

        return processedText.trimmingCharacters(in: .whitespaces)
    }

    func savePastDictation(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        #if DEBUG
        print("SettingsModel.savePastDictation - Current editingDictationId: \(String(describing: editingDictationId))")
        #endif

        if let editingId = editingDictationId {
            #if DEBUG
            print("SettingsModel.savePastDictation - Removing original entry with id: \(editingId)")
            #endif
            deletePastDictation(id: editingId, shouldWriteToFile: false)
        }

        let entry = DictationEntry(text: trimmedText)
        pastDictations.insert(entry, at: 0)

        writePastDictationsToFile()

        #if DEBUG
        print("SettingsModel.savePastDictation - Saved new/updated entry with id: \(entry.id)")
        #endif

        editingDictationId = nil

        #if DEBUG
        print("SettingsModel.savePastDictation - Cleared editingDictationId")
        #endif
    }

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
        writePastDictationsToFile()
        editingDictationId = nil
    }

    private func writePastDictationsToFile() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(pastDictations)
            try data.write(to: pastDictationsFileURL, options: [.atomic, .completeFileProtection])
            print("Successfully wrote \(pastDictations.count) past dictations to file.")
        } catch {
            print("Failed to write past dictations to file: \(error)")
            self.error = "Failed to save dictations: \(error.localizedDescription)"
        }
    }
}
