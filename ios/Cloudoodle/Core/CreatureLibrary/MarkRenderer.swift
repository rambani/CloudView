import Foundation
import CoreGraphics

/// Turns (silhouette waypoints + character marks) into drawing
/// elements that HandDrawingView can animate. Each mark type has
/// a small dedicated function so the visual style of every "eye"
/// stays consistent across creatures — designer tuning of the
/// eye style lands once and benefits every output.
enum MarkRenderer {

    /// Compose the cloud silhouette and the given marks into a
    /// single ordered list of drawing elements. The silhouette is
    /// drawn first so character marks land on top of it during the
    /// pen-trace animation.
    static func render(
        silhouette: [[Double]],
        marks: [CharacterMark]
    ) -> [CloudAnalysis.DrawingElement] {
        var out: [CloudAnalysis.DrawingElement] = []

        // 1. Silhouette outline — closed loop
        if silhouette.count >= 3 {
            var closed = silhouette
            if let first = silhouette.first { closed.append(first) }
            out.append(.init(
                points: closed,
                smooth: true,
                strokeWidth: 2.6,
                label: "silhouette"
            ))
        }

        // 2. Each mark adds zero or more elements
        for mark in marks {
            out.append(contentsOf: renderMark(mark, silhouette: silhouette))
        }
        return out
    }

    // MARK: - Per-type renderers

    private static func renderMark(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard silhouette.count >= 3 else { return [] }
        switch mark.type {
        case .eye:          return renderEye(mark, silhouette: silhouette)
        case .mouthArc:     return renderMouthArc(mark, silhouette: silhouette)
        case .teethZigzag:  return renderTeethZigzag(mark, silhouette: silhouette)
        case .earTip:       return renderEarTip(mark, silhouette: silhouette)
        case .tailFlick:    return renderTailFlick(mark, silhouette: silhouette)
        case .spikeRow:     return renderSpikeRow(mark, silhouette: silhouette)
        case .whisker:      return renderWhisker(mark, silhouette: silhouette)
        case .claw:         return renderClaw(mark, silhouette: silhouette)
        case .fin:          return renderFin(mark, silhouette: silhouette)
        }
    }

    private static func renderEye(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let idx = mark.nearWaypoint else { return [] }
        let waypoint = wp(silhouette, idx)
        let (nx, ny) = outwardNormal(at: idx, silhouette: silhouette)
        let inset = mark.inset ?? 0.025
        let x = waypoint[0] - nx * inset
        let y = waypoint[1] - ny * inset
        // Single-point stroke — HandDrawingView renders single-point
        // strokes as bold dots, which is exactly what an eye should be.
        return [.init(
            points: [[x, y]],
            smooth: false,
            strokeWidth: 2.8,
            label: "eye"
        )]
    }

    private static func renderMouthArc(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let from = mark.fromWaypoint, let to = mark.toWaypoint else { return [] }
        let inset = mark.inset ?? 0.012
        let indices = arcIndices(from: from, to: to, count: silhouette.count)
        let points: [[Double]] = indices.map { i in
            let waypoint = wp(silhouette, i)
            let (nx, ny) = outwardNormal(at: i, silhouette: silhouette)
            return [waypoint[0] - nx * inset, waypoint[1] - ny * inset]
        }
        return [.init(
            points: points,
            smooth: true,
            strokeWidth: 1.8,
            label: "mouth"
        )]
    }

    private static func renderTeethZigzag(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let from = mark.fromWaypoint, let to = mark.toWaypoint else { return [] }
        let amp = mark.amplitude ?? 0.015
        let indices = arcIndices(from: from, to: to, count: silhouette.count)
        // Alternate inward/outward perpendicular to the silhouette
        // to create a sawtooth pattern that reads as teeth or a sharp jaw.
        var points: [[Double]] = []
        for (k, i) in indices.enumerated() {
            let waypoint = wp(silhouette, i)
            let (nx, ny) = outwardNormal(at: i, silhouette: silhouette)
            let sign: Double = (k % 2 == 0) ? -1 : 1
            points.append([
                waypoint[0] + nx * amp * sign,
                waypoint[1] + ny * amp * sign
            ])
        }
        return [.init(
            points: points,
            smooth: false,  // sharp zigzag, no smoothing
            strokeWidth: 1.6,
            label: "teeth"
        )]
    }

