import SwiftUI

// Animates cloud contours as if an artist is sketching them —
// a single glowing pen tip travels through all paths sequentially,
// drawing each stroke before moving to the next.
struct HandDrawingView: View {
    let shapeName: String
    let labelPosition: CGPoint         // normalized 0-1
    var onComplete: (() -> Void)?

    @State private var drawProgress: Double = 0  // 0→1, single source of truth
    @State private var penVisible = false

    /// Honor the system Reduce Motion setting — drop the pen-trace
    /// animation in favor of an immediate full reveal so users who
    /// requested calmer motion don't see strokes sweep across the
    /// screen on every scan. The drawing still appears; it just
    /// appears whole with the label.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Precomputed at init — path ordering and segment timing
    private let orderedElements: [CloudAnalysis.DrawingElement]
    private let segments: [SegmentTiming]
    private let totalDuration: Double

    struct SegmentTiming {
        let element: CloudAnalysis.DrawingElement
        let start: Double   // fraction of total draw time this segment begins
        let end: Double     // fraction of total draw time this segment ends
    }

    init(
        elements: [CloudAnalysis.DrawingElement],
        shapeName: String,
        labelPosition: CGPoint,
        onComplete: (() -> Void)? = nil
    ) {
        self.shapeName = shapeName
        self.labelPosition = labelPosition
        self.onComplete = onComplete

        // 1. Sort: longest path first (main cloud outline before details)
        let sorted = elements.sorted { arcLength($0) > arcLength($1) }

        // 2. Nearest-neighbour ordering so pen travels minimal distance between strokes
        self.orderedElements = nearestNeighbourOrder(sorted)

        // 3. Build per-segment timing proportional to arc length
        let lengths = self.orderedElements.map { arcLength($0) }
        let total = max(lengths.reduce(0, +), 0.001)

        var segs: [SegmentTiming] = []
        var cursor = 0.0
        for (el, len) in zip(self.orderedElements, lengths) {
            let segStart = cursor / total
            let segEnd = (cursor + len) / total
            segs.append(SegmentTiming(element: el, start: segStart, end: segEnd))
            cursor += len
        }
        self.segments = segs

        // Drawing duration: faster for sparse skies, slower for dense contours
        self.totalDuration = 1.4 + min(2.0, Double(elements.count) * 0.28)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Each path, trimmed to how far the pen has reached
                ForEach(segments.indices, id: \.self) { i in
                    let seg = segments[i]
                    let local = localProgress(global: drawProgress, seg: seg)

                    if local > 0 {
                        StrokePath(
                            element: seg.element,
                            size: size,
                            progress: local
                        )
                    }
                }

                // The pen tip — a glowing dot that leads the stroke
                if penVisible, let tip = penTip(at: drawProgress, size: size) {
                    PenTip(at: tip)
                        .opacity(drawProgress > 0.01 && drawProgress < 0.97 ? 1 : 0)
                        .animation(.easeOut(duration: 0.15), value: drawProgress)
                }

                // Shape label materialises near the end of the drawing
                if drawProgress > 0.8 {
                    let labelOpacity = (drawProgress - 0.8) / 0.2
                    let labelScale = 0.72 + 0.28 * labelOpacity

                    Text(shapeName.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.35))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                        )
                        .scaleEffect(labelScale)
                        .opacity(labelOpacity)
                        .position(
                            x: labelPosition.x * size.width,
                            y: labelPosition.y * size.height
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: drawProgress > 0.8)
                }
            }
        }
        .onAppear {
            if reduceMotion {
                // Skip the animated reveal — flip straight to final
                // state so the drawing and label appear together with
                // no motion. Pen tip never shows.
                drawProgress = 1.0
                penVisible = false
                onComplete?()
                return
            }
            penVisible = true
            withAnimation(.timingCurve(0.25, 0.1, 0.65, 1.0, duration: totalDuration)) {
                drawProgress = 1.0
            }
            // Fire completion callback after drawing finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
                penVisible = false
                onComplete?()
            }
        }
    }

    // MARK: - Progress math

    // What fraction of a specific segment's path to draw, given global progress 0..1
    private func localProgress(global: Double, seg: SegmentTiming) -> Double {
        guard seg.end > seg.start else { return global >= seg.start ? 1.0 : 0.0 }
        guard global >= seg.start else { return 0 }
        return min(1.0, (global - seg.start) / (seg.end - seg.start))
    }

    // Interpolate the current pen-tip position across all segments
    private func penTip(at global: Double, size: CGSize) -> CGPoint? {
        // Which segment is the pen currently in?
        if let seg = segments.first(where: { global >= $0.start && global <= $0.end }) {
            let local = localProgress(global: global, seg: seg)
            return pointAlong(seg.element, at: local, size: size)
        }
        // Between segments (pen is "lifting") — hold at the last drawn point
        if let last = segments.last(where: { global > $0.end }),
           let lastPt = last.element.points.last {
            return CGPoint(x: lastPt[0] * size.width, y: lastPt[1] * size.height)
        }
        return nil
    }

    // Interpolate a point along a polyline at a given arc-length progress 0..1
    private func pointAlong(
        _ element: CloudAnalysis.DrawingElement,
        at progress: Double,
        size: CGSize
    ) -> CGPoint {
        let pts = element.points.map {
            CGPoint(x: ($0.count > 0 ? $0[0] : 0) * size.width,
                    y: ($0.count > 1 ? $0[1] : 0) * size.height)
        }
        guard pts.count >= 2 else { return pts.first ?? .zero }

        let segLengths: [Double] = zip(pts, pts.dropFirst()).map { a, b in
            let dx = Double(b.x - a.x)
            let dy = Double(b.y - a.y)
            return sqrt(dx * dx + dy * dy)
        }
        let total = segLengths.reduce(0, +)
        guard total > 0 else { return pts.first ?? .zero }

        let target = progress * total
        var accumulated = 0.0
        for (i, segLen) in segLengths.enumerated() {
            if accumulated + segLen >= target || i == segLengths.count - 1 {
                guard i + 1 < pts.count else { return pts.last ?? .zero }
                let t = segLen > 0 ? CGFloat((target - accumulated) / segLen) : 0
                let tc = max(0, min(1, t))
                return CGPoint(
                    x: pts[i].x + tc * (pts[i + 1].x - pts[i].x),
                    y: pts[i].y + tc * (pts[i + 1].y - pts[i].y)
                )
            }
            accumulated += segLen
        }
        return pts.last ?? .zero
    }
}

