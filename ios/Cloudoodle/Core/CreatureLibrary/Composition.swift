import Foundation
import CoreGraphics

/// Composes a subject + optional prop into a flat array of
/// `CloudAnalysis.DrawingElement`s ready to feed to HandDrawingView.
/// The actual rendering view doesn't know or care that the strokes
/// came from a template library instead of a generative model.
enum Composition {

    /// Strokes whose label contains any of these substrings are
    /// considered the template's body outline / silhouette. When real
    /// cloud waypoints are available they replace these strokes, so
    /// the drawing's outline IS the cloud rather than floating on top.
    private static let silhouetteTags: Set<String> = [
        "body", "outline", "silhouette", "head", "hull", "back", "belly"
    ]

    /// Shape-conforming compose. If `cloudWaypoints` is non-empty, the
    /// cloud silhouette becomes the body outline and the template only
    /// provides character details (eyes, beak, mouth, fins, etc.).
    /// When no waypoints are available, falls back to bounding-box fit.
    static func compose(
        subjectId: String,
        propId: String?,
        in cloudBox: CGRect,
        cloudWaypoints: [[Double]] = []
    ) -> [CloudAnalysis.DrawingElement] {
        if cloudWaypoints.count >= 6 {
            return composeShapeAware(
                subjectId: subjectId,
                propId: propId,
                cloudWaypoints: cloudWaypoints
            )
        }
        return composeBoundingBoxFit(
            subjectId: subjectId,
            propId: propId,
            in: cloudBox
        )
    }

    // MARK: - Shape-conforming composition (cloud waypoints available)

    private static func composeShapeAware(
        subjectId: String,
        propId: String?,
        cloudWaypoints: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        let lib = TemplateLibrary.shared
        guard let subject = lib.subjects[subjectId] else { return [] }

        let cloudBox = boundingBox(of: cloudWaypoints)
        let templateBox = templateBoundingBox(subject)

        var elements: [CloudAnalysis.DrawingElement] = []

        // 1. Body outline = cloud silhouette itself, closed loop.
        var closed = cloudWaypoints
        if let first = closed.first { closed.append(first) }
        elements.append(CloudAnalysis.DrawingElement(
            points: closed,
            smooth: true,
            strokeWidth: 2.4,
            label: "cloud-silhouette"
        ))

        // 2. Detail strokes from the template, mapped from template
        // local bbox into cloud bbox.
        for stroke in subject.strokes {
            guard !isSilhouette(stroke.label) else { continue }
            let mapped = stroke.points.map { mapPoint($0,
                                                     from: templateBox,
                                                     to: cloudBox) }
            elements.append(CloudAnalysis.DrawingElement(
                points: mapped,
                smooth: stroke.points.count >= 3,
                strokeWidth: stroke.width,
                label: stroke.label
            ))
        }

        // 3. Prop strokes, hooked via the subject anchor mapped into cloud space.
        if let propId,
           let prop = lib.props[propId],
           let anchorName = prop.attachesTo,
           let subjectAnchor = subject.anchors?[anchorName],
           subjectAnchor.count >= 2 {
            let anchorPoint = mapPointCG(subjectAnchor, from: templateBox, to: cloudBox)
            let scale = prop.sizeRelativeToSubject ?? 1.0
            let propWidth = cloudBox.width * scale
            let propBBox = templateBoundingBox(prop)
            let propAspect = max(0.001, propBBox.width / max(propBBox.height, 0.001))
            let propHeight = propWidth / propAspect
            let selfAnchor = prop.anchorOnSelf ?? [0.5, 0.5]
            let propBoxX = anchorPoint.x - selfAnchor[0] * propWidth
            let propBoxY = anchorPoint.y - selfAnchor[1] * propHeight
            let propTarget = CGRect(x: propBoxX, y: propBoxY, width: propWidth, height: propHeight)
            for stroke in prop.strokes {
                let mapped = stroke.points.map { mapPoint($0,
                                                          from: propBBox,
                                                          to: propTarget) }
                elements.append(CloudAnalysis.DrawingElement(
                    points: mapped,
                    smooth: stroke.points.count >= 3,
                    strokeWidth: stroke.width,
                    label: stroke.label
                ))
            }
        }

        return elements
    }

    /// True when a stroke label identifies it as a body outline that
    /// should be replaced by the cloud silhouette.
    private static func isSilhouette(_ label: String) -> Bool {
        let lower = label.lowercased()
        return silhouetteTags.contains(where: { lower.contains($0) })
    }

    /// Affine map: a normalized 0-1 point inside the template's bbox
    /// is rewritten to the corresponding point inside the cloud bbox.
    private static func mapPoint(
        _ p: [Double],
        from src: CGRect,
        to dst: CGRect
    ) -> [Double] {
        guard p.count >= 2 else { return [Double(dst.midX), Double(dst.midY)] }
        let xLocal = (p[0] - Double(src.minX)) / max(Double(src.width), 0.001)
        let yLocal = (p[1] - Double(src.minY)) / max(Double(src.height), 0.001)
        return [
            Double(dst.minX) + xLocal * Double(dst.width),
            Double(dst.minY) + yLocal * Double(dst.height)
        ]
    }

    /// CGPoint-returning variant. Renamed (was previously an
    /// overload of mapPoint differing only in return type) because
    /// Swift can't disambiguate the two when the call site doesn't
    /// pin the return type — e.g., inside `.map { ... }` closures
    /// where the result is later passed through several layers of
    /// inference.
    private static func mapPointCG(
        _ p: [Double],
        from src: CGRect,
        to dst: CGRect
    ) -> CGPoint {
        let out: [Double] = mapPoint(p, from: src, to: dst)
        return CGPoint(x: out[0], y: out[1])
    }

    /// Bounding box (in normalized 0-1 photo-space) of a list of waypoints.
    private static func boundingBox(of points: [[Double]]) -> CGRect {
        var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0
        for p in points {
            if let x = p.first { minX = min(minX, x); maxX = max(maxX, x) }
            if let y = p.dropFirst().first { minY = min(minY, y); maxY = max(maxY, y) }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func templateBoundingBox(_ template: CreatureTemplate) -> CGRect {
        var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0
        for stroke in template.strokes {
            for p in stroke.points {
                if let x = p.first { minX = min(minX, x); maxX = max(maxX, x) }
                if let y = p.dropFirst().first { minY = min(minY, y); maxY = max(maxY, y) }
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Bounding-box-fit composition (no cloud waypoints)

    private static func composeBoundingBoxFit(
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
