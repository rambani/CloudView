import Foundation

/// Returns 5 alternative interpretations of a cloud cluster. The caller
/// picks one at random to render, preserving the "5 viewers, 5 different
/// answers" property called out in docs/RECOGNITION.md.
///
/// Implementations are tiered for cost. Today only the stub is wired up.
/// Phase 1 adds the backend-cache implementation; Phase 3 adds the
/// on-device tier. Both will conform to this same protocol; the call
/// sites don't change.
protocol CloudRecognitionService {
    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation]
}

/// Cost-tiered orchestrator. Tries the on-device tier first, falls back
/// to the backend on low confidence. Today both backing services are
/// stubs; the abstraction is what we need now so the rest of the iOS
/// pipeline can flow end-to-end before Phase 1 wires the vision model.
final class TieredCloudRecognitionService: CloudRecognitionService {
    static let shared = TieredCloudRecognitionService()

    private let onDevice: CloudRecognitionService
    private let backend: CloudRecognitionService

    init(
        onDevice: CloudRecognitionService = StubCloudRecognitionService(),
        backend: CloudRecognitionService = StubCloudRecognitionService()
    ) {
        self.onDevice = onDevice
        self.backend = backend
    }

    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation] {
        // Tier 1: on-device match.
        let local = try await onDevice.recognize(cluster)
        if let best = local.first, best.confidence >= 0.6 {
            return local
        }
        // Tier 2/3: backend. The backend itself handles cache vs.
        // vision-model internally — we don't see the difference.
        return try await backend.recognize(cluster)
    }
}

/// Phase 0 stub. Returns a deterministic, seeded-by-signature set of
/// interpretations so the iOS pipeline can run end-to-end without any
/// network call. Replaced in Phase 1 by the backend-backed implementation.
final class StubCloudRecognitionService: CloudRecognitionService {
    func recognize(_ cluster: CloudCluster) async throws -> [Interpretation] {
        // Seed by signature so the same cloud always returns the same five.
        // The renderer picks one at random per scan, so the user still gets
        // variety per re-scan; the determinism here is just so dev/test
        // doesn't flap.
        let bank: [(String, Double)] = [
            ("turtle", 0.55), ("dragon", 0.55), ("rabbit", 0.55),
            ("cat", 0.55), ("whale", 0.55), ("dolphin", 0.55),
            ("rocket", 0.55), ("castle", 0.55), ("dog", 0.55),
            ("penguin", 0.55), ("unicorn", 0.55), ("bear", 0.55),
        ]

        let hash = abs(cluster.signature.cacheKey.hashValue)
        var picks: [(String, Double)] = []
        var i = hash
        for _ in 0..<5 {
            picks.append(bank[i % bank.count])
            i /= bank.count + 1  // step pseudo-randomly through the bank
            if i == 0 { i = hash &* 31 + 7 }
        }

        return picks.map { label, conf in
            Interpretation(label: label, confidence: conf, annotations: [])
        }
    }
}
