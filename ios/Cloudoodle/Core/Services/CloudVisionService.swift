import Vision
import UIKit
import CoreImage

// On-device Vision passes that ground Gemini in the actual photo:
//   • Saliency — finds where the eye goes, used for label placement.
//   • Cloud-edge waypoints — extracts a sampled silhouette of the most
//     prominent cloud cluster so Gemini snaps its strokes to real
//     cloud edges instead of inventing coordinates.
//
// Both run on-device, ~100ms total on an iPhone 15. The waypoint pass
// is the heavier-handed grounding mechanism described as "follow-up B"
// in the prompt-engineering work; the prompt-only version is "A".
actor CloudVisionService {
    static let shared = CloudVisionService()

    struct Result {
        let salientRegion: CGRect  // normalized 0-1, may be .null if nothing found
        let waypoints: [[Double]]  // sampled cloud-edge points, normalized 0-1, top-left origin
        // Kept for interface compatibility; always empty — Gemini provides drawing paths now
        let drawingElements: [CloudAnalysis.DrawingElement]
    }

    func analyzeCloudImage(_ image: UIImage) async throws -> Result {
        guard let cgImage = image.cgImage else {
            return Result(salientRegion: .null, waypoints: [], drawingElements: [])
        }
        // Saliency + contour run in parallel — both are pure on-device
        // Vision passes and don't block each other on any shared state.
        async let salient = findSalientRegion(cgImage: cgImage)
        async let waypoints = extractCloudWaypoints(cgImage: cgImage)
        return Result(
            salientRegion: await salient,
            waypoints: await waypoints,
            drawingElements: []
        )
    }

    // MARK: - Saliency: where does the eye go?

    private func findSalientRegion(cgImage: CGImage) async -> CGRect {
        await withCheckedContinuation { cont in
            // Guard against double-resume: VNImageRequestHandler.perform might
            // throw (low memory, malformed image), in which case the request's
            // completion handler never fires. Without the explicit catch on
            // perform, the continuation would never resume and the async task
            // would hang indefinitely.
            var hasResumed = false
            func resumeOnce(with value: CGRect) {
                guard !hasResumed else { return }
                hasResumed = true
                cont.resume(returning: value)
            }

            let request = VNGenerateAttentionBasedSaliencyImageRequest { req, _ in
                guard
                    let obs = req.results?.first as? VNSaliencyImageObservation,
                    let objects = obs.salientObjects, !objects.isEmpty
                else {
                    resumeOnce(with: .null)
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
                resumeOnce(with: union)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(with: .null)
            }
        }
    }

    // MARK: - Cloud-edge waypoint extraction

    /// Extract a sampled silhouette of the brightest cloud cluster in
    /// the photo as ~18 normalized waypoints. We pass these into the
    /// Gemini prompt as "anchor points your strokes must follow," so
    /// the model commits to tracing the real cloud edge instead of
    /// inventing coordinates that land in empty blue sky.
    ///
    /// Pipeline:
    ///   1. Preprocess via CoreImage — strip saturation, push contrast,
    ///      then clamp so anything dim enough to be sky goes black and
    ///      anything bright enough to be cloud stays white.
    ///   2. VNDetectContoursRequest on the binarized image.
    ///   3. Pick the contour with the largest bounding-box area —
    ///      the most prominent cloud cluster, not noise from haze.
    ///   4. Sample ~18 evenly-indexed points along the contour.
    ///   5. Flip Y to SwiftUI's top-left origin.
    ///
    /// Returns an empty array on any failure; Gemini falls back to
    /// prompt-only grounding (still better than 1.0-temperature wild
    /// invention) when waypoints are absent.
    private func extractCloudWaypoints(cgImage: CGImage) async -> [[Double]] {
        guard let preprocessed = preprocessForContours(cgImage) else {
            return []
        }
        return await withCheckedContinuation { cont in
            var hasResumed = false
            func resumeOnce(with value: [[Double]]) {
                guard !hasResumed else { return }
                hasResumed = true
                cont.resume(returning: value)
            }

            let request = VNDetectContoursRequest { req, _ in
                guard let obs = req.results?.first as? VNContoursObservation else {
                    resumeOnce(with: [])
                    return
                }
                // Collect top-level contours (outermost shapes) and pick
                // the one with the biggest bounding-box area. pointCount
                // is a poor proxy — a wispy cirrus could have lots of
                // points but a tiny footprint.
                var biggest: VNContour?
                var biggestArea: Float = 0
                for c in obs.topLevelContours {
                    let pts = c.normalizedPoints
                    guard !pts.isEmpty else { continue }
                    var minX: Float = 1, minY: Float = 1, maxX: Float = 0, maxY: Float = 0
                    for p in pts {
                        minX = min(minX, p.x); maxX = max(maxX, p.x)
                        minY = min(minY, p.y); maxY = max(maxY, p.y)
                    }
                    let area = (maxX - minX) * (maxY - minY)
                    if area > biggestArea {
                        biggestArea = area
                        biggest = c
                    }
                }
                guard let chosen = biggest else {
                    resumeOnce(with: [])
                    return
                }
                // Reject very small contours — anything covering less
                // than 1% of the image area is noise from haze /
                // compression artifacts, not a real cloud.
                guard biggestArea > 0.01 else {
                    resumeOnce(with: [])
                    return
                }
                let sampled = Self.sampleEvenly(chosen.normalizedPoints, target: 18)
                // VNContour points are in Vision's bottom-left origin —
                // flip Y so they line up with SwiftUI / Gemini's
                // expected top-left coordinate system.
                let flipped: [[Double]] = sampled.map {
                    [Double($0.x), 1.0 - Double($0.y)]
                }
                resumeOnce(with: flipped)
            }
            // We're looking for bright cloud silhouettes on a dimmer
            // background after preprocessing. detectsDarkOnLight=false
            // tells Vision to treat *light* regions as the foreground.
            request.detectsDarkOnLight = false
            request.contrastAdjustment = 2.0
            request.maximumImageDimension = 512   // plenty for silhouette extraction; saves ~30ms

            let handler = VNImageRequestHandler(cgImage: preprocessed, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(with: [])
            }
        }
    }

    /// Binarize the photo so contour detection sees clean cloud
    /// silhouettes instead of soft cumulus gradients. CIColorClamp
    /// is the lightweight trick: anything below the threshold gets
    /// pulled down to black, anything above stays bright.
    nonisolated private func preprocessForContours(_ cgImage: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])

        // Strip saturation + push contrast so cloud edges resolve.
        let gray = ci.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.6,
            kCIInputBrightnessKey: 0.0
        ])

        // Threshold: clamp anything below 0.55 luminance down to 0.55.
        // Combined with the contrast boost above, this pushes blue sky
        // toward black after the next stage and keeps clouds bright.
        let clamped = gray.applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0.55, y: 0.55, z: 0.55, w: 0.0),
            "inputMaxComponents": CIVector(x: 1.0,  y: 1.0,  z: 1.0,  w: 1.0)
        ])

        // Final hard-stretch to push clamped midtones to true white
        // and the rest to black — gives VNDetectContoursRequest a
        // crisp binary image to work with.
        let stretched = clamped.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 4.0,
            kCIInputBrightnessKey: -0.2
        ])

        return context.createCGImage(stretched, from: stretched.extent)
    }

    /// Sample N evenly-indexed points along the contour. We do
    /// uniform-index sampling rather than arc-length sampling — the
    /// downstream Gemini doesn't need geodesic accuracy; the model
    /// just needs enough waypoints to know where the cloud edge is.
    nonisolated private static func sampleEvenly(_ points: [simd_float2], target: Int) -> [simd_float2] {
        guard points.count > target else { return points }
        var out: [simd_float2] = []
        out.reserveCapacity(target)
        for i in 0..<target {
            let idx = (i * points.count) / target
            out.append(points[idx])
        }
        return out
    }
}
