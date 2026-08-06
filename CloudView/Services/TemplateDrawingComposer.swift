import Foundation
import CoreGraphics

/// Turns a chosen `DrawingTemplate` + a real cloud contour into a
/// `DrawingConcept` the existing `AnimatedDrawing` renderer can trace out.
///
/// This is where the "hybrid by confidence" fusion lives:
///
///   • **Strong shape match → cloud-as-body.** The cloud's own outline *is*
///     the creature's body (order 0); only the template's detail strokes
///     (ears, tail, fins, eyes) are drawn, warped so they attach at the
///     cloud's real extremes. Maximum pareidolia — the cloud literally
///     becomes the animal.
///
///   • **Weaker match → full creature, warped to the cloud.** The template's
///     own silhouette is drawn as the body and warped so it hugs the cloud's
///     shape, with all details on top. Still cloud-shaped, but the complete
///     creature is spelled out so it reads clearly even when the resemblance
///     is loose.
///
/// Pure and deterministic — no iOS/AR dependencies — so it's fully unit
/// testable off-device.
enum TemplateDrawingComposer {

    /// Score at or above which we trust the cloud to carry the body itself.
    /// Paired with `ShapeMatcher.scoreScale` and the library's confidence
    /// floor; below this (but above the floor) we draw the full creature.
    static let defaultStrongThreshold = 0.55

    static func compose(
        cloudContour: [CGPoint],
        template: DrawingTemplate,
        score: Double,
        strongMatchThreshold: Double = defaultStrongThreshold
    ) -> DrawingConcept {
        // Thin-plate spline over the cloud's landmarks when they support one,
        // else a closed-form similarity transform — either way the template is
        // draped onto the cloud's real form.
        let warp = TemplateWarp.fit(
            templateContour: template.silhouette.cgPoints,
            cloudContour: cloudContour
        )

        var paths: [DrawingConcept.DrawingPath] = []
        let cloudAsBody = score >= strongMatchThreshold

        // Body (order 0): the real cloud outline when confident, otherwise the
        // warped template silhouette.
        let bodyPoints = cloudAsBody ? cloudContour : warp.apply(template.silhouette.cgPoints)
        if bodyPoints.count >= 2 {
            paths.append(DrawingConcept.DrawingPath(points: bodyPoints, closed: true, order: 0))
        }

        // Details: always the template's strokes, warped onto the cloud, in
        // their authored reveal order (offset by 1 so the body is first).
        for stroke in template.strokes.sorted(by: { $0.order < $1.order }) {
            let pts = warp.apply(stroke.points.cgPoints)
            guard pts.count >= 2 else { continue }
            paths.append(DrawingConcept.DrawingPath(
                points: pts,
                closed: stroke.closed,
                order: stroke.order + 1
            ))
        }

        return DrawingConcept(
            name: template.label.capitalized,
            paths: paths,
            preferredShape: nil
        )
    }
}
