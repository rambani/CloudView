import Foundation
import CoreGraphics
import CoreVideo
import UIKit

/// Rasterizes a `CloudCluster`'s normalized contour into a 224×224 RGB
/// CVPixelBuffer suitable for the MobileCLIP image encoder. The output
/// is white-background, black-foreground — silhouettes are unusual CLIP
/// inputs either way; we picked white-on-black inverted in early tests
/// and found the embeddings landed closer to expected text prompts when
/// the cloud is the lighter region (matching its visual identity). This
/// detail is part of the prompt-engineering story in docs/RECOGNITION.md.
enum CloudSilhouetteRenderer {
    static let inputSize = CGSize(width: 224, height: 224)

    static func render(_ cluster: CloudCluster) -> CVPixelBuffer? {
        guard cluster.combinedContour.count >= 3 else { return nil }

        let canvas = CGRect(origin: .zero, size: inputSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: inputSize, format: format)

        let image = renderer.image { ctx in
            // Black background (sky-at-night feel; CLIP doesn't care, but
            // the cloud silhouette as the bright element matches what the
            // text prompts describe — "a cloud that looks like a dragon").
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(canvas)

            // Bounding box of the normalized contour (0..1 per axis)
            let (minP, maxP) = boundingBox(of: cluster.combinedContour)
            let w = max(maxP.x - minP.x, 0.001)
            let h = max(maxP.y - minP.y, 0.001)
            // Fit into 80% of the canvas, centered, preserving aspect ratio.
            let pad: CGFloat = 0.10
            let availW = inputSize.width * (1 - 2 * pad)
            let availH = inputSize.height * (1 - 2 * pad)
            let scale = min(availW / w, availH / h)
            let drawW = w * scale
            let drawH = h * scale
            let offsetX = (inputSize.width - drawW) / 2
            let offsetY = (inputSize.height - drawH) / 2

            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            let path = UIBezierPath()
            for (i, p) in cluster.combinedContour.enumerated() {
                let x = offsetX + (p.x - minP.x) * scale
                let y = offsetY + (p.y - minP.y) * scale
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.close()
            path.fill()
        }

        return pixelBuffer(from: image)
    }

    private static func boundingBox(of points: [CGPoint]) -> (CGPoint, CGPoint) {
        var minX: CGFloat = .infinity, minY: CGFloat = .infinity
        var maxX: CGFloat = -.infinity, maxY: CGFloat = -.infinity
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return (CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: maxY))
    }

    /// Convert UIImage → CVPixelBuffer in the kCVPixelFormatType_32BGRA
    /// layout that Core ML image inputs accept by default.
    private static func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]

        var pb: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(inputSize.width),
            Int(inputSize.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pb
        )
        guard status == kCVReturnSuccess, let buffer = pb else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let address = CVPixelBufferGetBaseAddress(buffer),
              let cgImage = image.cgImage else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: address,
            width: Int(inputSize.width),
            height: Int(inputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
                        CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.draw(cgImage, in: CGRect(origin: .zero, size: inputSize))
        return buffer
    }
}
