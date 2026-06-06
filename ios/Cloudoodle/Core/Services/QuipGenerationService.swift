import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// Generates witty cloud quips entirely on-device using Apple Foundation Models (iOS 26+).
// Falls back to curated templates on older OS versions — no API call either way.
//
// Two-layer guard for SDK availability:
//   1. `#if canImport(FoundationModels)` — only compiles the FoundationModels
//      path when the SDK is present (Xcode 26+). Older Xcode still builds.
//   2. `if #available(iOS 26.0, *)` — only runs the path when the device's
//      iOS is new enough to actually have the framework loaded.
actor QuipGenerationService {
    static let shared = QuipGenerationService()

    func generateQuip(shapeName: String, cloudType: String) async -> String {
        if let onDevice = await foundationModelsQuip(shapeName: shapeName, cloudType: cloudType) {
            return onDevice
        }
        return templateQuip(shapeName: shapeName, cloudType: cloudType)
    }

    // MARK: - On-device generation (iOS 26+)

    private func foundationModelsQuip(shapeName: String, cloudType: String) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return nil }
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You write short, witty, poetic observations about clouds.
            One sentence only. Playful but not cheesy.
            Never start with 'Look', 'This', 'A', or 'The'.
            """
        )

        let prompt = "Write one sentence about a \(cloudType) cloud that looks like a \(shapeName)."

        do {
            let response = try await session.respond(to: prompt)
            let quip = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quip.isEmpty, quip.count < 180 else { return nil }
            return quip
        } catch {
            return nil
        }
        #else
        // Pre-iOS 26 SDK — FoundationModels isn't available to link against.
        // Returning nil here makes the caller fall through to the template
        // pool, which is the desired behavior on any non-Xcode-26 build.
        return nil
        #endif
    }

    // MARK: - Template fallback (any iOS version)

    private func templateQuip(shapeName: String, cloudType: String) -> String {
        let cloud = cloudType.lowercased()
        let templates: [String] = [
            "Overhead, \(cloud) air has conspired to form the unmistakable silhouette of a \(shapeName).",
            "Nature's sculptor left a \(shapeName) in the \(cloud) sky and kept moving.",
            "\(cloud.capitalized) skies today — wearing a \(shapeName) like it has somewhere important to be.",
            "Drifting west at altitude: one \(shapeName), rendered in \(cloud) and late afternoon light.",
            "If clouds keep minutes, today's entry would simply read: \(shapeName).",
            "The \(cloud) layer overhead has committed, somewhat aggressively, to looking exactly like a \(shapeName).",
        ]
        return templates[abs(shapeName.hashValue ^ cloudType.hashValue) % templates.count]
    }
}
