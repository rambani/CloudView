import Foundation
import CoreGraphics

// MARK: - Deterministic hashing & PRNG
//
// Swift's `hashValue` is salted per process launch, so it can never seed
// reproducible drawings. Everything here is fixed-algorithm and pinned by
// unit tests to known vectors.

enum StableHash {
    /// FNV-1a 64-bit over UTF-8 bytes.
    static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return h
    }

    /// SplitMix64 finalizer — a strong 64-bit avalanche mix.
    static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    static func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
        (x << (k & 63)) | (x >> (64 - (k & 63)))
    }
}

/// SplitMix64 sequence generator — tiny, fast, and identical on every
/// platform/run for a given seed.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1) with 53 bits of precision.
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }
}

// MARK: - Variation seed

/// The seed policy from docs/GENERATIVE_DRAWING_DESIGN.md:
///
///   shared   = hash(cloud shape bucket, region bucket)   — what strangers at
///                                                          the same cloud share
///   personal = hash(device salt, time bucket)            — what makes a scan
///                                                          yours, and fresh
///
/// Each named decision ("category", "slot-pick:head", …) draws its value from
/// the shared stream with probability `stickiness` (α), else the personal
/// one. Which stream drives a given decision depends only on (shared,
/// decision) — so everyone at the same cloud *agrees* on which aspects they
/// share, and those aspects come out identical for all of them, while the
/// rest differ per person and per time bucket.
///
/// Same inputs → identical drawing: reproducible, testable, shareable.
struct VariationSeed {
    let shared: UInt64
    let personal: UInt64
    /// α ∈ [0, 1]: 1 = everyone at a cloud sees the same drawing;
    /// 0 = always personal/fresh.
    let stickiness: Double

    static let defaultStickiness = 0.5

    init(
        cloudShapeKey: String,
        regionKey: String,
        timeBucket: UInt64,
        deviceSalt: UInt64,
        stickiness: Double = VariationSeed.defaultStickiness
    ) {
        self.init(
            shared: StableHash.mix(StableHash.fnv1a(cloudShapeKey) ^ StableHash.rotl(StableHash.fnv1a(regionKey), 31)),
            personal: StableHash.mix(deviceSalt ^ StableHash.rotl(StableHash.mix(timeBucket), 17)),
            stickiness: stickiness
        )
    }

    /// Direct seam for tests.
    init(shared: UInt64, personal: UInt64, stickiness: Double = VariationSeed.defaultStickiness) {
        self.shared = shared
        self.personal = personal
        self.stickiness = min(max(stickiness, 0), 1)
    }

    /// Deterministic 64-bit value for a named decision.
    func value(for decision: String) -> UInt64 {
        let d = StableHash.fnv1a(decision)
        // Stream selection depends only on (shared, decision) so co-located
        // viewers agree on which decisions are shared-driven.
        let selector = StableHash.mix((shared ^ d) &+ 0x632BE59BD9B4E019)
        let u = Double(selector >> 11) * 0x1.0p-53
        let base = u < stickiness ? shared : personal
        return StableHash.mix(base ^ StableHash.rotl(d, 17))
    }

    /// Uniform [0, 1) for a named decision.
    func double(for decision: String) -> Double {
        Double(value(for: decision) >> 11) * 0x1.0p-53
    }

    /// Uniform pick in 0..<count (0 when count ≤ 0).
    func pick(count: Int, decision: String) -> Int {
        guard count > 0 else { return 0 }
        return Int(value(for: decision) % UInt64(count))
    }

    func chance(_ p: Double, decision: String) -> Bool {
        double(for: decision) < p
    }
}

// MARK: - Assembler

/// Assembles a `DrawingConcept` from a v2 creature + parts library: the cloud
/// (or warped silhouette) as the body, then one part per slot — selected,
/// included, flipped, and styled deterministically by the `VariationSeed` —
/// each placed at its cloud landmark. Pure and fully unit-testable.
enum DrawingAssembler {

