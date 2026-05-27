import Vision
import UIKit

// On-device saliency detection — finds where the eye goes in the photo.
// Used only for label placement; drawing paths come from Gemini.
actor CloudVisionService {
    static let shared = CloudVisionService()

    struct Result {
        let salientRegion: CGRect  // normalized 0-1, may be .null if nothing found
        // Kept for interface compatibility; always empty — Gemini provides drawing paths now
        let drawingElements: [CloudAnalysis.DrawingElement]
    }

    func analyzeCloudImage(_ image: UIImage) async throws -> Result {
        guard let cgImage = image.cgImage else {
            return Result(drawingElements: [], salientRegion: .null)
        }
        let salientRegion = await findSalientRegion(cgImage: cgImage)
        return Result(drawingElements: [], salientRegion: salientRegion)
    }

    // MARK: - Saliency: where does the eye go?

    private func findSalientRegion(cgImage: CGImage) async -> CGRect {
        await withCheckedContinuation { cont in
            let request = VNGenerateAttentionBasedSaliencyImageRequest { req, _ in
                guard
                    let obs = req.results?.first as? VNSaliencyImageObservation,
                    let objects = obs.salientObjects, !objects.isEmpty
                else {
                    cont.resume(returning: .null)
                    return
                }
                // Union of all salient bounding boxes, flipping Y to SwiftUI space
                let union = objects.reduce(CGRect.null) { acc, obj in
                    let flipped = CGRect(
                        x: obj.boundingBox.origin.x,
                        y: 1.0 - obj.boundingBox.origin.y - obj.boundingBox.height,
                        width: obj.boundingBox.width,
                        height: obj.boundingBox.height
                    )
                    return acc.isNull ? flipped : acc.union(flipped)
                }
                cont.resume(returning: union)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
