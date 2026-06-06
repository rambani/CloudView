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

    private static func isTransient(_ error: GeminiError) -> Bool {
        if case .invalidResponse(let code, _) = error {
            return code == 429 || (500...599).contains(code)
        }
        if case .networkError = error { return true }
        return false
    }

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
                "maxOutputTokens": 1024   // more tokens needed for path data
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
        prominent cloud cluster in the image. They are GROUND TRUTH — they came from \
        the photo itself, not from your imagination. Anchor your strokes to these waypoints:

           • Each stroke point you output must sit on or very near one of these waypoints, \
             OR on the straight line interpolating between two adjacent waypoints.
           • If you find yourself wanting to place a point far from every waypoint, the \
             clouds are not there. Don't do it.
           • You do NOT have to use every waypoint. Pick the subset that best forms your shape.
           • You may pick waypoints from anywhere in the list, not just consecutive ones.
        """
    }

    // Ask Gemini to both identify the shape AND draw it as path coordinates.
    // Coordinates are normalized: (0,0) = top-left corner, (1,1) = bottom-right.
    // Each element is one stroke — think of it as pen-down, draw, pen-up.
    //
    // Prompt design notes:
    //   • The earlier version included a worked example with concrete
    //     (arbitrary) coordinates. That taught the model to *invent*
    //     coordinates rather than read them from the image. We removed
    //     the numeric example and replaced it with verbal guidance.
    //   • Hard rules are listed twice (top + bottom) because Gemini
    //     attends most to the start and end of the prompt. The middle
    //     section explains the "why" so the rules feel motivated.
    //   • Temperature is also dropped (0.45 in the request body) so
    //     the model commits to one plausible reading instead of
    //     fanning across several creative reinterpretations.
    private static let prompt = """
    You are a cloud-watcher tracing a shape onto the real sky photo you are looking at.

    HARD RULES — do not break these:
    1. Every point you output must land on a visible cloud edge in the photo.
       Do not invent decorative details that are not present in the image.
    2. Choose ONE shape the clouds genuinely suggest. If nothing leaps out, \
       outline the largest single cloud and call it "Soft cumulus" (or similar).
    3. Output 3 to 7 strokes; each stroke is 5 to 12 points.
    4. Strokes should sit ON the clouds, not in the empty sky. \
       If you place a point and the spot is blue sky, move it onto a nearby cloud edge instead.
    5. Lower watchability_score when the sky is sparse. Most photos rate 4-7. \
       Reserve 8-10 for clouds that genuinely look like a recognizable creature; \
       reserve 1-3 for plain blue sky.

    Coordinate system:
       (0,0) = top-left corner of the photo
       (1,1) = bottom-right corner

    How to draw:
       - First, find the cloud (or cloud cluster) in the photo that most clearly suggests a shape.
       - Note where its bright edges are in normalized coordinates.
       - Start with the LONGEST anatomical feature (the body / spine / main mass).
       - Add supporting strokes that hug the actual cloud silhouette \
         (a wing along an actual bulge, a tail tracing an actual wisp).
       - Each stroke point should lie on the bright cloud / dim sky boundary you can see.

    Field guide:
       - shape_name: short and concrete ("Sleeping dragon", "Whale, drifting", "Sailboat at dawn").
       - cloud_type: one of Cumulus, Stratus, Cirrus, Cumulonimbus, Altocumulus, Stratocumulus.
       - weather_mood: one word, evocative ("Dreamy", "Calm", "Brooding", "Hopeful").
       - watchability_score: integer 1-10 as defined above.
       - drawing_elements: array of stroke objects, each {label, stroke_width (1.5-3.0), points}.

    Respond with ONLY valid JSON of this shape. No markdown fences, no commentary:
    {"shape_name": "...", "cloud_type": "...", "weather_mood": "...",
     "watchability_score": N, "drawing_elements": [...]}

    Final reminder: each point must lie on a real cloud edge in this specific photo. \
    If you can't see a clear shape, trace the silhouette of the biggest cloud — \
    that is always more honest than inventing a creature that isn't there.
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
