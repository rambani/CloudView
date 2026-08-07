import XCTest
import CoreGraphics
@testable import CloudView

/// Tests for the v2 parts schema, the deterministic hash/PRNG stack, the
/// variation-seed policy, and the slot-based assembler. All pure — no bundle,
/// no AR.
final class DrawingAssemblyTests: XCTestCase {

    // MARK: - Deterministic PRNG / hashing (pinned to known vectors)

    func testSplitMix64KnownVectors() {
        var rng = SplitMix64(seed: 0)
        XCTAssertEqual(rng.next(), 0xE220A8397B1DCDAF)
        XCTAssertEqual(rng.next(), 0x6E789E6AA1B965F4)
        XCTAssertEqual(rng.next(), 0x06C45D188009454F)

        var rng42 = SplitMix64(seed: 42)
        XCTAssertEqual(rng42.next(), 0xBDD732262FEB6E95)
    }

    func testSplitMix64DoubleInUnitInterval() {
        var rng = SplitMix64(seed: 123)
        for _ in 0..<100 {
            let d = rng.nextDouble()
            XCTAssertTrue(d >= 0 && d < 1)
        }
    }

    func testFNV1aKnownVectors() {
        XCTAssertEqual(StableHash.fnv1a(""), 0xcbf29ce484222325)
        XCTAssertEqual(StableHash.fnv1a("a"), 0xaf63dc4c8601ec8c)
        XCTAssertEqual(StableHash.fnv1a("category"), 0x5bd2e7ffb1224e91)
    }

    // MARK: - Variation seed policy

    func testSeedIsDeterministicForIdenticalInputs() {
        let a = VariationSeed(cloudShapeKey: "c1", regionKey: "r1", timeBucket: 7, deviceSalt: 99)
        let b = VariationSeed(cloudShapeKey: "c1", regionKey: "r1", timeBucket: 7, deviceSalt: 99)
        for d in ["category", "orientation", "slot-pick:eye"] {
            XCTAssertEqual(a.value(for: d), b.value(for: d))
        }
    }

    func testFullStickinessMakesStrangersAgree() {
        // α = 1: two different devices at the same cloud+region see the same
        // decisions.
        let a = VariationSeed(cloudShapeKey: "c1", regionKey: "r1", timeBucket: 7, deviceSalt: 1, stickiness: 1.0)
        let b = VariationSeed(cloudShapeKey: "c1", regionKey: "r1", timeBucket: 3, deviceSalt: 2, stickiness: 1.0)
        for d in ["category", "orientation", "slot-pick:eye", "style-linewidth"] {
            XCTAssertEqual(a.value(for: d), b.value(for: d))
        }
    }

    func testZeroStickinessMakesDrawingsPersonal() {
        // α = 0: different devices diverge (16 salts, 4-way pick: the odds of
        // all agreeing by chance are ~4^-15 — effectively impossible).
        let picks = Set((1...16).map { salt in
            VariationSeed(cloudShapeKey: "c1", regionKey: "r1", timeBucket: 7, deviceSalt: UInt64(salt), stickiness: 0.0)
                .pick(count: 4, decision: "slot-pick:eye")
        })
        XCTAssertGreaterThan(picks.count, 1)
    }

    func testHalfStickinessSharesAboutHalfTheDecisions() {
        // With α = 0.5, which decisions are shared depends only on
        // (shared, decision) — so across many decisions, two viewers at the
        // same cloud should agree on roughly half. 64 decisions, expect
        // 32 ± 4σ (σ = 4): assert within [16, 48].
        let a = VariationSeed(cloudShapeKey: "c1", regionKey: "r1", timeBucket: 7, deviceSalt: 1, stickiness: 0.5)
        let b = VariationSeed(cloudShapeKey: "c1", regionKey: "r1", timeBucket: 9, deviceSalt: 2, stickiness: 0.5)
        let agreements = (0..<64).filter { a.value(for: "d\($0)") == b.value(for: "d\($0)") }.count
        XCTAssertTrue((16...48).contains(agreements), "agreed on \(agreements)/64 decisions")
    }

    func testDifferentDecisionsGetIndependentValues() {
        let seed = VariationSeed(cloudShapeKey: "c1", regionKey: "r1", timeBucket: 7, deviceSalt: 99)
        XCTAssertNotEqual(seed.value(for: "slot-pick:eye"), seed.value(for: "slot-pick:head"))
        XCTAssertNotEqual(seed.value(for: "category"), seed.value(for: "orientation"))
    }

