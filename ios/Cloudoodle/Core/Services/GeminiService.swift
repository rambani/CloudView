import Foundation
import UIKit

// Gemini Flash — free tier: 1,500 requests/day, 1M tokens/day
// Get an API key at: https://aistudio.google.com/app/apikey (no credit card required)
//
// Gemini does the creative work: identifies the shape AND draws it.
// It returns normalized path coordinates that trace the shape it sees in the clouds.
// Apple Vision is kept only for saliency (label placement).

enum GeminiError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case networkError(Error)
    case invalidResponse(Int, String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Google AI Studio API key in Settings. Free at aistudio.google.com"
        case .imageEncodingFailed:
            return "Couldn't encode the photo for upload."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let code, let body):
            return "Gemini returned \(code). \(body.prefix(120))"
        case .parseError(let msg):
            return "Couldn't parse the response: \(msg)"
        }
    }
}

actor GeminiService {
    static let shared = GeminiService()

    private let model = "gemini-2.0-flash"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    private var apiKey: String {
        // Production builds bake the key via Config.xcconfig → Info.plist.
        // Dev builds fall back to the Settings screen entry in UserDefaults.
        if let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        return UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    }

    /// Analyze a sky photo. Pass `cloudWaypoints` if you've already
    /// run `CloudVisionService.extractCloudWaypoints` — they ground
    /// the model in the actual cloud silhouettes. Without them, the
    /// model still produces a drawing but is freer to drift away
    /// from the real cloud edges.
    func analyzeCloud(
        image: UIImage,
        cloudWaypoints: [[Double]] = []
    ) async throws -> GeminiCloudAnalysis {
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }
        guard let imageData = image.preparedForAnalysis() else {
            throw GeminiError.imageEncodingFailed
        }

        // One quiet auto-retry on transient categories — the common
        // rate-limit and 5xx hiccups usually clear after a second. Any
        // more than one retry would erode the snappy "scan now" feel
        // of the capture flow; users would rather see the error and
        // tap again than wait 5+ seconds for repeated attempts.
        do {
            return try await callGemini(imageData: imageData, cloudWaypoints: cloudWaypoints)
        } catch let error as GeminiError where Self.isTransient(error) {
            try? await Task.sleep(for: .seconds(1))
            return try await callGemini(imageData: imageData, cloudWaypoints: cloudWaypoints)
        }
    }

    /// Mark-vocabulary analysis. Given the photo and an extracted
    /// cloud silhouette, Gemini identifies what creature the
    /// silhouette suggests and returns a list of character marks
    // The "mark vocabulary" path (analyzeWithMarks + GeminiMarkAnalysis
    // + the on-device MarkRenderer that turned semantic marks into
    // strokes) was removed when the develop flow moved fully to
    // OpenAI's image-edit. Gemini now only contributes the shape
    // metadata via analyzeCloud above; the developed image comes
    // from gpt-image-1.

    private func callGemini(
        imageData: Data,
        cloudWaypoints: [[Double]]
    ) async throws -> GeminiCloudAnalysis {
        let urlString = "\(baseURL)/\(model):generateContent"
        guard let url = URL(string: urlString) else { throw GeminiError.missingAPIKey }

        // Inject the on-device waypoints into the prompt as a
        // dedicated "anchor points" section. With them present, the
        // model can't honestly place a stroke that isn't near a real
        // cloud edge — the waypoints ARE the visible cloud edges.
        let prompt = Self.prompt + Self.waypointsSection(cloudWaypoints)

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inlineData": ["mimeType": "image/jpeg", "data": imageData.base64EncodedString()]],
                    ["text": prompt]
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                // Temperature is intentionally low. We want the model to
                // ground its strokes in the actual cloud silhouettes
                // visible in the photo — not invent shapes that don't
                // match what's there. Earlier prompts ran at 1.0 and
                // produced decorative outlines drifting in the sky;
                // 0.45 keeps Gemini grounded while still letting it
                // pick from multiple plausible shape interpretations.
                "temperature": 0.45,
                "maxOutputTokens": 2048   // three-layer drawings can run long
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Send the API key as a header instead of `?key=...` so it doesn't
        // end up in URLSession metrics, Sentry breadcrumbs, crash reports,
        // or anywhere else the request URL gets logged. Google's API
        // accepts both transports; the header form is the recommended one.
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.networkError(URLError(.badServerResponse))
        }
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.invalidResponse(http.statusCode, bodyStr)
        }

        return try parseResponse(data: data)
    }

    private func parseResponse(data: Data) throws -> GeminiCloudAnalysis {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiError.parseError("Unexpected response structure")
        }

        let jsonString = extractJSON(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.parseError("Couldn't convert response to data")
        }

        do {
            return try JSONDecoder().decode(GeminiCloudAnalysis.self, from: jsonData)
        } catch {
            throw GeminiError.parseError("Decode failed: \(error). Raw: \(jsonString.prefix(300))")
        }
    }

    private func extractJSON(from text: String) -> String {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            var lines = Array(s.components(separatedBy: "\n").dropFirst())
            if lines.last?.hasPrefix("```") == true {
                lines.removeLast()
            }
            return lines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            return String(s[start...end])
        }
        return s
    }

    /// Build the cloud-edge waypoint section that gets concatenated
    /// onto the static prompt at request time. Empty when on-device
    /// Vision didn't find a usable silhouette (very plain sky, broken
    /// image), in which case the model falls back to image-only
    /// grounding with the prompt's existing "every point must lie on
    /// a visible cloud edge" rules.
    private static func waypointsSection(_ waypoints: [[Double]]) -> String {
        guard waypoints.count >= 6 else { return "" }
        let formatted = waypoints
            .map { String(format: "[%.3f, %.3f]", $0[0], $0[1]) }
            .joined(separator: ", ")
        return """


        CLOUD EDGE WAYPOINTS (extracted from this exact photo by on-device Vision):
        [\(formatted)]

        These are normalized (x, y) points sampled along the silhouette of the most \
        prominent cloud cluster in the image. They are GROUND TRUTH for SILHOUETTE strokes only — \
        they came from the photo itself, not from your imagination.

           • SILHOUETTE strokes (Layer 1) must use these waypoints, or points interpolated \
             between two adjacent waypoints. No exceptions.
           • CHARACTER and FLOURISH strokes (Layer 2, 3) do NOT have to land on waypoints — \
             they live INSIDE the silhouette or just adjacent to it. Place them where the \
             body of the creature would logically be (eye near a head bulge, fin along a \
             belly curve, spout above a head).
           • You do NOT have to use every waypoint. Pick the subset that best forms the silhouette.
        """
    }

    // Three-layer drawing prompt — silhouette anchors to waypoints,
    // character details and flourishes give the creature life.
    //
    // Prompt design notes:
    //   • Previous iteration capped at 3-7 strokes "tracing the cloud
    //     edges." Result: tight outline but no creature character —
    //     just a blob shape. This version splits the work into three
    //     layers so character + flourish strokes are *required*, not
    //     a side effect of luck.
    //   • Hard rules listed at top + bottom because Gemini attends
    //     most to start and end of the prompt.
    //   • Temperature kept at 0.45 in the request body (low enough to
    //     trust waypoints, high enough to invent expressive details
    //     in Layers 2 + 3).
    private static let prompt = """
    You are a cloud-watcher illustrating a creature you see in the sky photo.

    Your drawing has THREE layers — all three are required:

    LAYER 1 — SILHOUETTE (1 to 2 strokes, 5 to 12 points each):
       Trace the outline of the cloud where the creature lives. These strokes are anchored \
       to the on-device cloud waypoints listed below — they MUST come from the waypoints.

    LAYER 2 — CHARACTER (2 to 4 strokes, 1 to 8 points each):
       Bring the creature alive with anatomical details placed INSIDE the silhouette area:
          • An EYE (1 point — a dot) — required, near the head
          • A defining feature: fin / wing / horn / sail / beak / ear (3-8 points)
          • Optional: mouth, smaller fin, leg, second eye
       These do not need to be on waypoints — they go where the anatomy would logically sit.

    LAYER 3 — FLOURISH (0 to 2 strokes, 1 to 6 points each, OPTIONAL):
       Small expressive marks that say "this is alive" — a breath spout above a head, \
       a tiny ripple line behind a tail, a fluff of breath. Keep them SMALL and CLEARLY \
       supporting the creature. Don't crowd the frame.

    HARD RULES — do not break these:
    1. Total strokes: 4 to 10. Total points across all strokes: 18 to 60.
    2. Layer 1 silhouette strokes must come from waypoints (when waypoints exist below).
    3. Layer 2 and Layer 3 strokes do NOT have to land on waypoints — they live inside the \
       silhouette area or just adjacent. But don't put them in obvious empty sky far from \
       the cloud.
    4. Choose ONE creature the clouds genuinely suggest. If nothing leaps out, choose \
       "Soft cumulus" with just Layer 1 + an eye in Layer 2 — no need to force a dragon.
    5. Lower watchability_score when the sky is sparse. Most photos rate 4-7. \
       Reserve 8-10 for clouds that genuinely look like a recognizable creature; \
       reserve 1-3 for plain blue sky.

    Coordinate system:
       (0,0) = top-left corner of the photo
       (1,1) = bottom-right corner

    How to think about it:
       - First, find the cloud cluster that suggests a creature.
       - Decide where the HEAD is (which end of the cluster).
       - Trace the silhouette in 1-2 strokes (Layer 1) using waypoints.
       - Place an eye dot inside the head area (Layer 2 — required).
       - Add the most distinctive feature (Layer 2 — fin / wing / sail / horn).
       - Optional: tiny breath spout or motion line (Layer 3).
       - That's the drawing. Don't add anything that doesn't help.

    Field guide:
       - shape_name: short and concrete ("Sleeping dragon", "Whale, drifting", "Sailboat at dawn").
       - cloud_type: one of Cumulus, Stratus, Cirrus, Cumulonimbus, Altocumulus, Stratocumulus.
       - weather_mood: one word, evocative ("Dreamy", "Calm", "Brooding", "Hopeful").
       - watchability_score: integer 1-10 as defined above.
       - drawing_elements: array of stroke objects, each {label, stroke_width (1.5-3.0), points}.
         Label should reflect which layer it is: "silhouette", "eye", "fin", "spout", etc.

    Respond with ONLY valid JSON of this shape. No markdown fences, no commentary:
    {"shape_name": "...", "cloud_type": "...", "weather_mood": "...",
     "watchability_score": N, "drawing_elements": [...]}

    Final reminder: A bare silhouette is a blob. An eye + a defining feature is what makes \
    it a creature. Layer 2 is not optional — every drawing needs at least an eye and one \
    other feature inside the silhouette. If you can't decide on a feature, "Soft cumulus" \
    with just an eye is the honest fallback.
    """
}

