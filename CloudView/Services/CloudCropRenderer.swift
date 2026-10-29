import Foundation
import CoreGraphics
import CoreImage
import CoreVideo

/// Cuts the real cloud out of the camera frame for the recognition model —
/// the photo of the cloud, not its silhouette. A vision-language model
/// sees shading, bumps and texture a silhouette throws away, which is
/// most of what makes a cloud look like a bear.
enum CloudCropRenderer {
    static let inputSize = 224
    /// Extra context around the cloud's box, as a fraction of its size, so
    /// the model sees where the cloud ends and the sky begins.
    static let margin: CGFloat = 0.15

    /// Square crop rect (upright pixels) around the cloud box with margin,
    /// clamped to the frame. Pure, tested.
    static func cropRect(for box: CGRect, in frameSize: CGSize) -> CGRect {
        guard box.width > 0, box.height > 0, frameSize.width > 0, frameSize.height > 0 else { return .zero }
        let side = max(box.width, box.height) * (1 + 2 * margin)
        var rect = CGRect(x: box.midX - side / 2, y: box.midY - side / 2, width: side, height: side)
        // Shrink to fit if the square is bigger than the frame, then slide inside.
        let fit = min(side, frameSize.width, frameSize.height)
        rect = CGRect(x: box.midX - fit / 2, y: box.midY - fit / 2, width: fit, height: fit)
        rect.origin.x = min(max(rect.origin.x, 0), frameSize.width - fit)
        rect.origin.y = min(max(rect.origin.y, 0), frameSize.height - fit)
        return rect.integral
    }

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The cloud crop as a 224×224 BGRA pixel buffer, upright. Call before
    /// the frame is recycled.
    static func render(
        pixelBuffer: CVPixelBuffer,
        cloudBox: CGRect,
        orientation: CGImagePropertyOrientation = CameraFrameGeometry.uprightOrientation
    ) -> CVPixelBuffer? {
        let upright = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let frameSize = upright.extent.size
        let rect = cropRect(for: cloudBox, in: frameSize)
        guard rect.width > 0 else { return nil }

        // CI's y axis points up; the box is y-down.
        let ciRect = CGRect(x: rect.minX, y: frameSize.height - rect.maxY, width: rect.width, height: rect.height)
        let k = CGFloat(inputSize) / rect.width
        let cropped = upright
            .cropped(to: ciRect)
            .transformed(by: CGAffineTransform(translationX: -ciRect.minX, y: -ciRect.minY))
            .transformed(by: CGAffineTransform(scaleX: k, y: k))

        var out: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, inputSize, inputSize, kCVPixelFormatType_32BGRA,
                                  attrs as CFDictionary, &out) == kCVReturnSuccess,
              let buffer = out
        else { return nil }
        context.render(cropped, to: buffer, bounds: CGRect(x: 0, y: 0, width: inputSize, height: inputSize),
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        return buffer
    }
}