    /// Part extent as a fraction of the cloud's shorter bounding-box side,
    /// when the part doesn't specify its own.
    static let defaultPartScale = 0.35

    /// Inclusion probability for optional slots that don't specify one.
    static let defaultOptionalProbability = 0.5

    /// Probability the whole assembly is mirrored horizontally. Parameterized
    /// so tests can pin it to 0 or 1.
    static let defaultFlipProbability = 0.5

    static func assemble(
        creature: CreatureSpec,
        parts: [DrawingPart],
        cloudContour: [CGPoint],
        score: Double,
        variation: VariationSeed,
        strongMatchThreshold: Double = TemplateDrawingComposer.defaultStrongThreshold,
        flipProbability: Double = DrawingAssembler.defaultFlipProbability
    ) -> DrawingConcept {
        let landmarks = CloudLandmarks.richReferencePoints(cloudContour)
        let bbox = boundingBox(of: cloudContour)

        var paths: [DrawingConcept.DrawingPath] = []

        // Body (order 0): hybrid by confidence, same rule as the v1 composer —
        // the cloud's own outline when the resemblance is strong, the warped
        // creature silhouette when it's loose.
        if score >= strongMatchThreshold {
            if cloudContour.count >= 2 {
                paths.append(DrawingConcept.DrawingPath(points: cloudContour, closed: true, order: 0))
            }
        } else {
            let warp = TemplateWarp.fit(
                templateContour: creature.silhouette.cgPoints,
                cloudContour: cloudContour
            )
            let body = warp.apply(creature.silhouette.cgPoints)
            if body.count >= 2 {
                paths.append(DrawingConcept.DrawingPath(points: body, closed: true, order: 0))
            }
        }

        let flipped = variation.chance(flipProbability, decision: "orientation")

        // Fill slots in sorted-key order so assembly is order-deterministic.
        var order = 1
        for slotKind in creature.slots.keys.sorted() {
            guard let spec = creature.slots[slotKind] else { continue }

            if !spec.required {
                let p = spec.probability ?? defaultOptionalProbability
                guard variation.chance(p, decision: "slot-include:\(slotKind)") else { continue }
            }

            // Candidates sorted by id: selection index → part is stable
            // regardless of the JSON's array order.
            let candidates = parts
                .filter { $0.kind == slotKind && $0.suits(creature.label) }
                .sorted { $0.id < $1.id }
            guard !candidates.isEmpty else { continue }

            let part = candidates[variation.pick(count: candidates.count, decision: "slot-pick:\(slotKind)")]

            let anchor = flipped ? part.anchor.mirrored : part.anchor
            let anchorPoint = anchor.point(in: landmarks)
            let extent = CGFloat(part.scale ?? defaultPartScale) * min(bbox.width, bbox.height)

            for stroke in part.strokes.sorted(by: { $0.order < $1.order }) {
                let pts: [CGPoint] = stroke.points.map { p in
                    let lx = flipped ? 1 - p.x : p.x
                    return CGPoint(
                        x: anchorPoint.x + (CGFloat(lx) - 0.5) * extent,
                        y: anchorPoint.y + (CGFloat(p.y) - 0.5) * extent
                    )
                }
                guard pts.count >= 2 else { continue }
                paths.append(DrawingConcept.DrawingPath(points: pts, closed: stroke.closed, order: order))
                order += 1
            }
        }

        return DrawingConcept(
            name: creature.label.capitalized,
            paths: paths,
            preferredShape: nil,
            style: seededStyle(variation)
        )
    }

    /// Seeded stroke/animation style, shared by the v1 and v2 paths: line
    /// weight ±15% around the classic 3 mm, reveal duration 2.2–3.0 s.
    static func seededStyle(_ variation: VariationSeed) -> DrawingConcept.Style {
        var style = DrawingConcept.Style()
        style.lineWidth = Float(0.003 * (0.85 + 0.30 * variation.double(for: "style-linewidth")))
        style.revealDuration = 2.2 + 0.8 * variation.double(for: "style-duration")
        return style
    }

    static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