    // MARK: - Schema v2 decode

    func testPartsLibraryFileDecodes() throws {
        let json = """
        {
          "version": 2,
          "creatures": [
            {
              "label": "dragon",
              "category": "mythical",
              "silhouette": [[0.1,0.5],[0.5,0.3],[0.9,0.5],[0.5,0.7]],
              "slots": {
                "eye": { "required": true },
                "crest": { "required": false, "probability": 0.7 }
              }
            }
          ],
          "parts": [
            {
              "id": "eye-01",
              "kind": "eye",
              "creatures": ["*"],
              "anchor": "top",
              "scale": 0.2,
              "strokes": [
                { "role": "eye", "order": 1, "closed": true, "points": [[0.4,0.5],[0.6,0.5],[0.5,0.6]] }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let file = try JSONDecoder().decode(PartsLibraryFile.self, from: json)
        XCTAssertEqual(file.version, 2)
        XCTAssertEqual(file.creatures.count, 1)
        let creature = file.creatures[0]
        XCTAssertEqual(creature.slots["eye"]?.required, true)
        XCTAssertEqual(creature.slots["crest"]?.probability ?? 0, 0.7, accuracy: 1e-9)
        let part = file.parts[0]
        XCTAssertEqual(part.anchor, .top)
        XCTAssertTrue(part.suits("dragon"))
        XCTAssertEqual(part.scale ?? 0, 0.2, accuracy: 1e-9)
    }

    // MARK: - Assembler fixtures

    /// Axis-aligned rectangle cloud (0.2, 0.3)–(0.8, 0.7). With strict
    /// comparisons in the landmark scan, top = (0.2, 0.3), right = (0.8, 0.3).
    private let cloud = [
        CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.8, y: 0.3),
        CGPoint(x: 0.8, y: 0.7), CGPoint(x: 0.2, y: 0.7),
    ]

    private func makeCreature(slots: [String: SlotSpec]) -> CreatureSpec {
        CreatureSpec(
            label: "blob",
            category: "test",
            silhouette: cloud.map { Pt($0) },
            slots: slots
        )
    }

    /// A part whose strokes are centered on local (0.5, 0.5), so the mapped
    /// centroid should land exactly on the anchor landmark.
    private func makePart(id: String, kind: String, anchor: PartAnchor, pointCount: Int = 2,
                          display: String? = nil) -> DrawingPart {
        let pts = (0..<pointCount).map { i -> Pt in
            let t = Double(i) / Double(max(pointCount - 1, 1))
            return Pt(x: 0.4 + 0.2 * t, y: 0.5)
        }
        return DrawingPart(
            id: id, kind: kind, creatures: ["*"], anchor: anchor, scale: 0.2, display: display,
            strokes: [DrawingTemplate.Stroke(role: kind, order: 1, closed: false, points: pts)]
        )
    }

    private var seed: VariationSeed {
        VariationSeed(cloudShapeKey: "c", regionKey: "r", timeBucket: 1, deviceSalt: 7)
    }

    private func centroid(_ pts: [CGPoint]) -> CGPoint {
        let n = CGFloat(pts.count)
        return CGPoint(
            x: pts.reduce(0) { $0 + $1.x } / n,
            y: pts.reduce(0) { $0 + $1.y } / n
        )
    }

    // MARK: - Assembler behavior

    func testStrongMatchBodyIsCloudContour() {
        let concept = DrawingAssembler.assemble(
            creature: makeCreature(slots: [:]), parts: [], cloudContour: cloud,
            score: 0.9, variation: seed
        )
        let body = concept.paths.first { $0.order == 0 }
        XCTAssertNotNil(body)
        XCTAssertEqual(body!.points.count, cloud.count)
        for (a, b) in zip(body!.points, cloud) {
            XCTAssertEqual(a.x, b.x, accuracy: 1e-9)
            XCTAssertEqual(a.y, b.y, accuracy: 1e-9)
        }
    }

    func testRequiredSlotIsAlwaysFilled() {
        let concept = DrawingAssembler.assemble(
            creature: makeCreature(slots: ["eye": SlotSpec(required: true, probability: nil)]),
            parts: [makePart(id: "eye-01", kind: "eye", anchor: .centroid)],
            cloudContour: cloud, score: 0.9, variation: seed
        )
        XCTAssertEqual(concept.paths.count, 2) // body + eye
    }

    func testOptionalSlotProbabilityBounds() {
        let never = DrawingAssembler.assemble(
            creature: makeCreature(slots: ["crest": SlotSpec(required: false, probability: 0.0)]),
            parts: [makePart(id: "crest-01", kind: "crest", anchor: .top)],
            cloudContour: cloud, score: 0.9, variation: seed
        )
        XCTAssertEqual(never.paths.count, 1) // body only

        let always = DrawingAssembler.assemble(
            creature: makeCreature(slots: ["crest": SlotSpec(required: false, probability: 1.0)]),
            parts: [makePart(id: "crest-01", kind: "crest", anchor: .top)],
            cloudContour: cloud, score: 0.9, variation: seed
        )
        XCTAssertEqual(always.paths.count, 2)
    }

    func testPartCenterLandsOnAnchorLandmark() {
        // flipProbability 0 → placement is exactly at the authored anchor.
        let concept = DrawingAssembler.assemble(
            creature: makeCreature(slots: ["eye": SlotSpec(required: true, probability: nil)]),
            parts: [makePart(id: "eye-01", kind: "eye", anchor: .top)],
            cloudContour: cloud, score: 0.9, variation: seed,
            flipProbability: 0.0
        )
        let eye = concept.paths.first { $0.order == 1 }
        XCTAssertNotNil(eye)
        let c = centroid(eye!.points)
        // top landmark of the rect cloud is (0.2, 0.3).
        XCTAssertEqual(c.x, 0.2, accuracy: 1e-6)
        XCTAssertEqual(c.y, 0.3, accuracy: 1e-6)
    }

    func testFlippedAssemblyMirrorsAnchors() {
        // flipProbability 1 → a left-anchored part attaches at the right
        // landmark (0.8, 0.3).
        let concept = DrawingAssembler.assemble(
            creature: makeCreature(slots: ["tail": SlotSpec(required: true, probability: nil)]),
            parts: [makePart(id: "tail-01", kind: "tail", anchor: .left)],
            cloudContour: cloud, score: 0.9, variation: seed,
            flipProbability: 1.0
        )
        let tail = concept.paths.first { $0.order == 1 }
        XCTAssertNotNil(tail)
        let c = centroid(tail!.points)
        XCTAssertEqual(c.x, 0.8, accuracy: 1e-6)
        XCTAssertEqual(c.y, 0.3, accuracy: 1e-6)
    }

    func testAssemblyIsDeterministic() {
        let creature = makeCreature(slots: [
            "eye": SlotSpec(required: true, probability: nil),
            "crest": SlotSpec(required: false, probability: 0.5),
        ])
        let parts = [
            makePart(id: "eye-01", kind: "eye", anchor: .centroid),
            makePart(id: "eye-02", kind: "eye", anchor: .centroid, pointCount: 3),
            makePart(id: "crest-01", kind: "crest", anchor: .top),
        ]
        let a = DrawingAssembler.assemble(creature: creature, parts: parts, cloudContour: cloud, score: 0.9, variation: seed)
        let b = DrawingAssembler.assemble(creature: creature, parts: parts, cloudContour: cloud, score: 0.9, variation: seed)

        XCTAssertEqual(a.paths.count, b.paths.count)
        for (pa, pb) in zip(a.paths, b.paths) {
            XCTAssertEqual(pa.order, pb.order)
            XCTAssertEqual(pa.points.count, pb.points.count)
            for (qa, qb) in zip(pa.points, pb.points) {
                XCTAssertEqual(qa.x, qb.x, accuracy: 1e-12)
                XCTAssertEqual(qa.y, qb.y, accuracy: 1e-12)
            }
        }
        XCTAssertEqual(a.style.lineWidth, b.style.lineWidth, accuracy: 1e-9)
        XCTAssertEqual(a.style.revealDuration, b.style.revealDuration, accuracy: 1e-12)
    }

    func testDifferentDevicesPickDifferentParts() {
        // 4 eye candidates, distinguishable by stroke point count; α = 0 so
        // the pick is fully personal. Across 16 device salts at least two
        // different parts must appear (all-same odds ≈ 4^-15).
        let creature = makeCreature(slots: ["eye": SlotSpec(required: true, probability: nil)])
        let parts = (0..<4).map { makePart(id: "eye-0\($0)", kind: "eye", anchor: .centroid, pointCount: $0 + 2) }

        let observed = Set((1...16).map { salt -> Int in
            let s = VariationSeed(cloudShapeKey: "c", regionKey: "r", timeBucket: 1, deviceSalt: UInt64(salt), stickiness: 0.0)
            let concept = DrawingAssembler.assemble(creature: creature, parts: parts, cloudContour: cloud, score: 0.9, variation: s)
            return concept.paths.first { $0.order == 1 }?.points.count ?? -1
        })
        XCTAssertGreaterThan(observed.count, 1)
    }

    func testPropDisplayTemplateDecoratesName() {
        // A required prop with a display template must rewrite the drawing's
        // display name — "Blob" becomes "Skateboarding Blob".
        let concept = DrawingAssembler.assemble(
            creature: makeCreature(slots: ["prop": SlotSpec(required: true, probability: nil)]),
            parts: [makePart(id: "prop-skate", kind: "prop", anchor: .bottom,
                             display: "Skateboarding {name}")],
            cloudContour: cloud, score: 0.9, variation: seed
        )
        XCTAssertEqual(concept.name, "Skateboarding Blob")

        // Without a display template the name stays the plain creature.
        let plain = DrawingAssembler.assemble(
            creature: makeCreature(slots: ["eye": SlotSpec(required: true, probability: nil)]),
            parts: [makePart(id: "eye-01", kind: "eye", anchor: .centroid)],
            cloudContour: cloud, score: 0.9, variation: seed
        )
        XCTAssertEqual(plain.name, "Blob")
    }

    func testSeededStyleStaysInBounds() {
        for salt in 1...20 {
            let s = VariationSeed(cloudShapeKey: "c", regionKey: "r", timeBucket: 1, deviceSalt: UInt64(salt))
            let style = DrawingAssembler.seededStyle(s)
            XCTAssertTrue(style.lineWidth >= 0.00255 - 1e-6 && style.lineWidth <= 0.00345 + 1e-6)
            XCTAssertTrue(style.revealDuration >= 2.2 && style.revealDuration <= 3.0)
        }
    }

    // MARK: - Library integration (v2 + v1 seams)

    func testLibraryV2MakesAssembledDrawing() {
        // Creature silhouette identical to the cloud → score 1.0, well above
        // the floor; required eye slot must appear in the result.
        let library = DrawingTemplateLibrary(
            creatures: [makeCreature(slots: ["eye": SlotSpec(required: true, probability: nil)])],
            parts: [makePart(id: "eye-01", kind: "eye", anchor: .centroid)]
        )
        let concept = library.makeDrawing(forCloudContour: cloud, variation: seed)
        XCTAssertNotNil(concept)
        XCTAssertEqual(concept?.name, "Blob")
        XCTAssertEqual(concept?.paths.count, 2)
    }

    func testLibraryV1PathStillWorksAndIsStyled() {
        let template = DrawingTemplate(
            label: "square", category: "test",
            silhouette: cloud.map { Pt($0) },
            strokes: [DrawingTemplate.Stroke(role: "eye", order: 1, closed: false,
                                             points: [Pt(x: 0.4, y: 0.5), Pt(x: 0.6, y: 0.5)])]
        )
        let library = DrawingTemplateLibrary(templates: [template])
        let concept = library.makeDrawing(forCloudContour: cloud, variation: seed)
        XCTAssertNotNil(concept)
        XCTAssertEqual(concept?.name, "Square")
        // Style is seeded, not the fixed default-only path.
        XCTAssertTrue((concept?.style.revealDuration ?? 0) >= 2.2)
    }

    func testLibraryRejectsBelowFloor() {
        // Extreme floor → no creature qualifies → nil (caller falls back).
        let library = DrawingTemplateLibrary(
            creatures: [makeCreature(slots: [:])],
            parts: [],
            confidenceFloor: 0.999999
        )
        let thinCloud = [
            CGPoint(x: 0.1, y: 0.48), CGPoint(x: 0.9, y: 0.48),
            CGPoint(x: 0.9, y: 0.52), CGPoint(x: 0.1, y: 0.52),
        ]
        XCTAssertNil(library.makeDrawing(forCloudContour: thinCloud, variation: seed))
    }
}
