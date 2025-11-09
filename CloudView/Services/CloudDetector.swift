import Vision
import CoreImage
import ARKit
import UIKit

struct CloudShape {
    let center: simd_float3
    let boundingBox: CGRect
    let screenPosition: CGPoint
    let size: CGSize
    let aspectRatio: Float
    let area: Float
    let contourPoints: [CGPoint] // ACTUAL cloud outline points!
    let normalizedContour: [CGPoint] // Normalized to 0-1 space for drawing

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

class CloudDetector {
    private let ciContext = CIContext()
    private var lastDetectionTime: Date = .distantPast
    private let detectionInterval: TimeInterval = 0.5

    func detectClouds(in pixelBuffer: CVPixelBuffer) async -> [CloudShape] {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Detect bright regions and extract contours
        guard let cloudContours = await detectCloudContours(in: ciImage) else {
            return []
        }

        // Convert contours to cloud shapes
        return cloudContours.compactMap { contour in
            convertToCloudShape(contour, imageSize: ciImage.extent.size)
        }
    }

    private func detectCloudContours(in image: CIImage) async -> [VNContoursObservation]? {
        // First, enhance clouds with brightness/contrast filter
        guard let enhancedImage = enhanceCloudRegions(image) else {
            return nil
        }

        // Detect contours in the enhanced image
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0 // Increase contrast for better cloud detection
        request.detectsDarkOnLight = false // We want bright clouds on dark sky
        request.maximumImageDimension = 512

        let handler = VNImageRequestHandler(ciImage: enhancedImage, options: [:])

        do {
            try handler.perform([request])
            guard let results = request.results as? [VNContoursObservation] else {
                return nil
            }

            // Filter for significant contours (clouds, not noise)
            let significantContours = results.filter { contour in
                let area = contour.boundingBox.width * contour.boundingBox.height
                return area > 0.02 // At least 2% of image
            }

            return Array(significantContours.prefix(5))
        } catch {
            print("Contour detection error: \(error)")
            return nil
        }
    }

    private func enhanceCloudRegions(_ image: CIImage) -> CIImage? {
        // Apply filters to make clouds stand out
        guard let brightnessFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }

        brightnessFilter.setValue(image, forKey: kCIInputImageKey)
        brightnessFilter.setValue(0.3, forKey: kCIInputBrightnessKey)
        brightnessFilter.setValue(1.8, forKey: kCIInputContrastKey)
        brightnessFilter.setValue(0.8, forKey: kCIInputSaturationKey)

        return brightnessFilter.outputImage
    }

    private func convertToCloudShape(_ observation: VNContoursObservation, imageSize: CGSize) -> CloudShape? {
        let boundingBox = observation.boundingBox

        // Convert normalized coordinates to image coordinates
        let rect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: boundingBox.origin.y * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        // Skip very small regions
        guard rect.width > 50 && rect.height > 50 else {
            return nil
        }

        let center = CGPoint(
            x: rect.midX,
            y: rect.midY
        )

        let size = CGSize(
            width: rect.width,
            height: rect.height
        )

        let aspectRatio = Float(size.width / size.height)
        let area = Float(size.width * size.height)

        // Extract actual contour points from the cloud
        let contourPoints = extractContourPoints(from: observation, imageSize: imageSize)

        // Normalize contour points to 0-1 space relative to bounding box
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

        // Get the top-level contour
        let topLevelContours = observation.topLevelContours

        for contour in topLevelContours {
            // Sample points along the contour path
            let pointCount = min(contour.pointCount, 100) // Limit to 100 points for performance
            let step = max(1, contour.pointCount / pointCount)

            for i in stride(from: 0, to: contour.pointCount, by: step) {
                if let point = try? contour.point(at: i) {
                    // Convert normalized point to image coordinates
                    let imagePoint = CGPoint(
                        x: CGFloat(point.x) * imageSize.width,
                        y: CGFloat(point.y) * imageSize.height
                    )
                    points.append(imagePoint)
                }
            }
        }

        return points
    }

    private func normalizeContourPoints(_ points: [CGPoint], relativeTo rect: CGRect) -> [CGPoint] {
        // Normalize points to 0-1 space within the bounding box
        return points.map { point in
            CGPoint(
                x: (point.x - rect.minX) / rect.width,
                y: (point.y - rect.minY) / rect.height
            )
        }
    }

    // Alternative: Simple brightness-based detection (fallback)
    func detectCloudRegionsWithBrightness(in pixelBuffer: CVPixelBuffer) async -> [CloudShape] {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply brightness threshold filter
        guard let brightnessFilter = CIFilter(name: "CIColorControls") else {
            return []
        }

        brightnessFilter.setValue(ciImage, forKey: kCIInputImageKey)
        brightnessFilter.setValue(0.5, forKey: kCIInputBrightnessKey)
        brightnessFilter.setValue(2.0, forKey: kCIInputContrastKey)

        guard let outputImage = brightnessFilter.outputImage else {
            return []
        }

        // Detect contours in the filtered image
        return await detectCloudContours(in: outputImage)?.compactMap { contour in
            convertToCloudShape(contour, imageSize: ciImage.extent.size)
        } ?? []
    }
}