// MARK: - Stroke path

private struct StrokePath: View {
    let element: CloudAnalysis.DrawingElement
    let size: CGSize
    let progress: Double

    var body: some View {
        path
            .trim(from: 0, to: progress)
            .stroke(
                Color.white,
                style: StrokeStyle(
                    lineWidth: strokeWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            // Double shadow: outer diffuse glow + tight inner glow
            .shadow(color: .cyan.opacity(0.35), radius: 8)
            .shadow(color: .white.opacity(0.55), radius: 2)
    }

    private var strokeWidth: CGFloat {
        CGFloat(element.strokeWidth) * size.width / 375
    }

    private var path: Path {
        let pts = element.points.map {
            CGPoint(x: ($0.count > 0 ? $0[0] : 0) * size.width,
                    y: ($0.count > 1 ? $0[1] : 0) * size.height)
        }
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        pts.dropFirst().forEach { p.addLine(to: $0) }
        return p
    }
}

// MARK: - Pen tip glow

private struct PenTip: View {
    let position: CGPoint

    init(at position: CGPoint) {
        self.position = position
    }

    var body: some View {
        ZStack {
            // Soft outer halo
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 32, height: 32)
                .blur(radius: 6)

            // Mid glow ring
            Circle()
                .fill(.cyan.opacity(0.25))
                .frame(width: 14, height: 14)
                .blur(radius: 3)

            // Bright inner dot
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 5, height: 5)
        }
        .position(position)
        .allowsHitTesting(false)
    }
}

// MARK: - Arc length + path ordering helpers

// Arc length of a drawing element in normalised coordinate space
private func arcLength(_ element: CloudAnalysis.DrawingElement) -> Double {
    let pts = element.points
    var total = 0.0
    for i in 1..<pts.count {
        guard pts[i].count >= 2, pts[i - 1].count >= 2 else { continue }
        let dx = pts[i][0] - pts[i - 1][0]
        let dy = pts[i][1] - pts[i - 1][1]
        total += sqrt(dx * dx + dy * dy)
    }
    return max(total, 0.001)
}

// Nearest-neighbour: connect paths so the pen travels the shortest possible total
// distance when lifting between strokes.
private func nearestNeighbourOrder(
    _ elements: [CloudAnalysis.DrawingElement]
) -> [CloudAnalysis.DrawingElement] {
    guard elements.count > 1 else { return elements }
    var pool = elements
    var result: [CloudAnalysis.DrawingElement] = [pool.removeFirst()]

    while !pool.isEmpty {
        let lastEnd = result.last?.points.last ?? [0.5, 0.5]
        let nearestIdx = pool.indices.min { a, b in
            let ptA = pool[a].points.first ?? [0.5, 0.5]
            let ptB = pool[b].points.first ?? [0.5, 0.5]
            let da = (ptA[0] - lastEnd[0]) * (ptA[0] - lastEnd[0])
                   + (ptA[1] - lastEnd[1]) * (ptA[1] - lastEnd[1])
            let db = (ptB[0] - lastEnd[0]) * (ptB[0] - lastEnd[0])
                   + (ptB[1] - lastEnd[1]) * (ptB[1] - lastEnd[1])
            return da < db
        } ?? pool.startIndex
        result.append(pool.remove(at: nearestIdx))
    }
    return result
}
