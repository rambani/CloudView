import Vision
import CoreImage
import ARKit
import UIKit

/// One candidate cloud. All coordinates are in the **upright image** (the
/// portrait view the user sees), not the landscape capture buffer — see
/// `CameraFrameGeometry`. `size`/`boundingBox`/`screenPosition` are upright
/// pixels; `normalizedContour` is 0–1 within the bounding box, y-down.
struct CloudShape {
    let center: simd_float3
    let boundingBox: CGRect
    let screenPosition: CGPoint
    let size: CGSize
    let aspectRatio: Float
    let area: Float
    let contourPoints: [CGPoint] // ACTUAL cloud outline points (upright pixels)
    let normalizedContour: [CGPoint] // Normalized to 0-1 space for drawing
    /// Top of the bright mass (upright pixels), known for lobes from the
    /// splitter; nil for plain Vision contours. Where a companion stands.
    var summit: CGPoint? = nil

    var shapeCategory: ShapeCategory {
        if aspectRatio > 2.0 {
            return .elongated
        } else if aspectRatio > 1.3 {
            return .wide
        } else if aspectRatio < 0.7 {
            return .tall
        } else {
            return .round
        }
    }

    enum ShapeCategory {
        case round
        case elongated
        case wide
        case tall
    }
}

/// Which of several detected blobs the pipeline should act on, and which
/// to ignore. Pure, so it's unit-tested without Vision.
enum CloudCandidateSelection {
    /// A blob covering more of the frame than this is an overcast sheet (or
    /// the phone is pointed at a wall), not a cloud with a shape — there's
    /// nothing to doodle on. Dropped so the "no clouds" states can speak.
    static let maxAreaFraction: CGFloat = 0.60

    static func areaFraction(_ shape: CloudShape, imageSize: CGSize) -> CGFloat {
        let frame = imageSize.width * imageSize.height
        guard frame > 0 else { return 0 }
        return (shape.size.width * shape.size.height) / frame
    }

    /// Bigger is better, but a cloud near the middle of the frame — the one
    /// the user is actually aiming at — beats a bigger one at the edge.
    static func score(_ shape: CloudShape, imageSize: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 0 }
        let dx = (shape.screenPosition.x - imageSize.width / 2) / imageSize.width
        let dy = (shape.screenPosition.y - imageSize.height / 2) / imageSize.height
        let offCenter = (dx * dx + dy * dy).squareRoot() // 0 at center, ~0.71 at a corner
        return areaFraction(shape, imageSize: imageSize).squareRoot() / (1 + 4 * offCenter)
    }

    /// Candidates worth drawing on, best first.
    static func rank(_ shapes: [CloudShape], imageSize: CGSize) -> [CloudShape] {
        shapes
            .filter { areaFraction($0, imageSize: imageSize) <= maxAreaFraction }
            .sorted { score($0, imageSize: imageSize) > score($1, imageSize: imageSize) }
    }
}

class CloudDetector {
    private let ciContext = CIContext()

    /// How the capture buffer is turned to be upright (portrait phone).
    static let orientation = CameraFrameGeometry.uprightOrientation

    /// Contours must cover at least this fraction of the frame to count.
    static let minAreaFraction: CGFloat = 0.02
    static let maxCandidates = 5

    /// Cloud-vs-sky separation adapts to each frame: clouds are white (red
    /// channel high), blue sky is not (red channel low), so the red channel
    /// is thresholded relative to the frame's own mean. Set false to fall
    /// back to the fixed brightness/contrast boost.
    static let useAdaptiveEnhancement = true
    /// Gain around the frame mean; 3.0 maps "mean + 0.17" to full white.
    static let adaptiveGain: CGFloat = 3.0

    /// Blobs covering at least this share of the frame are split into lobes
    /// — a bank becomes head-puff + tower + body, so a companion can sit on
    /// its own cloud and the creature lands on the bulbous part.
    static let lobeSplitMinAreaFraction: CGFloat = 0.10
    static let lobeGridWidth = 256
    /// Whiteness above this is cloud (the adaptive map puts sky well below).
    static let lobeWhitenessThreshold: Float = 0.75

    /// Whiteness map of the last frame, upright, at lobe-grid resolution.
    /// Rendered lazily — only when a blob is big enough to split.
    private var lastEnhanced: CIImage?

