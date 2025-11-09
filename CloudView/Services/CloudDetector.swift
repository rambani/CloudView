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
        // Convert pixel buffer to CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Detect bright regions (clouds are typically bright)
        guard let brightRegions = detectBrightRegions(in: ciImage) else {
            return []
        }

        // Convert to cloud shapes
        return brightRegions.compactMap { observation in
            convertToCloudShape(observation, imageSize: ciImage.extent.size)
        }
    }

    private func detectBrightRegions(in image: CIImage) -> [VNRectangleObservation]? {
        // Use Vision to detect bright regions
        let request = VNDetectRectanglesRequest()
        request.minimumSize = 0.1 // At least 10% of image
        request.maximumObservations = 5

        let handler = VNImageRequestHandler(ciImage: image, options: [:])

        do {
            try handler.perform([request])
            return request.results as? [VNRectangleObservation]
        } catch {
            print("Cloud detection error: \(error)")
            return nil
        }
    }

    private func convertToCloudShape(_ observation: VNRectangleObservation, imageSize: CGSize) -> CloudShape? {
        let boundingBox = observation.boundingBox

        // Convert normalized coordinates to image coordinates
        let rect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: boundingBox.origin.y * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

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

        return CloudShape(
            center: simd_float3(0, 0, 0), // Will be calculated later in world space
            boundingBox: rect,
            screenPosition: center,
            size: size,
            aspectRatio: aspectRatio,
            area: area
        )
    }

    // Alternative: Use brightness-based detection for better cloud recognition
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
        return await detectContoursAsCloudShapes(in: outputImage)
    }

    private func detectContoursAsCloudShapes(in image: CIImage) async -> [CloudShape] {
        // Use contour detection
        let request = VNDetectContoursRequest()
        request.maximumImageDimension = 512 // Reduce resolution for performance

        let handler = VNImageRequestHandler(ciImage: image, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results as? [VNContoursObservation] else {
                return []
            }

            // Convert top contours to cloud shapes
            let topContours = results.prefix(5)
            return topContours.compactMap { contour in
                convertContourToCloudShape(contour, imageSize: image.extent.size)
            }
        } catch {
            print("Contour detection error: \(error)")
            return []
        }
    }

    private func convertContourToCloudShape(_ contour: VNContoursObservation, imageSize: CGSize) -> CloudShape? {
        let boundingBox = contour.boundingBox

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

        return CloudShape(
            center: simd_float3(0, 0, 0),
            boundingBox: rect,
            screenPosition: center,
            size: size,
            aspectRatio: aspectRatio,
            area: area
        )
    }
}
