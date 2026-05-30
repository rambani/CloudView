import Foundation
import CoreGraphics

/// Converts the recognition pipeline's `Interpretation` output into the
/// `DrawingConcept` shape that `AnimatedDrawing` knows how to animate.
/// Pure function. No iOS dependencies — testable on its own.
///
/// Composition rule: the cloud's own outline is always path #1 (the
/// body). Annotation marks layer on top in order, capped at
/// `annotationCap` regardless of how generous the hints library is,
/// so the cloud always stays visually dominant in the final drawing.
enum RecognitionToDrawingAdapter {

    /// Maximum number of annotation paths included over the cloud
    /// outline. Higher than this risks the marks dominating the
    /// cloud silhouette visually.
    static let annotationCap = 10

    /// Radius of the circle that a `.dot` annotation expands to, in
    /// normalized 0-1 coordinates. Small enough to read as a "dot",
    /// large enough that the line-mesh renderer's edge thickness
    /// makes it visible.
    static let dotRadius: CGFloat = 0.012

    /// Build a DrawingConcept for the given recognition result.
    static func makeDrawingConcept(
        from interpretation: Interpretation,
        cloudShape: CloudShape
    ) -> DrawingConcept {
        var paths: [DrawingConcept.DrawingPath] = []

        // 1. The cloud's own outline IS the body.
        if !cloudShape.normalizedContour.isEmpty {
            paths.append(DrawingConcept.DrawingPath(
                points: cloudShape.normalizedContour,
                closed: true,
                order: 1
            ))
        }

        // 2. Annotations: small marks layered on top, animated in order.
        //    Dot annotations (single point) expand to a tiny polygon so the
        //    line-mesh renderer has something to trace (it needs ≥2 points).
        for (idx, annotation) in interpretation.annotations.prefix(annotationCap).enumerated() {
            let pts: [CGPoint]
            let closed: Bool
            switch annotation.kind {
            case .dot:
                pts = expandDot(at: annotation.points.first ?? .zero, radius: dotRadius)
                closed = true
            case .line:
                pts = annotation.points
                closed = false
            case .arc:
                pts = annotation.points
                closed = false
            }
            paths.append(DrawingConcept.DrawingPath(
                points: pts,
                closed: closed,
                order: idx + 2
            ))
        }

        return DrawingConcept(
            name: interpretation.label.capitalized,
            paths: paths,
            preferredShape: nil
        )
    }

    /// Six-point regular polygon approximating a small filled circle.
    /// Used for `Annotation.dot` because the existing line-mesh renderer
    /// needs ≥2 points to draw anything.
    static func expandDot(at center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<6).map { i in
            let t = Double(i) / 6 * 2 * .pi
            return CGPoint(
                x: center.x + radius * CGFloat(cos(t)),
                y: center.y + radius * CGFloat(sin(t))
            )
        }
    }
}