// What Gemini returns — shape identity + the drawing itself
struct GeminiCloudAnalysis: Codable {
    let shapeName: String
    let cloudType: String
    let weatherMood: String
    let watchabilityScore: Int
    let drawingElements: [GeminiDrawingElement]

    enum CodingKeys: String, CodingKey {
        case shapeName = "shape_name"
        case cloudType = "cloud_type"
        case weatherMood = "weather_mood"
        case watchabilityScore = "watchability_score"
        case drawingElements = "drawing_elements"
    }
}

struct GeminiDrawingElement: Codable {
    let label: String?
    let strokeWidth: Double?
    let points: [[Double]]

    enum CodingKeys: String, CodingKey {
        case label
        case strokeWidth = "stroke_width"
        case points
    }

    func toDrawingElement() -> CloudAnalysis.DrawingElement {
        // Clamp all coordinates to 0-1 range in case Gemini drifts slightly outside
        let clamped = points.map { pt -> [Double] in
            guard pt.count >= 2 else { return [0.5, 0.5] }
            return [max(0, min(1, pt[0])), max(0, min(1, pt[1]))]
        }
        return CloudAnalysis.DrawingElement(
            points: clamped,
            smooth: true,   // Gemini coordinates benefit from smoothing
            strokeWidth: strokeWidth ?? 2.0,
            label: label
        )
    }
}
