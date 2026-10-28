import Foundation
import CoreGraphics
import simd

/// Pure mesh geometry for hand-drawn-looking strokes: maps a normalized path
/// onto the drawing's plane in meters, cuts it at the pen's current position
/// for a true progressive reveal, and builds a ribbon mesh with round joins
/// and caps. No RealityKit here, so all of it is unit-testable.
enum StrokeGeometry {

    struct Mesh {
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var isEmpty: Bool { indices.isEmpty }
    }

    /// Normalized path points (0–1 in the drawing's box, y-down) → local
    /// meters on the drawing's plane: centered, y-up, z = 0.
    static func localPoints(_ normalized: [CGPoint], worldSize: CGSize) -> [SIMD2<Float>] {
        normalized.map {
            SIMD2<Float>(
                Float($0.x - 0.5) * Float(worldSize.width),
                Float(0.5 - $0.y) * Float(worldSize.height)
            )
        }
    }

    /// The polyline as a pen would draw it — with the closing segment
    /// appended when the path is closed.
    static func polyline(_ points: [SIMD2<Float>], closed: Bool) -> [SIMD2<Float>] {
        guard closed, points.count > 2, let first = points.first else { return points }
        return points + [first]
    }

    static func totalLength(_ polyline: [SIMD2<Float>]) -> Float {
        guard polyline.count >= 2 else { return 0 }
        var length: Float = 0
        for i in 1..<polyline.count {
            length += simd_distance(polyline[i - 1], polyline[i])
        }
        return length
    }

    /// The prefix of `polyline` a pen has covered at `reveal` (0…1 of the
    /// arc length), ending exactly at the pen tip — so the stroke grows at a
    /// constant speed along its length rather than popping in point by point.
    static func revealedPrefix(_ polyline: [SIMD2<Float>], reveal: Float) -> [SIMD2<Float>] {
        guard let first = polyline.first else { return [] }
        if polyline.count < 2 { return [first] }
        if reveal >= 1 { return polyline }
        let target = totalLength(polyline) * max(reveal, 0)
        if target <= 0 { return [first] }

        var out: [SIMD2<Float>] = [first]
        var covered: Float = 0
        for i in 1..<polyline.count {
            let a = polyline[i - 1], b = polyline[i]
            let seg = simd_distance(a, b)
            if seg <= 0 { continue }
            if covered + seg <= target {
                out.append(b)
                covered += seg
            } else {
                let f = (target - covered) / seg
                out.append(a + (b - a) * f)
                return out
            }
        }
        return out
    }

    /// Triangle mesh for a ribbon `width` wide along `polyline`, in the
    /// z = 0 plane facing +Z. Every vertex also gets a small disc so joins
    /// and caps are round and the pen tip reads as a dot while it moves.
    /// Winding is counter-clockwise viewed from +Z.
    static func ribbon(_ polyline: [SIMD2<Float>], width: Float, discSegments: Int = 8) -> Mesh {
        var mesh = Mesh()
        guard let first = polyline.first, width > 0 else { return mesh }
        let half = width / 2

        func add(_ p: SIMD2<Float>) -> UInt32 {
            mesh.positions.append(SIMD3<Float>(p.x, p.y, 0))
            return UInt32(mesh.positions.count - 1)
        }
        func triangle(_ a: UInt32, _ b: UInt32, _ c: UInt32) {
            mesh.indices.append(a); mesh.indices.append(b); mesh.indices.append(c)
        }

        if polyline.count >= 2 {
            for i in 1..<polyline.count {
                let a = polyline[i - 1], b = polyline[i]
                let d = b - a
                let len = simd_length(d)
                guard len > 1e-7 else { continue }
                let n = SIMD2<Float>(-d.y, d.x) / len * half
                let i0 = add(a + n), i1 = add(a - n), i2 = add(b - n), i3 = add(b + n)
                triangle(i0, i1, i2)
                triangle(i0, i2, i3)
            }
        }

        let segments = max(discSegments, 3)
        let discCenters = polyline.count >= 2 ? polyline : [first]
        for p in discCenters {
            let c = add(p)
            var ring: [UInt32] = []
            ring.reserveCapacity(segments)
            for k in 0..<segments {
                let t = Float(k) / Float(segments) * 2 * Float.pi
                ring.append(add(p + SIMD2<Float>(cos(t), sin(t)) * half))
            }
            for k in 0..<segments {
                triangle(c, ring[k], ring[(k + 1) % segments])
            }
        }
        return mesh
    }
}
