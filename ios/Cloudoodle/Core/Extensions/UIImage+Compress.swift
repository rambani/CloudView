import UIKit

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
