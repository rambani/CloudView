import UIKit
import CoreGraphics

/// Crops the input photo to a 1024×1024 square centered on the most
/// shape-suggestive cloud region. Sending the crop instead of the
/// full photo to the image-edit API cuts cost meaningfully
/// (smaller image = fewer tokens) and focuses the model on the
/// region that actually has visual interest.
///
/// When Vision didn't produce a usable candidate, falls back to a
/// center crop — still 1024×1024 — so the develop path never stalls.
enum SmartCrop {

    struct Result {
        /// The cropped 1024×1024 image, ready to send to the API.
        let cropped: UIImage
        /// The crop rectangle in the ORIGINAL photo's coordinates
        /// (normalized 0–1). We keep this so the developed image
        /// can be composited back onto the photo at the right
        /// location instead of the user seeing a tiny standalone
        /// square.
        let normalizedRect: CGRect
    }

    /// Pick the candidate's bounding box, expand it to a square with
    /// padding, clamp to image bounds, then crop. Always returns a
    /// 1024×1024 image (resized if the source crop is larger).
    static func crop(
        photo: UIImage,
        around candidate: CloudVisionService.CandidateRegion?
    ) -> Result {
        let size = photo.size
        let w = size.width
        let h = size.height

        // Target bounding box in normalized photo coords
        let target: CGRect
        if let c = candidate, c.boundingBox.width > 0.01, c.boundingBox.height > 0.01 {
            target = c.boundingBox
        } else {
            // No candidate — center square of the photo
            let side: CGFloat = 0.7   // 70% of the shorter dimension
            target = CGRect(x: 0.5 - side/2, y: 0.5 - side/2, width: side, height: side)
        }

        // Expand to square + add 15% padding so we don't crop right up
        // against the candidate's silhouette. Model sees a bit of the
        // surrounding sky which helps it understand context.
        let pad: CGFloat = 0.15
        let longSide = max(target.width, target.height) * (1 + pad * 2)
        let cx = target.midX
        let cy = target.midY

        var nx = cx - longSide / 2
        var ny = cy - longSide / 2
        var nw = longSide
        var nh = longSide

        // Clamp to [0, 1] without breaking the square aspect
        if nx < 0 { nx = 0 }
        if ny < 0 { ny = 0 }
        if nx + nw > 1 { nx = 1 - nw }
        if ny + nh > 1 { ny = 1 - nh }
        if nx < 0 { nx = 0; nw = min(1, nw) }
        if ny < 0 { ny = 0; nh = min(1, nh) }

        // To pixel coordinates in the source image
        let rect = CGRect(
            x: nx * w,
            y: ny * h,
            width: nw * w,
            height: nh * h
        )

        // Crop via CGImage to preserve orientation handling
        guard let cg = photo.cgImage,
              let cropped = cg.cropping(to: rect)
        else {
            return Result(
                cropped: resize(photo, to: 1024),
                normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1)
            )
        }
        let croppedUI = UIImage(cgImage: cropped, scale: photo.scale, orientation: photo.imageOrientation)
        return Result(
            cropped: resize(croppedUI, to: 1024),
            normalizedRect: CGRect(x: nx, y: ny, width: nw, height: nh)
        )
    }

    /// Resize while preserving aspect — pads with transparent edges
    /// if the source isn't square (which it should be after our
    /// square bbox expansion, but defensive).
    private static func resize(_ image: UIImage, to side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}
