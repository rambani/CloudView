import Vision
import UIKit
import CoreImage

// On-device Vision contour detection — the single piece of cloud
// analysis Cloudoodle still does client-side. The output (a ranked
// list of CandidateRegion) feeds SmartCrop, which picks a tight
// square around the most "creature-like" cloud cluster before we
// send it to the server-side AI proxy. The saliency + waypoint
// extraction that used to live here is gone with the Gemini-direct
// path it grounded.
actor CloudVisionService {
    static let shared = CloudVisionService()

    /// A single candidate cloud region found by contour detection,
    /// scored by how "creature-like" its silhouette looks.
    struct CandidateRegion {
        /// ~18 evenly-sampled points along the silhouette,
        /// normalized to 0–1 in the photo, top-left origin.
        let waypoints: [[Double]]
        /// Normalized 0–1 in the photo.
        let boundingBox: CGRect
        /// 4π·area / perimeter². 1.0 for a perfect circle, lower for
        /// elongated shapes. Mid-range (0.4–0.8) is most "creature-like."
        let compactness: Double
        /// Composite score: prefers medium-size + medium-compactness
        /// regions. Higher is better.
        let score: Double
    }

    /// Find UP TO `topK` candidate cloud regions that look like
    /// containable shapes — not the whole sky, not noise. Sorted by
    /// score descending. Empty when nothing usable is found.
    ///
    /// This replaces the older "find the single largest contour"
    /// behavior. Real cloud-watching is "I see a fish in THAT puff",
    /// not "the entire frame is a fish" — so we extract multiple
    /// candidates and rank by shape-likeness, letting the upstream
    /// flow pick which one to draw on.
    func findCandidateRegions(in image: UIImage, topK: Int = 3) async -> [CandidateRegion] {
        guard let cg = image.cgImage,
              let preprocessed = preprocessForContours(cg)
        else { return [] }
        return await contourCandidates(cgImage: preprocessed, topK: topK)
    }

    /// Score every contour in the image and return the top K. Scoring
    /// favors medium-sized + medium-compact silhouettes — the kind of
    /// "I can see a creature in that puff" cloud, not "the entire
    /// sky is white." Thrown errors and empty contour sets return [].
    private func contourCandidates(
        cgImage: CGImage,
        topK: Int
    ) async -> [CandidateRegion] {
        return await withCheckedContinuation { cont in
            var hasResumed = false
            func resumeOnce(with value: [CandidateRegion]) {
                guard !hasResumed else { return }
                hasResumed = true
                cont.resume(returning: value)
            }

            let request = VNDetectContoursRequest { req, _ in
                guard let obs = req.results?.first as? VNContoursObservation else {
                    resumeOnce(with: [])
                    return
                }
                var scored: [CandidateRegion] = []
                for c in obs.topLevelContours {
                    let pts = c.normalizedPoints
                    guard pts.count >= 6 else { continue }
                    // Bounding box of this contour (Vision origin, will flip below)
                    var minX: Float = 1, minY: Float = 1, maxX: Float = 0, maxY: Float = 0
                    for p in pts {
                        minX = min(minX, p.x); maxX = max(maxX, p.x)
                        minY = min(minY, p.y); maxY = max(maxY, p.y)
                    }
                    let bboxArea = Double((maxX - minX) * (maxY - minY))
                    // Reject too-small (noise/haze) and too-large
                    // (the whole sky filling the frame).
                    guard bboxArea > 0.01, bboxArea < 0.40 else { continue }
                    // Compactness = 4π·area / perimeter². Use bbox area
                    // as a stand-in for true polygon area to avoid a
                    // shoelace pass on every contour.
                    let perim = Self.contourPerimeter(pts)
                    let compactness = perim > 0
                        ? min(1.0, 4 * .pi * bboxArea / (Double(perim) * Double(perim)))
                        : 0
                    // Size sweet-spot: ~10% of image area is ideal;
                    // taper off above 30% or below 3%.
                    let sizeScore = Self.bell(value: bboxArea, peak: 0.10, width: 0.12)
                    // Compactness sweet-spot: 0.5–0.8 (creature-like
                    // but not perfectly circular).
                    let compactnessScore = Self.bell(value: compactness, peak: 0.65, width: 0.30)
                    let score = sizeScore * 0.55 + compactnessScore * 0.45
                    // Sample + flip Y to SwiftUI's top-left origin
                    let sampled = Self.sampleEvenly(pts, target: 18)
                    let flipped: [[Double]] = sampled.map {
                        [Double($0.x), 1.0 - Double($0.y)]
                    }
                    let flippedBox = CGRect(
                        x: CGFloat(minX),
                        y: CGFloat(1.0 - maxY),
                        width: CGFloat(maxX - minX),
                        height: CGFloat(maxY - minY)
                    )
                    scored.append(CandidateRegion(
                        waypoints: flipped,
                        boundingBox: flippedBox,
                        compactness: compactness,
                        score: score
                    ))
                }
                scored.sort { $0.score > $1.score }
                resumeOnce(with: Array(scored.prefix(topK)))
            }
            request.detectsDarkOnLight = false
            request.contrastAdjustment = 2.0
            request.maximumImageDimension = 512

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(with: [])
            }
        }
    }

    /// Smooth bell-curve scorer — peaks at `peak`, falls off with
    /// width `width`. Used so that "halfway-good" values still get
    /// some credit instead of dropping to zero.
    nonisolated private static func bell(value: Double, peak: Double, width: Double) -> Double {
        let d = (value - peak) / max(0.001, width)
        return exp(-d * d)
    }

    /// Approximate contour perimeter in normalized 0-1 coords.
    nonisolated private static func contourPerimeter(_ pts: [simd_float2]) -> Float {
        guard pts.count > 1 else { return 0 }
        var sum: Float = 0
        for i in 0..<(pts.count - 1) {
            let dx = pts[i+1].x - pts[i].x
            let dy = pts[i+1].y - pts[i].y
            sum += sqrt(dx * dx + dy * dy)
        }
        // close the loop
        let dx = pts[0].x - pts[pts.count - 1].x
        let dy = pts[0].y - pts[pts.count - 1].y
        sum += sqrt(dx * dx + dy * dy)
        return sum
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
