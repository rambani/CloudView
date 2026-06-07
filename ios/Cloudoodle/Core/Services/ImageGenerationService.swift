import Foundation
import UIKit

enum ImageGenerationError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case networkError(Error)
    case invalidResponse(Int, String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenAI API key in Settings to develop with AI. Get one at platform.openai.com/api-keys."
        case .imageEncodingFailed:
            return "Couldn't encode the photo for upload."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let code, let body):
            switch code {
            case 401, 403: return "OpenAI rejected the request — your API key may be invalid."
            case 429:      return "OpenAI rate-limited the request. Try again in a few seconds."
            case 500...599: return "OpenAI is having a moment. Try again in a sec."
            default:       return "OpenAI returned an error (\(code)). \(body.prefix(120))"
            }
        case .parseError(let msg):
            return "Couldn't parse the response: \(msg)"
        }
    }
}

/// Image-to-image generation via OpenAI's gpt-image-1 model.
/// Takes a cloud photo, returns a new image where minimal white
/// ink-line work has been added to emphasize creature shapes the
/// clouds already suggest.
///
/// This is the "develop with AI" path — explicitly opt-in per scan
/// (the cheap mark-vocab preview runs first, this only runs on the
/// user's deliberate tap) so per-scan cost is capped.
actor ImageGenerationService {
    static let shared = ImageGenerationService()

    private let endpoint = URL(string: "https://api.openai.com/v1/images/edits")!
    private let model = "gpt-image-1"

    private var apiKey: String {
        // Production builds bake the key via Config.xcconfig → Info.plist.
        // Dev builds fall back to the Settings screen entry in UserDefaults.
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.isEmpty, !key.hasPrefix("$(") {
            return key
        }
        return UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }

    /// "Develop" a cloud photo. The returned image keeps the photo
    /// background intact and adds minimal white ink line-art that
    /// traces what the cloud shapes already suggest.
    ///
    /// `crop` is the smart-cropped region (square, 1024×1024) — we
    /// send the crop instead of the full photo to (a) keep within
    /// the API's image-size budget and (b) focus the model's
    /// attention on the most shape-suggestive cloud area.
    func develop(crop: UIImage) async throws -> Data {
        guard !apiKey.isEmpty else { throw ImageGenerationError.missingAPIKey }
        // gpt-image-1 expects PNG input
        guard let pngData = crop.pngData() else {
            throw ImageGenerationError.imageEncodingFailed
        }
        let request = try buildRequest(pngData: pngData)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ImageGenerationError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ImageGenerationError.networkError(URLError(.badServerResponse))
        }
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw ImageGenerationError.invalidResponse(http.statusCode, bodyStr)
        }
        return try parseResponse(data: data)
    }

    // MARK: - Request building

    private func buildRequest(pngData: Data) throws -> URLRequest {
        let boundary = "Cloudoodle-\(UUID().uuidString)"
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.multipartBody(
            boundary: boundary,
            fields: [
                "model": model,
                "prompt": Self.prompt,
                "n": "1",
                "size": "1024x1024",
                "input_fidelity": "high"  // preserve the original photo as much as possible
            ],
            imageField: ("image", "cloud.png", "image/png", pngData)
        )
        return req
    }

    private static func multipartBody(
        boundary: String,
        fields: [String: String],
        imageField: (name: String, filename: String, mime: String, data: Data)
    ) -> Data {
        var body = Data()
        func appendString(_ s: String) {
            if let d = s.data(using: .utf8) { body.append(d) }
        }
        for (key, value) in fields {
            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            appendString("\(value)\r\n")
        }
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(imageField.name)\"; filename=\"\(imageField.filename)\"\r\n")
        appendString("Content-Type: \(imageField.mime)\r\n\r\n")
        body.append(imageField.data)
        appendString("\r\n--\(boundary)--\r\n")
        return body
    }

    // MARK: - Response parsing

    private func parseResponse(data: Data) throws -> Data {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = root["data"] as? [[String: Any]],
            let first = items.first,
            let b64 = first["b64_json"] as? String
        else {
            throw ImageGenerationError.parseError("Unexpected response structure")
        }
        guard let imgData = Data(base64Encoded: b64) else {
            throw ImageGenerationError.parseError("Couldn't decode base64 image")
        }
        return imgData
    }

    // MARK: - Prompt

    /// The system prompt that defines the cloudoodle aesthetic. We
    /// want the model to *emphasize* the patterns already present in
    /// the clouds, not draw new shapes on top.
    private static let prompt = """
    Look at this cloud photo carefully. Find shapes the clouds ALREADY suggest \
    on their own — a bump that already reads as a head, a curve that already \
    reads as a wing, a vertical lobe that already reads as a castle turret. \
    Not what you'd like to draw on them, but what the cloud forms genuinely look like.

    Add minimal white ink line-art that TRACES those existing patterns. Every \
    line follows a real cloud edge. An eye dot lives on a cloud-bump that \
    already looks like a head. A wing line runs along a cloud-edge that \
    already has a wing-curve. A tail follows an existing cloud wisp.

    The viewer should look at the result and say "oh yes — I see it now", as \
    if you helped them notice what was already there. Not "someone drew that \
    on top."

    Style:
       • Delicate single-weight white ink. Like a careful architectural pencil \
         sketch in white.
       • No fills, no cross-hatching, no shading.
       • Use as FEW lines as possible. Less is more.
       • Keep the photo's clouds, sky, colors entirely intact. The ink is the \
         only addition.
       • Pick 1-3 creatures or structures, no more. A cluttered sky kills \
         the illusion.

    Return the photo with the ink overlay applied. Do not change anything \
    else about the image.
    """
}