    func detectClouds(in pixelBuffer: CVPixelBuffer) async -> [CloudShape] {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let uprightSize = CameraFrameGeometry.uprightImageSize(
            bufferSize: ciImage.extent.size,
            orientation: Self.orientation
        )

        guard let cloudContours = await detectCloudContours(in: ciImage) else {
            return []
        }

        let shapes = cloudContours.compactMap { contour in
            convertToCloudShape(contour, imageSize: uprightSize)
        }

        // Overcast sheets drop before splitting (a 70% blob is still a
        // sheet, not a bank of lobes); big banks split; the rest pass.
        var expanded: [CloudShape] = []
        var grid: GrayGrid? = nil
        for shape in shapes {
            let fraction = CloudCandidateSelection.areaFraction(shape, imageSize: uprightSize)
            if fraction > CloudCandidateSelection.maxAreaFraction { continue }
            if fraction >= Self.lobeSplitMinAreaFraction {
                if grid == nil { grid = whitenessGrid(uprightSize: uprightSize) }
                if let grid = grid {
                    let lobes = lobeShapes(of: shape, grid: grid, uprightSize: uprightSize)
                    if lobes.count >= 2 {
                        expanded.append(contentsOf: lobes)
                        continue
                    }
                }
            }
            expanded.append(shape)
        }
        return CloudCandidateSelection.rank(expanded, imageSize: uprightSize)
    }

    // MARK: - Lobe splitting

    /// The enhanced frame, turned upright and scaled to the lobe grid.
    private func whitenessGrid(uprightSize: CGSize) -> GrayGrid? {
        guard let enhanced = lastEnhanced, uprightSize.width > 0 else { return nil }
        let w = Self.lobeGridWidth
        let h = max(1, Int((uprightSize.height * CGFloat(w) / uprightSize.width).rounded()))
        let upright = enhanced.oriented(Self.orientation)
        let k = CGFloat(w) / upright.extent.width
        let scaled = upright
            .transformed(by: CGAffineTransform(scaleX: k, y: k))
            .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

        // Rows come back top-down, like a CGImage.
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        ciContext.render(
            scaled,
            toBitmap: &rgba,
            rowBytes: w * 4,
            bounds: CGRect(x: 0, y: 0, width: w, height: h),
            format: .RGBA8,
            colorSpace: nil
        )
        var pixels = [Float](repeating: 0, count: w * h)
        for i in 0..<(w * h) { pixels[i] = Float(rgba[i * 4]) / 255 }
        return GrayGrid(width: w, height: h, pixels: pixels)
    }

    /// Split a detected shape into lobe shapes (in upright pixels). Returns
    /// fewer than two when the blob doesn't visually split.
    private func lobeShapes(of shape: CloudShape, grid: GrayGrid, uprightSize: CGSize) -> [CloudShape] {
        let k = CGFloat(grid.width) / uprightSize.width
        let box = shape.boundingBox.applying(CGAffineTransform(scaleX: k, y: k))
        var mask = [Bool](repeating: false, count: grid.count)
        for y in 0..<grid.height {
            for x in 0..<grid.width {
                let i = y * grid.width + x
                if box.contains(CGPoint(x: x, y: y)) && grid.pixels[i] > Self.lobeWhitenessThreshold {
                    mask[i] = true
                }
            }
        }
        let lobes = CloudLobeSplitter.split(grid, mask: mask)
        guard lobes.count >= 2 else { return [] }

        return lobes.compactMap { lobe in
            // Grid → upright pixels (pixel centers).
            let pts = lobe.outline.map { CGPoint(x: ($0.x + 0.5) / k, y: ($0.y + 0.5) / k) }
            let summit = CGPoint(x: (lobe.summit.x + 0.5) / k, y: (lobe.summit.y + 0.5) / k)
            return Self.makeShape(contourPoints: pts, summit: summit)
        }
    }

    /// A CloudShape from an upright-pixel outline, with the same minimum
    /// size rule as the Vision path.
    static func makeShape(contourPoints: [CGPoint], summit: CGPoint? = nil) -> CloudShape? {
        guard contourPoints.count >= 3 else { return nil }
        let xs = contourPoints.map(\.x), ys = contourPoints.map(\.y)
        let rect = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        guard rect.width > 50 && rect.height > 50 else { return nil }
        let size = CGSize(width: rect.width, height: rect.height)
        let normalized = contourPoints.map {
            CGPoint(x: ($0.x - rect.minX) / rect.width, y: ($0.y - rect.minY) / rect.height)
        }
        return CloudShape(
            center: simd_float3(0, 0, 0),
            boundingBox: rect,
            screenPosition: CGPoint(x: rect.midX, y: rect.midY),
            size: size,
            aspectRatio: Float(size.width / size.height),
            area: Float(size.width * size.height),
            contourPoints: contourPoints,
            normalizedContour: normalized,
            summit: summit
        )
    }

