import Foundation
import CoreGraphics

/// One or more spatially-adjacent CloudShapes that the recognition service
/// can identify as a single perceived "thing." Most clusters will be single
/// clouds; some will be multi-cloud constellations.
struct CloudCluster: Identifiable {
    let id = UUID()
    let shapes: [CloudShape]

    /// Combined outline of all member shapes, normalized to 0–1 within the
    /// cluster's bounding box. This is what the recognition service sees.
    let combinedContour: [CGPoint]

    /// Bucketed Hu-moments signature for cache lookup. See
    /// docs/RECOGNITION.md for the rationale.
    let signature: CloudShapeSignature

    var primaryShape: CloudShape { shapes[0] }
}
