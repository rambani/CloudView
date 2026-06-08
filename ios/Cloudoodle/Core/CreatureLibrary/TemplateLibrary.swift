import Foundation

/// Loads every JSON template under `Resources/Library/Subjects/` and
/// `Resources/Library/Props/` once at startup and caches them by id.
/// Adding a new shape is just dropping a JSON file in — no code change.
final class TemplateLibrary {
    static let shared = TemplateLibrary()

    private(set) var subjects: [String: CreatureTemplate] = [:]
    private(set) var props: [String: CreatureTemplate] = [:]

    private init() {
        subjects = Self.load(folder: "Subjects")
        props = Self.load(folder: "Props")
    }

    /// Sorted ids — useful for paging through previews + for building
    /// the prompt catalog the Gemini selector receives.
    var subjectIds: [String] { subjects.keys.sorted() }
    var propIds: [String] { props.keys.sorted() }

    /// Catalog string the Gemini prompt receives: short list of
    /// `id (category) — tag, tag, tag` entries. Kept compact so the
    /// model can scan it without spending output tokens.
    func promptCatalog() -> String {
        let subjectLines = subjectIds.compactMap { id -> String? in
            guard let t = subjects[id] else { return nil }
            let tags = (t.tags ?? []).joined(separator: ", ")
            return "  \(id) (\(t.category))\(tags.isEmpty ? "" : " — \(tags)")"
        }.joined(separator: "\n")
        let propLines = propIds.compactMap { id -> String? in
            guard let t = props[id] else { return nil }
            let tags = (t.tags ?? []).joined(separator: ", ")
            return "  \(id) (\(t.category))\(tags.isEmpty ? "" : " — \(tags)")"
        }.joined(separator: "\n")
        return """
        SUBJECTS:
        \(subjectLines)

        PROPS:
        \(propLines)
        """
    }

    /// Scan the bundle subdirectory for `*.json`, decode each one,
    /// and key by template id. Files that fail to decode are skipped
    /// silently — a malformed file shouldn't bring down the whole
    /// library; on next launch a fixed file will load cleanly.
    private static func load(folder: String) -> [String: CreatureTemplate] {
        let dir = "Library/\(folder)"
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: dir),
              !urls.isEmpty
        else { return [:] }
        var dict: [String: CreatureTemplate] = [:]
        let decoder = JSONDecoder()
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let template = try? decoder.decode(CreatureTemplate.self, from: data)
            else { continue }
            dict[template.id] = template
        }
        return dict
    }
}