    private static func renderEarTip(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let idx = mark.nearWaypoint else { return [] }
        let waypoint = wp(silhouette, idx)
        let (nx, ny) = outwardNormal(at: idx, silhouette: silhouette)
        let (tx, ty) = tangent(at: idx, silhouette: silhouette)
        let height    = mark.height ?? 0.05
        let baseWidth = mark.baseWidth ?? 0.04
        let tip   = [waypoint[0] + nx * height,
                     waypoint[1] + ny * height]
        let baseL = [waypoint[0] - tx * baseWidth / 2,
                     waypoint[1] - ty * baseWidth / 2]
        let baseR = [waypoint[0] + tx * baseWidth / 2,
                     waypoint[1] + ty * baseWidth / 2]
        return [.init(
            points: [baseL, tip, baseR],
            smooth: false,
            strokeWidth: 1.8,
            label: "ear"
        )]
    }

    private static func renderTailFlick(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let idx = mark.nearWaypoint else { return [] }
        let waypoint = wp(silhouette, idx)
        let (nx, ny) = outwardNormal(at: idx, silhouette: silhouette)
        let (tx, ty) = tangent(at: idx, silhouette: silhouette)
        let length = mark.length ?? 0.06
        let curve  = mark.curve ?? 1.0
        // Three-point curve: anchor → mid (offset along tangent) → tip (outward)
        let mid = [waypoint[0] + nx * length * 0.5 + tx * length * 0.3 * curve,
                   waypoint[1] + ny * length * 0.5 + ty * length * 0.3 * curve]
        let tip = [waypoint[0] + nx * length,
                   waypoint[1] + ny * length]
        return [.init(
            points: [waypoint, mid, tip],
            smooth: true,
            strokeWidth: 2.0,
            label: "tail"
        )]
    }

    private static func renderSpikeRow(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let from = mark.fromWaypoint, let to = mark.toWaypoint else { return [] }
        let count = max(2, mark.count ?? 4)
        let height = mark.height ?? 0.018
        let n = silhouette.count
        let span: Int
        if to >= from { span = to - from }
        else { span = n - from + to }
        // Each spike is its own short stroke — gives the pen a distinct
        // pen-down / pen-up per spike during the reveal animation.
        var out: [CloudAnalysis.DrawingElement] = []
        for k in 0..<count {
            let idx = (from + Int(Double(k) * Double(span) / Double(max(1, count - 1)))) % n
            let waypoint = wp(silhouette, idx)
            let (nx, ny) = outwardNormal(at: idx, silhouette: silhouette)
            let tip = [waypoint[0] + nx * height,
                       waypoint[1] + ny * height]
            out.append(.init(
                points: [waypoint, tip],
                smooth: false,
                strokeWidth: 1.6,
                label: "spike"
            ))
        }
        return out
    }

    private static func renderWhisker(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let idx = mark.nearWaypoint else { return [] }
        let waypoint = wp(silhouette, idx)
        let (nx, ny) = outwardNormal(at: idx, silhouette: silhouette)
        let (tx, ty) = tangent(at: idx, silhouette: silhouette)
        let length = mark.length ?? 0.05
        let angle  = (mark.angle ?? 0) * .pi / 180.0
        // Rotated outward direction — mostly normal but tilted along
        // tangent by `angle` degrees so multiple whiskers fan out.
        let dx = nx * cos(angle) - tx * sin(angle) * 0.3
        let dy = ny * cos(angle) + ty * sin(angle) * 0.3
        let tip = [waypoint[0] + dx * length,
                   waypoint[1] + dy * length]
        return [.init(
            points: [waypoint, tip],
            smooth: false,
            strokeWidth: 1.2,
            label: "whisker"
        )]
    }

