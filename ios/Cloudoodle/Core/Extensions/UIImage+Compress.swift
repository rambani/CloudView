import UIKit
import CoreImage

extension UIImage {
    /// Mean perceptual luminance of the image, 0 (black) … 1 (white).
    /// One CIAreaAverage pass — cheap enough to run on every capture.
    /// Used to catch night-sky scans BEFORE they hit the AI proxy:
    /// a black frame produces a garbage Polaroid and would burn the
    /// free user's daily quota on it.
    var averageLuminance: CGFloat? {
        guard let cg = cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: ci,
                kCIInputExtentKey: CIVector(cgRect: ci.extent)
            ]
        ), let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        let r = CGFloat(bitmap[0]) / 255
        let g = CGFloat(bitmap[1]) / 255
        let b = CGFloat(bitmap[2]) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

extension UIImage {
    // Resize to fit within maxDimension while preserving aspect ratio
    func resized(maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        guard scale < 1.0 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    // Prepare image for Anthropic API — resize and compress
    func preparedForAnalysis() -> Data? {
        resized(maxDimension: 1568).jpegData(compressionQuality: 0.82)
    }

    // Create a thumbnail for local display
    func thumbnail(size: CGFloat = 400) -> UIImage {
        resized(maxDimension: size)
    }
}
