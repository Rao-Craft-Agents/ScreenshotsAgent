import CoreGraphics
import Foundation
import ImageIO
import Vision

/// The words on a screenshot, read by Vision: how a test checks what a screen shows without a person looking.
enum ScreenText {
    /// The lines of text on `png`, each with how far down it sits (0 the top, 1 the bottom).
    static func lines(_ png: Data) throws -> [(text: String, top: Double)] {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { ($0.string, 1 - Double(observation.boundingBox.maxY)) }
        }
    }
}