    private static func renderClaw(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let idx = mark.nearWaypoint else { return [] }
        let waypoint = wp(silhouette, idx)
        let (nx, ny) = outwardNormal(at: idx, silhouette: silhouette)
        let length = mark.length ?? 0.04
        let tip = [waypoint[0] + nx * length,
                   waypoint[1] + ny * length]
        return [.init(
            points: [waypoint, tip],
            smooth: false,
            strokeWidth: 1.8,
            label: "claw"
        )]
    }

    private static func renderFin(
        _ mark: CharacterMark,
        silhouette: [[Double]]
    ) -> [CloudAnalysis.DrawingElement] {
        guard let idx = mark.nearWaypoint else { return [] }
        let waypoint = wp(silhouette, idx)
        let (nx, ny) = outwardNormal(at: idx, silhouette: silhouette)
        let (tx, ty) = tangent(at: idx, silhouette: silhouette)
        let size = mark.size ?? 0.05
        // Asymmetric triangle — looks more like a fin (slanted back)
        // than a generic ear which is symmetric.
        let tip = [waypoint[0] + nx * size + tx * size * 0.3,
                   waypoint[1] + ny * size + ty * size * 0.3]
        let back = [waypoint[0] + tx * size * 0.6,
                    waypoint[1] + ty * size * 0.6]
        return [.init(
            points: [waypoint, tip, back],
            smooth: true,
            strokeWidth: 1.8,
            label: "fin"
        )]
    }

    // MARK: - Geometry helpers

    /// Indexed wrap-around access into the silhouette ring.
    private static func wp(_ silhouette: [[Double]], _ idx: Int) -> [Double] {
        let n = silhouette.count
        let safe = ((idx % n) + n) % n
        return silhouette[safe]
    }

    /// Unit normal pointing OUT of the silhouette at the given waypoint.
    /// Uses neighbors ±2 indices away for a smoother estimate than ±1.
    private static func outwardNormal(at idx: Int, silhouette: [[Double]]) -> (Double, Double) {
        let n = silhouette.count
        guard n >= 4 else { return (0, 0) }
        let a = wp(silhouette, idx - 2)
        let c = wp(silhouette, idx + 2)
        let tx = c[0] - a[0]
        let ty = c[1] - a[1]
        let tl = sqrt(tx * tx + ty * ty)
        if tl < 0.0001 { return (0, 0) }
        // Rotate tangent by -90° in screen coords to get outward normal.
        // Silhouettes come from clockwise traversal in top-left origin
        // coords, which matches this orientation.
        return (ty / tl, -tx / tl)
    }

    /// Unit tangent at the given waypoint (along the silhouette
    /// direction of travel).
    private static func tangent(at idx: Int, silhouette: [[Double]]) -> (Double, Double) {
        let n = silhouette.count
        guard n >= 4 else { return (0, 0) }
        let a = wp(silhouette, idx - 2)
        let c = wp(silhouette, idx + 2)
        let tx = c[0] - a[0]
        let ty = c[1] - a[1]
        let tl = sqrt(tx * tx + ty * ty)
        if tl < 0.0001 { return (0, 0) }
        return (tx / tl, ty / tl)
    }

    /// Indices [from, from+1, ..., to] with wrap-around if to < from.
    private static func arcIndices(from: Int, to: Int, count n: Int) -> [Int] {
        guard n > 0 else { return [] }
        let fromN = ((from % n) + n) % n
        let toN   = ((to   % n) + n) % n
        if toN >= fromN {
            return Array(fromN...toN)
        }
        return Array(fromN..<n) + Array(0...toN)
    }
}
