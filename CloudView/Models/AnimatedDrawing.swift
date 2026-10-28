import Foundation
import RealityKit
import UIKit
import simd

/// Draws a `DrawingConcept` in AR the way a hand would: stroke by stroke, each
/// one growing along its length at a steady pen speed. Two layers per stroke
/// — a soft white halo under a dark ink line — so the drawing reads both on
/// the white body of the cloud and on blue sky.
///
/// Geometry is in the drawing's own plane (local +X = image right, +Y = image
/// up, meters); the owner orients the parent entity to face the camera. All
/// mesh math lives in `StrokeGeometry` (pure); this class only schedules
/// frames and hands meshes to RealityKit.
final class AnimatedDrawing {
    let concept: DrawingConcept
    /// Size of the drawing's box in meters at its anchor distance.
    let worldSize: CGSize
    /// Ink stroke width in meters at the anchor distance.
    let lineWidth: Float
    let duration: TimeInterval

    enum Look {
        /// Deep ink that stays legible over white cloud.
        static let ink = UIColor(red: 0.12, green: 0.18, blue: 0.32, alpha: 1)
        static let inkOpacity: Float = 0.92
        /// Soft white glow that keeps the line legible over blue sky.
        static let halo = UIColor.white
        static let haloOpacity: Float = 0.55
        static let haloWidthFactor: Float = 2.6
        /// Ink sits this far in front of the halo so it always wins the
        /// depth test; invisible at the ~50 m anchor distance.
        static let inkLift: Float = 0.05
        static let frameInterval: TimeInterval = 1.0 / 30.0
        /// Even a tiny stroke gets at least this share of the reveal time,
        /// so dots and short marks don't just pop in.
        static let minimumPathShare: Float = 0.04
    }

    private struct Track {
        let polyline: [SIMD2<Float>]
        let start: TimeInterval
        let end: TimeInterval
        let halo: ModelEntity
        let ink: ModelEntity
        var finished = false
    }

    private var tracks: [Track] = []
    private var timer: Timer?
    private var startDate: Date?

    init(concept: DrawingConcept, worldSize: CGSize, lineWidth: Float, duration: TimeInterval) {
        self.concept = concept
        self.worldSize = worldSize
        self.lineWidth = max(lineWidth, 0.0005)
        self.duration = max(duration, 0.1)
    }

    deinit {
        timer?.invalidate()
    }

    /// Start revealing the drawing as children of `entity`. The instance
    /// keeps itself alive through its frame timer until the reveal finishes
    /// (or the host entity has been removed from the scene).
    func animate(entity: Entity) {
        let sorted = concept.paths.sorted { $0.order < $1.order }
        let polylines: [[SIMD2<Float>]] = sorted.map { path in
            StrokeGeometry.polyline(
                StrokeGeometry.localPoints(path.points, worldSize: worldSize),
                closed: path.closed
            )
        }
        guard !polylines.isEmpty else { return }

        // Time per stroke ∝ its length (constant pen speed), floored.
        let lengths = polylines.map(StrokeGeometry.totalLength)
        let total = lengths.reduce(0, +)
        var shares: [Float] = lengths.map { length in
            let proportional = total > 0 ? length / total : 1 / Float(polylines.count)
            return max(proportional, Look.minimumPathShare)
        }
        let shareSum = shares.reduce(0, +)
        shares = shares.map { $0 / shareSum }

        var cursor: TimeInterval = 0
        for (i, polyline) in polylines.enumerated() {
            let span = duration * Double(shares[i])
            let halo = ModelEntity()
            let ink = ModelEntity()
            ink.position = SIMD3<Float>(0, 0, Look.inkLift)
            entity.addChild(halo)
            entity.addChild(ink)
            tracks.append(Track(polyline: polyline, start: cursor, end: cursor + span, halo: halo, ink: ink))
            cursor += span
        }

        startDate = Date()
        let timer = Timer(timeInterval: Look.frameInterval, repeats: true) { [self] _ in
            self.tick(host: entity)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick(host: entity)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick(host: Entity) {
        guard let startDate = startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)

        // Host evicted from the scene (drawing cap / clear all): nothing to
        // show to anyone, stop burning frames. The parent is attached a
        // moment after `animate` is called, hence the grace period.
        if host.parent == nil && elapsed > 0.5 {
            stop()
            return
        }

        var allFinished = true
        for i in tracks.indices where !tracks[i].finished {
            let track = tracks[i]
            if elapsed < track.start {
                allFinished = false
                continue
            }
            let span = track.end - track.start
            let reveal: Float = span > 0 ? Float((elapsed - track.start) / span) : 1
            let clamped = min(max(reveal, 0), 1)
            apply(StrokeGeometry.revealedPrefix(track.polyline, reveal: clamped), to: track)
            if clamped >= 1 {
                tracks[i].finished = true
            } else {
                allFinished = false
            }
        }

        if allFinished { stop() }
    }

    private func apply(_ points: [SIMD2<Float>], to track: Track) {
        if let mesh = Self.meshResource(StrokeGeometry.ribbon(points, width: lineWidth * Look.haloWidthFactor)) {
            track.halo.model = ModelComponent(mesh: mesh, materials: [Self.haloMaterial])
        }
        if let mesh = Self.meshResource(StrokeGeometry.ribbon(points, width: lineWidth)) {
            track.ink.model = ModelComponent(mesh: mesh, materials: [Self.inkMaterial])
        }
    }

    private static func meshResource(_ mesh: StrokeGeometry.Mesh) -> MeshResource? {
        guard !mesh.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "stroke")
        descriptor.positions = MeshBuffer(mesh.positions)
        descriptor.normals = MeshBuffer(mesh.positions.map { _ in SIMD3<Float>(0, 0, 1) })
        descriptor.primitives = .triangles(mesh.indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    private static let inkMaterial: UnlitMaterial = material(Look.ink, opacity: Look.inkOpacity)
    private static let haloMaterial: UnlitMaterial = material(Look.halo, opacity: Look.haloOpacity)

    private static func material(_ color: UIColor, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        material.faceCulling = .none
        return material
    }
}
