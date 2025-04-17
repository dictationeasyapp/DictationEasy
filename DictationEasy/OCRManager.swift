import SwiftUI
import Vision
#if os(iOS)
import UIKit
#endif

@MainActor
class OCRManager: ObservableObject {
    enum OCRError: Error {
        case invalidImage
        case recognitionFailed
    }

    @Published var extractedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var error: String?
    @Published var hasNewOCRResult: Bool = false

    // Updated to accept ScanLanguage instead of AudioLanguage
    func processImage(_ image: UIImage, scanLanguage: ScanTabView.ScanLanguage) async throws {
        // Reset state on the main thread
        isProcessing = true
        error = nil
        extractedText = ""
        hasNewOCRResult = false

        // Resize the image to improve OCR performance
        let resizedImage = resizeImage(image, toMaxDimension: 1500) ?? image

        guard let cgImage = resizedImage.cgImage else {
            Task { @MainActor in
                self.error = "Failed to process image 無法處理圖片"
                self.isProcessing = false
            }
            throw OCRError.invalidImage
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.error = "OCR failed: \(error.localizedDescription) 文字識別失敗"
                    self.isProcessing = false
                    self.extractedText = ""
                    self.hasNewOCRResult = false
                    #if DEBUG
                    print("OCRManager: Error during OCR - \(error.localizedDescription)")
                    #endif
                }
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                Task { @MainActor in
                    self.error = "No text found in image 圖片中未找到文字"
                    self.isProcessing = false
                    self.extractedText = "No text detected. 沒有檢測到文字。"
                    self.hasNewOCRResult = true
                    #if DEBUG
                    print("OCRManager: No text observations found")
                    #endif
                }
                return
            }

            // Log raw observations for debugging
            #if DEBUG
            print("OCRManager: Raw observations - \(observations.count) detected")
            for (index, observation) in observations.enumerated() {
                if let text = observation.topCandidates(1).first?.string {
                    print("OCRManager: Observation \(index): \(text)")
                }
            }
            #endif

            // --- MODIFIED: Join observations with newline first, then clean ---
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n") // Use newline from observations directly

            Task { @MainActor in
                // Clean the text, preserving original punctuation where possible
                let cleanedText = self.cleanText(recognizedText)
                self.extractedText = cleanedText.isEmpty ? "No text detected. 沒有檢測到文字。" : cleanedText
                self.isProcessing = false
                self.hasNewOCRResult = true
                #if DEBUG
                print("OCRManager: Successfully extracted text - \(self.extractedText)")
                #endif
            }
        }

        // Use only the selected language for OCR
        let prioritizedLanguages = [scanLanguage.visionLanguageCode]
        #if DEBUG
        print("OCRManager: Prioritized languages - \(prioritizedLanguages)")
        #endif

        // Configure the request for better accuracy
        request.recognitionLanguages = prioritizedLanguages
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // Keep false for raw results
        request.minimumTextHeight = 0.015 // Adjust if needed

        do {
            try requestHandler.perform([request])
        } catch {
            Task { @MainActor in
                self.error = "Failed to perform OCR: \(error.localizedDescription) 無法執行文字識別"
                self.isProcessing = false
                self.extractedText = ""
                self.hasNewOCRResult = false
                #if DEBUG
                print("OCRManager: Failed to perform request - \(error.localizedDescription)")
                #endif
            }
            throw error
        }
    }

    func updateExtractedText(_ text: String) {
        extractedText = text
        hasNewOCRResult = false
        #if DEBUG
        print("OCRManager: Updated extractedText to '\(text)'")
        #endif
    }

    // --- UPDATED cleanText function ---
    private func cleanText(_ text: String) -> String {
        // 1. Split into paragraphs (using newline as separator from OCR)
        let paragraphs = text.components(separatedBy: .newlines)

        // 2. Process each paragraph: split into sentences, trim, and filter empty
        let processedSentences = paragraphs.flatMap { paragraph -> [String] in
            // Use the existing String extension to split, preserving original punctuation
            let sentences = paragraph.splitIntoSentences()
            return sentences.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } // Trim each sentence
                           .filter { !$0.isEmpty } // Filter out empty results
        }

        // 3. Join the processed sentences back together with a single newline
        let final_text = processedSentences.joined(separator: "\n")

        #if DEBUG
        print("OCRManager.cleanText: Input length \(text.count), Output length \(final_text.count)")
        // Uncomment to see exact output: print("OCRManager.cleanText: Final cleaned text:\n\(final_text)")
        #endif

        return final_text
    }
    // --- END UPDATED cleanText function ---


    private func resizeImage(_ image: UIImage, toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Only resize if necessary
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0) // Use scale 0.0 for device scale
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
