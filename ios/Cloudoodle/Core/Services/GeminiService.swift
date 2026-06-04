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

    func analyzeCloud(image: UIImage) async throws -> GeminiCloudAnalysis {
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
            return try await callGemini(imageData: imageData)
        } catch let error as GeminiError where Self.isTransient(error) {
            try? await Task.sleep(for: .seconds(1))
            return try await callGemini(imageData: imageData)
        }
    }

    private static func isTransient(_ error: GeminiError) -> Bool {
        if case .invalidResponse(let code, _) = error {
            return code == 429 || (500...599).contains(code)
        }
        if case .networkError = error { return true }
        return false
    }

    private func callGemini(imageData: Data) async throws -> GeminiCloudAnalysis {
        let urlString = "\(baseURL)/\(model):generateContent"
        guard let url = URL(string: urlString) else { throw GeminiError.missingAPIKey }

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inlineData": ["mimeType": "image/jpeg", "data": imageData.base64EncodedString()]],
                    ["text": Self.prompt]
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 1.0,
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

    // Ask Gemini to both identify the shape AND draw it as path coordinates.
    // Coordinates are normalized: (0,0) = top-left corner, (1,1) = bottom-right.
    // Each element is one stroke — think of it as pen-down, draw, pen-up.
    private static let prompt = """
    You are an artist who finds shapes hidden in clouds.

    Look at this sky photo. Find the most interesting shape formed by the clouds, \
    then sketch it as simple line strokes directly on the image.

    Use normalized coordinates where (0,0) is the top-left corner and (1,1) is the bottom-right. \
    Draw 3 to 7 strokes. Each stroke traces a part of the shape you actually see in the clouds — \
    follow the real cloud edges. Keep each stroke to 5–12 points.

    Example — a dragon seen in clouds:
    {
      "shape_name": "Sleeping Dragon",
      "cloud_type": "Cumulus",
      "weather_mood": "Dreamy",
      "watchability_score": 8,
      "drawing_elements": [
        {"label": "body", "stroke_width": 2.5, "points": [[0.28,0.48],[0.38,0.42],[0.50,0.40],[0.62,0.43],[0.70,0.50]]},
        {"label": "neck", "stroke_width": 2.2, "points": [[0.70,0.50],[0.76,0.43],[0.80,0.38]]},
        {"label": "head", "stroke_width": 2.0, "points": [[0.80,0.38],[0.84,0.35],[0.87,0.37],[0.85,0.41]]},
        {"label": "tail", "stroke_width": 1.8, "points": [[0.28,0.48],[0.18,0.54],[0.12,0.60],[0.10,0.68]]},
        {"label": "wing", "stroke_width": 1.6, "points": [[0.50,0.40],[0.48,0.30],[0.56,0.26],[0.60,0.32]]}
      ]
    }

    Now analyze this photo. Respond with ONLY valid JSON matching that structure. \
    watchability_score: 1 (plain blue sky) to 10 (dramatic shapes).
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
