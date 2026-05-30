import Foundation
import CoreML
import CoreVideo
import Accelerate

/// Thin Core ML wrapper for the MobileCLIP image encoder. Loads the
/// `MobileCLIP-S0.mlmodelc` shipped in the app bundle, encodes a
/// 224×224 RGB CVPixelBuffer into a unit-norm 512-dim Float embedding.
///
/// The model file is NOT in the repo (it's a 26 MB binary asset). See
/// docs/CLIP_SETUP.md. When missing, `init()` returns nil and the
/// recognition service falls back to deterministic stub picks so the
/// app still runs.
final class CLIPImageEncoder {
    private let model: MLModel

    /// Input/output feature names match Apple's published MobileCLIP
    /// Core ML export. Adjust here if you re-export with different names.
    private let inputName = "image"
    private let outputName = "image_embedding"

    init?() {
        guard let url = Bundle.main.url(
            forResource: "MobileCLIP-S0",
            withExtension: "mlmodelc"
        ) else {
            print("⚠️  MobileCLIP-S0.mlmodelc not found in bundle. " +
                  "CLIP recognition disabled; falling back to stub picks. " +
                  "See docs/CLIP_SETUP.md.")
            return nil
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all  // Let Core ML pick CPU/GPU/ANE per device

        do {
            self.model = try MLModel(contentsOf: url, configuration: config)
        } catch {
            print("⚠️  Failed to load MobileCLIP: \(error.localizedDescription)")
            return nil
        }
    }

    /// Run the CLIP image encoder. Returns an L2-normalized 512-dim vector
    /// suitable for cosine similarity against the pre-computed label
    /// embeddings.
    func encode(_ pixelBuffer: CVPixelBuffer) async throws -> [Float] {
        let inputs = try MLDictionaryFeatureProvider(dictionary: [
            inputName: MLFeatureValue(pixelBuffer: pixelBuffer)
        ])

        let prediction = try await model.prediction(from: inputs)

        guard let embedding = prediction.featureValue(for: outputName)?.multiArrayValue else {
            throw RecognitionError.invalidModelOutput(
                "Expected MLMultiArray output named '\(outputName)'"
            )
        }

        return Self.normalize(embedding)
    }

    /// L2-normalize a Core ML embedding into a Swift float array. We do
    /// this once at encode time so the matcher's cosine similarity reduces
    /// to a simple dot product.
    private static func normalize(_ array: MLMultiArray) -> [Float] {
        let count = array.count
        var values = [Float](repeating: 0, count: count)
        // Read whatever numeric type the model emits.
        switch array.dataType {
        case .float32:
            let ptr = array.dataPointer.assumingMemoryBound(to: Float.self)
            values.withUnsafeMutableBufferPointer { buf in
                buf.baseAddress!.update(from: ptr, count: count)
            }
        case .float16:
            // Read as half-floats and widen.
            for i in 0..<count {
                values[i] = array[i].floatValue
            }
        case .double:
            for i in 0..<count {
                values[i] = Float(array[i].doubleValue)
            }
        default:
            for i in 0..<count {
                values[i] = array[i].floatValue
            }
        }

        var norm: Float = 0
        vDSP_svesq(values, 1, &norm, vDSP_Length(count))
        norm = max(sqrt(norm), 1e-12)

        var divisor = norm
        vDSP_vsdiv(values, 1, &divisor, &values, 1, vDSP_Length(count))
        return values
    }
}

enum RecognitionError: Error {
    case modelMissing
    case invalidModelOutput(String)
    case renderingFailed
}
