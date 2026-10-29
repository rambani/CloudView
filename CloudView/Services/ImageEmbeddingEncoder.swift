import Foundation
import CoreML
import CoreVideo
import Accelerate

/// Thin Core ML wrapper for a contrastive image encoder (SigLIP 2, OpenAI
/// CLIP, …) exported by `tools/convert_recognition_model.py`. Encodes a
/// 224×224 RGB CVPixelBuffer into a unit-norm Float embedding that the
/// `LabelEmbeddingMatcher` compares against text embeddings of the kid-safe
/// labels.
///
/// Model-agnostic on purpose: the model is a ~90 MB asset that is NOT in
/// git and may be swapped. It is found as `CloudEmbedder.mlmodelc`, either
/// in the main bundle or — preferably — as an On-Demand Resource tagged
/// `recognition-model`, downloaded on first use by `load()`. Nothing here
/// assumes a particular dimensionality; the matcher checks that the text
/// side agrees.
///
/// Licensing matters here: Apple's MobileCLIP and FastVLM weights are
/// research-only and cannot ship in a product. See docs/CLIP_SETUP.md.
final class ImageEmbeddingEncoder {
    static let resourceName = "CloudEmbedder"
    static let onDemandTag = "recognition-model"
    static let inputName = "image"
    static let outputName = "embedding"

    private let model: MLModel
    let dimension: Int

    private init(model: MLModel) {
        self.model = model
        let out = model.modelDescription.outputDescriptionsByName[Self.outputName]
        self.dimension = out?.multiArrayConstraint?.shape.last?.intValue ?? 0
    }

    /// Synchronous load from the main bundle only (no download). Nil when
    /// the asset isn't there — the caller treats recognition as off.
    convenience init?() {
        guard let url = Bundle.main.url(forResource: Self.resourceName, withExtension: "mlmodelc") else {
            return nil
        }
        guard let model = Self.loadModel(at: url) else { return nil }
        self.init(model: model)
    }

    /// Load from the bundle, or fetch the On-Demand Resource first. Returns
    /// nil (and logs once) when neither works; never throws into the UI.
    static func load() async -> ImageEmbeddingEncoder? {
        if let encoder = ImageEmbeddingEncoder() { return encoder }

        let request = NSBundleResourceRequest(tags: [onDemandTag])
        do {
            try await request.beginAccessingResources()
        } catch {
            print("ℹ️  Recognition model not available (\(error.localizedDescription)). " +
                  "Shape matching only — see docs/CLIP_SETUP.md.")
            return nil
        }
        // Keep the request alive for the app's lifetime so the OS doesn't
        // purge the asset mid-session.
        retainedRequests.append(request)

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mlmodelc"),
              let model = loadModel(at: url)
        else {
            print("ℹ️  Recognition model ODR tag '\(onDemandTag)' has no \(resourceName).mlmodelc.")
            return nil
        }
        return ImageEmbeddingEncoder(model: model)
    }

    private static var retainedRequests: [NSBundleResourceRequest] = []

    private static func loadModel(at url: URL) -> MLModel? {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        do {
            return try MLModel(contentsOf: url, configuration: config)
        } catch {
            print("⚠️  Failed to load \(resourceName): \(error.localizedDescription)")
            return nil
        }
    }

    /// Encode an image into an L2-normalized embedding (cosine similarity
    /// then reduces to a dot product in the matcher).
    func encode(_ pixelBuffer: CVPixelBuffer) async throws -> [Float] {
        let inputs = try MLDictionaryFeatureProvider(dictionary: [
            Self.inputName: MLFeatureValue(pixelBuffer: pixelBuffer)
        ])
        let prediction = try model.prediction(from: inputs)
        guard let embedding = prediction.featureValue(for: Self.outputName)?.multiArrayValue else {
            throw RecognitionError.invalidModelOutput("Expected MLMultiArray output named '\(Self.outputName)'")
        }
        return Self.normalize(embedding)
    }

    static func normalize(_ array: MLMultiArray) -> [Float] {
        let count = array.count
        var values = [Float](repeating: 0, count: count)
        switch array.dataType {
        case .float32:
            let ptr = array.dataPointer.assumingMemoryBound(to: Float.self)
            values.withUnsafeMutableBufferPointer { buf in
                buf.baseAddress!.update(from: ptr, count: count)
            }
        default:
            for i in 0..<count { values[i] = array[i].floatValue }
        }
        return normalize(values)
    }

    static func normalize(_ values: [Float]) -> [Float] {
        var values = values
        var norm: Float = 0
        vDSP_svesq(values, 1, &norm, vDSP_Length(values.count))
        norm = max(sqrt(norm), 1e-12)
        var divisor = norm
        vDSP_vsdiv(values, 1, &divisor, &values, 1, vDSP_Length(values.count))
        return values
    }
}

enum RecognitionError: Error {
    case modelMissing
    case invalidModelOutput(String)
    case renderingFailed
}
