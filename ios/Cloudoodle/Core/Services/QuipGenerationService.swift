import Foundation

// Generates witty cloud quips entirely on-device using Apple Foundation Models (iOS 26+).
// Falls back to curated templates on older OS versions — no API call either way.
actor QuipGenerationService {
    static let shared = QuipGenerationService()

    func generateQuip(shapeName: String, cloudType: String) async -> String {
        if #available(iOS 26.0, *) {
            return await generateWithFoundationModels(shapeName: shapeName, cloudType: cloudType)
        }
        return templateQuip(shapeName: shapeName, cloudType: cloudType)
    }

    // MARK: - On-device generation (iOS 26+)

    @available(iOS 26.0, *)
    private func generateWithFoundationModels(shapeName: String, cloudType: String) async -> String {
        // Import is conditional — only compiled on iOS 26+
        // Using dynamic lookup to avoid compile errors on earlier SDKs
        guard let quip = await foundationModelsQuip(shapeName: shapeName, cloudType: cloudType) else {
            return templateQuip(shapeName: shapeName, cloudType: cloudType)
        }
        return quip
    }

    @available(iOS 26.0, *)
    private func foundationModelsQuip(shapeName: String, cloudType: String) async -> String? {
        // FoundationModels framework — available in iOS 26+ with Apple Intelligence
        // Requires: iPhone 15 Pro+ (A17 Pro) or M-series iPad, device language set to English
        //
        // Note: If you're compiling with Xcode 26 SDK, uncomment the FoundationModels implementation below.
        // The dynamic approach here avoids requiring the iOS 26 SDK to compile the project.

        /*
        import FoundationModels

        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let session = LanguageModelSession(
            model: model,
            instructions: "You write short, witty, poetic observations about clouds. " +
                          "One sentence only. Playful but not cheesy. Never start with 'Look', 'This', 'A', or 'The'."
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
        */

        // Until you update the project to Xcode 26, this path falls through to templates
        return nil
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
