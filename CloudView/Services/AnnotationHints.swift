import Foundation
import CoreGraphics

/// Hand-authored "where to draw the eyes / mouth / fin / antenna" hints
/// per label. CLIP gives us the label; AnnotationHints gives us the
/// minimum marks to add over the cloud's silhouette to make the
/// suggestion legible. Coordinates are normalized 0–1 within the
/// cluster's bounding box.
///
/// Loaded from `Resources/AnnotationHints.json` when present. When
/// missing, recognition still works but interpretations return with no
/// annotations — the cloud's outline is the entire drawing.
///
/// The JSON is hand-authored (not generated) because "where the eyes
/// go" is a design call, not an algorithmic one. ~30 well-chosen
/// entries cover the most common returned labels; everything else
/// falls back to no annotations, which still looks fine — the cloud is
/// the drawing.
enum AnnotationHints {

    /// All hints loaded at first access. nil entry means no hints for
    /// that label; an empty array means we know there are none (i.e.
    /// the label looks fine as just the silhouette, like "moon").
    private static let library: [String: [Annotation]] = {
        guard let url = Bundle.main.url(
            forResource: "AnnotationHints",
            withExtension: "json"
        ) else {
            print("ℹ️  AnnotationHints.json not in bundle — interpretations will render as outlines only.")
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: [Annotation]].self, from: data)
        } catch {
            print("⚠️  Failed to decode AnnotationHints.json: \(error.localizedDescription)")
            return [:]
        }
    }()

    /// Returns the annotations registered for this label, or [] if none.
    /// The renderer caps total annotations per interpretation regardless
    /// of what the library says, so a too-generous entry won't ever
    /// overwhelm the cloud visually.
    static func hints(for label: String) -> [Annotation] {
        library[label.lowercased()] ?? []
    }
}
