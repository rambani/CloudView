import Foundation
import CoreGraphics

/// Composes a subject + optional prop into a flat array of
/// `CloudAnalysis.DrawingElement`s ready to feed to HandDrawingView.
/// The actual rendering view doesn't know or care that the strokes
/// came from a template library instead of a generative model.
enum Composition {

    /// Build a drawing from the chosen template ids fit to the
    /// cloud's bounding box. `cloudBox` is in normalized photo-space
    /// (0–1 on each axis) so the strokes land where the cloud is.
    static func compose(
        subjectId: String,
        propId: String?,
        in cloudBox: CGRect
    ) -> [CloudAnalysis.DrawingElement] {
        let lib = TemplateLibrary.shared
        guard let subject = lib.subjects[subjectId] else { return [] }

        // Subject fits into the cloud box, preserving the template's
        // own aspect ratio. Cloud boxes can be wide / tall / square
        // depending on the silhouette; we letterbox rather than
        // squash so a penguin stays a penguin.
        let subjectFit = fit(subject, into: cloudBox)
        var elements = subjectFit.elements

        // If a prop was selected and the subject has the prop's
        // expected anchor, compose the prop on top.
        if let propId,
           let prop = lib.props[propId],
           let anchorName = prop.attachesTo,
           let subjectAnchor = subject.anchors?[anchorName],
           subjectAnchor.count >= 2 {
            // 1. Subject anchor in PHOTO coordinates
            let anchorPhoto = CGPoint(
                x: subjectFit.box.minX + subjectAnchor[0] * subjectFit.box.width,
                y: subjectFit.box.minY + subjectAnchor[1] * subjectFit.box.height
            )
            // 2. Prop size — relative to fit subject width
            let scale = prop.sizeRelativeToSubject ?? 1.0
            let propWidth  = subjectFit.box.width * scale
            let propAspect = templateAspect(prop)
            let propHeight = propWidth / propAspect
            // 3. Position prop so its `anchor_on_self` meets the
            //    subject anchor point.
            let selfAnchor = prop.anchorOnSelf ?? [0.5, 0.5]
            let propBox = CGRect(
                x: anchorPhoto.x - selfAnchor[0] * propWidth,
                y: anchorPhoto.y - selfAnchor[1] * propHeight,
                width: propWidth,
                height: propHeight
            )
            let propFit = fit(prop, into: propBox)
            elements.append(contentsOf: propFit.elements)
        }

        return elements
    }

    /// Affine fit: scale the template's [0,1]×[0,1] strokes into the
    /// target box while preserving aspect. Returns the fit box (which
    /// may be a letterboxed subset of `target`) plus the elements
    /// translated into target coordinates.
    private struct FitResult {
        let box: CGRect
        let elements: [CloudAnalysis.DrawingElement]
    }

    private static func fit(_ template: CreatureTemplate, into target: CGRect) -> FitResult {
        let aspect = templateAspect(template)
        let targetAspect = target.width / max(target.height, 0.001)
        var box = target
        if aspect > targetAspect {
            // template is wider than target — fit width, letterbox vertically
            let h = target.width / aspect
            box = CGRect(
                x: target.minX,
                y: target.minY + (target.height - h) / 2,
                width: target.width,
                height: h
            )
        } else if aspect < targetAspect {
            // template is taller than target — fit height, letterbox horizontally
            let w = target.height * aspect
            box = CGRect(
                x: target.minX + (target.width - w) / 2,
                y: target.minY,
                width: w,
                height: target.height
            )
        }
        let elements = template.strokes.map { stroke -> CloudAnalysis.DrawingElement in
            let mapped = stroke.points.map { pt -> [Double] in
                let x = Double(box.minX) + (pt.first ?? 0.5) * Double(box.width)
                let y = Double(box.minY) + (pt.dropFirst().first ?? 0.5) * Double(box.height)
                return [x, y]
            }
            return CloudAnalysis.DrawingElement(
                points: mapped,
                smooth: stroke.points.count >= 3,
                strokeWidth: stroke.width,
                label: stroke.label
            )
        }
        return FitResult(box: box, elements: elements)
    }

    /// Aspect ratio (w/h) computed from the template strokes' bounding
    /// box. Defaults to 1.0 if the template has no strokes (which
    /// shouldn't happen, but guards against div-by-zero).
    private static func templateAspect(_ template: CreatureTemplate) -> CGFloat {
        var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0
        for stroke in template.strokes {
            for pt in stroke.points {
                if let x = pt.first   { minX = min(minX, x); maxX = max(maxX, x) }
                if let y = pt.dropFirst().first { minY = min(minY, y); maxY = max(maxY, y) }
            }
        }
        let w = max(0.001, maxX - minX)
        let h = max(0.001, maxY - minY)
        return CGFloat(w / h)
    }
}
