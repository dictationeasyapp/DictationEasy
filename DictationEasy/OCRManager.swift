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
    @Published var hasNewOCRResult: Bool = false // New flag to track new OCR results

    private let supportedLanguages = ["en-US", "zh-Hant"]

    func processImage(_ image: UIImage) async throws {
        // Reset state on the main thread
        isProcessing = true
        error = nil
        extractedText = ""
        hasNewOCRResult = false // Reset flag

        // Resize the image to improve OCR performance (max 1000x1000)
        let resizedImage = resizeImage(image, toMaxDimension: 1000) ?? image

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
                    self.hasNewOCRResult = true // Flag new result
                    #if DEBUG
                    print("OCRManager: No text observations found")
                    #endif
                }
                return
            }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            Task { @MainActor in
                let cleanedText = self.cleanText(recognizedText)
                self.extractedText = cleanedText.isEmpty ? "No text detected. 沒有檢測到文字。" : cleanedText
                self.isProcessing = false
                self.hasNewOCRResult = true // Flag new result
                #if DEBUG
                print("OCRManager: Successfully extracted text - \(self.extractedText)")
                #endif
            }
        }

        // Configure the request for better accuracy
        request.recognitionLanguages = supportedLanguages
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01 // Adjust for small text detection

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

    // New method to allow TextTabView to update extractedText
    func updateExtractedText(_ text: String) {
        extractedText = text
        hasNewOCRResult = false // Not an OCR result
        #if DEBUG
        print("OCRManager: Updated extractedText to '\(text)'")
        #endif
    }

    private func cleanText(_ text: String) -> String {
        let chineseRegex = try! NSRegularExpression(pattern: "[\\u4e00-\\u9fff]+")
        let range = NSRange(text.startIndex..., in: text)
        let matches = chineseRegex.matches(in: text, range: range)

        var cleanedText = text

        // Special handling for Chinese text
        if !matches.isEmpty {
            cleanedText = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { component in
                    let componentRange = NSRange(component.startIndex..., in: component)
                    return chineseRegex.firstMatch(in: component, range: componentRange) != nil ||
                           component.rangeOfCharacter(from: .punctuationCharacters) != nil
                }
                .joined(separator: " ")
        }

        // Split by sentence-ending punctuation and clean up
        return cleanedText.components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ".\n")
    }

    private func resizeImage(_ image: UIImage, toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            // Landscape image
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait image
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Only resize if the image is larger than the max dimension
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
