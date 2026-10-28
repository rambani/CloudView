import Foundation
import CoreGraphics
import ImageIO
import simd

/// Pure geometry bridging the two coordinate frames the AR pipeline lives in:
///
///   • **The capture buffer.** ARKit always delivers `capturedImage` in
///     landscape-right orientation, and `camera.intrinsics` (the pinhole
///     matrix) is expressed in that buffer's pixels. The camera's own axes are
///     the buffer's too: +X along buffer x, +Y up (buffer −y), looking down −Z.
///
///   • **The upright image.** What the user sees — portrait, the only
///     orientation the app supports. Vision is told the buffer's orientation
///     (`CGImagePropertyOrientation.right`) so every contour, bounding box
///     and landmark it reports is already upright, which is what "the top of
///     the cloud" has to mean for ears to land on top rather than on the side.
///
/// Nothing here touches ARKit types, so it's fully unit-testable.
enum CameraFrameGeometry {

    /// Rotation that makes the landscape-right buffer upright for a portrait
    /// phone. (`.right` = "the buffer's first row ends up on the right".)
    static let uprightOrientation: CGImagePropertyOrientation = .right

    /// Whether the orientation swaps the buffer's axes (quarter turns do).
    static func swapsAxes(_ orientation: CGImagePropertyOrientation) -> Bool {
        switch orientation {
        case .left, .right, .leftMirrored, .rightMirrored: return true
        default: return false
        }
    }

    /// Pixel size of the upright image for a buffer of `bufferSize`.
    static func uprightImageSize(
        bufferSize: CGSize,
        orientation: CGImagePropertyOrientation = uprightOrientation
    ) -> CGSize {
        swapsAxes(orientation)
            ? CGSize(width: bufferSize.height, height: bufferSize.width)
            : bufferSize
    }

    /// Upright-image pixel → capture-buffer pixel, so the intrinsics (which
    /// live in buffer space) can unproject it into a world ray.
    static func bufferPoint(
        fromUpright p: CGPoint,
        uprightSize: CGSize,
        orientation: CGImagePropertyOrientation = uprightOrientation
    ) -> CGPoint {
        switch orientation {
        case .right:
            // upright = buffer turned 90° clockwise:
            //   upright x runs along buffer −y, upright y along buffer +x.
            return CGPoint(x: p.y, y: uprightSize.width - p.x)
        case .left:
            return CGPoint(x: uprightSize.height - p.y, y: p.x)
        case .down:
            return CGPoint(x: uprightSize.width - p.x, y: uprightSize.height - p.y)
        default:
            return p
        }
    }

    /// World-space extent (meters) at `distance` of a region that spans
    /// `uprightPixelSize` in the upright image. Pinhole: w = px / f · d.
    /// For quarter-turn orientations the upright x axis is the buffer's y
    /// axis, so it uses fy (and vice versa).
    static func worldExtent(
        uprightPixelSize: CGSize,
        fx: Float,
        fy: Float,
        distance: Float,
        orientation: CGImagePropertyOrientation = uprightOrientation
    ) -> CGSize {
        let fAlongX = swapsAxes(orientation) ? fy : fx
        let fAlongY = swapsAxes(orientation) ? fx : fy
        guard fAlongX > 0, fAlongY > 0 else { return .zero }
        return CGSize(
            width: CGFloat(Float(uprightPixelSize.width) / fAlongX * distance),
            height: CGFloat(Float(uprightPixelSize.height) / fAlongY * distance)
        )
    }

    /// Meters at `distance` for something `pixels` wide in the image — used
    /// to give strokes a consistent on-screen thickness regardless of how
    /// large the cloud is.
    static func worldLength(pixels: Float, focalLength f: Float, distance: Float) -> Float {
        guard f > 0 else { return 0 }
        return pixels / f * distance
    }

    /// Local roll that turns an entity authored in upright-image axes
    /// (+X = image right, +Y = image up) into the camera's buffer axes.
    /// Compose with the camera's rotation to get the anchor's world
    /// orientation: `simd_quatf(cameraTransform) * uprightRoll()`.
    static func uprightRoll(
        orientation: CGImagePropertyOrientation = uprightOrientation
    ) -> simd_quatf {
        let angle: Float
        switch orientation {
        case .right: angle = .pi / 2    // upright right → buffer up (camera +Y)
        case .left:  angle = -.pi / 2
        case .down:  angle = .pi
        default:     angle = 0
        }
        return simd_quatf(angle: angle, axis: SIMD3<Float>(0, 0, 1))
    }

    /// World orientation for a drawing anchored along the camera ray: faces
    /// the camera (its plane is perpendicular to the view direction) with the
    /// image upright. Taken once at creation; the drawing is ~50 m out, so
    /// the user walking a few steps doesn't change the view angle.
    static func drawingOrientation(
        cameraTransform: simd_float4x4,
        orientation: CGImagePropertyOrientation = uprightOrientation
    ) -> simd_quatf {
        simd_quatf(cameraTransform) * uprightRoll(orientation: orientation)
    }
}