    private func detectCloudContours(in image: CIImage) async -> [VNContoursObservation]? {
        guard let enhancedImage = enhanceCloudRegions(image) else {
            return nil
        }
        lastEnhanced = enhancedImage

        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0 // Increase contrast for better cloud detection
        request.detectsDarkOnLight = false // We want bright clouds on dark sky
        request.maximumImageDimension = 512

        // Telling Vision the buffer's orientation makes every observation
        // come back in upright coordinates — the fix for ears landing on
        // the side of a cloud because "top" meant the landscape buffer's top.
        let handler = VNImageRequestHandler(ciImage: enhancedImage, orientation: Self.orientation, options: [:])

        do {
            try handler.perform([request])
            guard let results = request.results else {
                return nil
            }

            // VNContoursObservation has no `.boundingBox` of its own — the
            // observation is a tree of contours. Compute the union bounding
            // box from its top-level contours' normalized paths, then drop
            // anything that doesn't cover the minimum share of the image.
            let significantContours = results.filter { observation in
                let box = observation.topLevelContours.reduce(CGRect.null) { acc, c in
                    acc.union(c.normalizedPath.boundingBox)
                }
                return box.width * box.height > Self.minAreaFraction
            }

            return Array(significantContours.prefix(Self.maxCandidates))
        } catch {
            print("Contour detection error: \(error)")
            return nil
        }
    }

    // MARK: - Enhancement

    private func enhanceCloudRegions(_ image: CIImage) -> CIImage? {
        if Self.useAdaptiveEnhancement, let adaptive = adaptiveWhiteness(image) {
            return adaptive
        }
        return legacyEnhance(image)
    }

    /// Grayscale "whiteness" image: the red channel, re-centered on the
    /// frame's mean red and amplified. Blue sky (R ≈ 0.3–0.5) falls to dark,
    /// cloud (R ≈ 0.85–1.0) saturates to white, whatever the exposure.
    private func adaptiveWhiteness(_ image: CIImage) -> CIImage? {
        let redOnly = CIVector(x: 1, y: 0, z: 0, w: 0)
        guard let red = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: image,
            "inputRVector": redOnly,
            "inputGVector": redOnly,
            "inputBVector": redOnly,
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ])?.outputImage else { return nil }

        guard let mean = meanRed(of: red) else { return nil }

        let k = Self.adaptiveGain
        let bias = 0.5 - k * mean
        return CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: red,
            "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0),
        ])?.outputImage
    }

    private func meanRed(of image: CIImage) -> CGFloat? {
        guard let average = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: image.extent),
        ])?.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            average,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return CGFloat(pixel[0]) / 255
    }

    /// The original fixed boost, kept as the fallback.
    private func legacyEnhance(_ image: CIImage) -> CIImage? {
        guard let brightnessFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        brightnessFilter.setValue(image, forKey: kCIInputImageKey)
        brightnessFilter.setValue(0.3, forKey: kCIInputBrightnessKey)
        brightnessFilter.setValue(1.8, forKey: kCIInputContrastKey)
        brightnessFilter.setValue(0.8, forKey: kCIInputSaturationKey)
        return brightnessFilter.outputImage
    }

    // MARK: - Observation → CloudShape

    private func convertToCloudShape(_ observation: VNContoursObservation, imageSize: CGSize) -> CloudShape? {
        // Union of every top-level contour's normalized path → bounding box.
        let boundingBox = observation.topLevelContours.reduce(CGRect.null) { acc, c in
            acc.union(c.normalizedPath.boundingBox)
        }
        guard !boundingBox.isNull else { return nil }

        // Vision returns normalized coords with origin at LOWER-left (of the
        // upright image, since the handler was given the orientation). Flip
        // Y so everything downstream is top-left, y-down pixel space.
        let rect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: (1.0 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        // Skip very small regions
        guard rect.width > 50 && rect.height > 50 else {
            return nil
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = CGSize(width: rect.width, height: rect.height)
        let aspectRatio = Float(size.width / size.height)
        let area = Float(size.width * size.height)

        let contourPoints = extractContourPoints(from: observation, imageSize: imageSize)
        let normalizedContour = normalizeContourPoints(contourPoints, relativeTo: rect)

        return CloudShape(
            center: simd_float3(0, 0, 0),
            boundingBox: rect,
            screenPosition: center,
            size: size,
            aspectRatio: aspectRatio,
            area: area,
            contourPoints: contourPoints,
            normalizedContour: normalizedContour
        )
    }

    private func extractContourPoints(from observation: VNContoursObservation, imageSize: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []

        for contour in observation.topLevelContours {
            // `normalizedPoints` is a buffer of simd_float2 in lower-left
            // normalized image space.
            let buffer = contour.normalizedPoints
            let total = buffer.count
            guard total > 0 else { continue }

            let target = min(total, 100)
            let step = max(1, total / target)

            for i in stride(from: 0, to: total, by: step) {
                let p = buffer[i]
                // Same Vision lower-left → top-left flip as the bounding box.
                let imagePoint = CGPoint(
                    x: CGFloat(p.x) * imageSize.width,
                    y: (1.0 - CGFloat(p.y)) * imageSize.height
                )
                points.append(imagePoint)
            }
        }

        return points
    }

    private func normalizeContourPoints(_ points: [CGPoint], relativeTo rect: CGRect) -> [CGPoint] {
        guard rect.width > 0, rect.height > 0 else { return [] }
        return points.map { point in
            CGPoint(
                x: (point.x - rect.minX) / rect.width,
                y: (point.y - rect.minY) / rect.height
            )
        }
    }
}
