import Foundation
import CoreGraphics

/// The shape `AnimatedDrawing` and the recognition adapter both
/// consume. A name + an ordered list of paths to trace out over the
/// drawing animation, optionally tagged with a preferred cloud shape
/// category (unused today; the recognition pipeline doesn't filter
/// by cloud shape, since CLIP figures that out implicitly).
///
/// Historical context: this file used to contain a procedural
/// generator (100+ enum-cased subjects × 70+ actions × 90+
/// accessories, with shape-compatibility rules and hand-coded path
/// generators). All of that is now superseded by the on-device CLIP
/// recognition pipeline (see docs/RECOGNITION.md). The struct below
/// is the one piece worth keeping — it's the wire format between the
/// recognition adapter in ARViewModel and AnimatedDrawing.
struct DrawingConcept {
    let name: String
    let paths: [DrawingPath]
    let preferredShape: CloudShape.ShapeCategory?

    struct DrawingPath {
        let points: [CGPoint]
        let closed: Bool
        let order: Int
    }
}
