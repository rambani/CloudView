import Foundation

/// Generates the app's personality copy — the weather-panel quip and the
/// share caption — from the current creature vocabulary, the weather trend,
/// and a deterministic seed. This replaces the old hand-written template
/// tree, which string-matched labels from the deleted procedural system
/// ("surfing", "wizard", "ice cream") and had become dead branches.
///
/// Design rules:
///  - **Keyed to real labels, with a graceful default.** Every creature in
///    the template library gets a persona; any label the engine doesn't
///    know still produces good copy from the generic forms, so future art
///    drops never dead-branch this file again.
///  - **Seeded, not random.** Copy is picked by SplitMix64 from the given
///    seed, so it's stable across re-renders and testable — and varies
///    per drawing/hour the same way drawings themselves do.
///  - **Composable.** A quip = creature line + weather line, picked
///    independently, so variety multiplies.
enum QuipEngine {

    // MARK: - Weather trend model (moved from WeatherView so it's testable)

    enum WeatherTrend {
        case rainComing
        case gettingWarmer
        case gettingColder
        case stormyComing
        case windy
        case stable
    }

    struct WeatherDetails {
        var hoursAway: Int?
        var targetTemp: Int?
        var tempChange: Int?
        var windSpeed: Int?
        var currentTemp: Int?

        init(hoursAway: Int? = nil, targetTemp: Int? = nil, tempChange: Int? = nil,
             windSpeed: Int? = nil, currentTemp: Int? = nil) {
            self.hoursAway = hoursAway
            self.targetTemp = targetTemp
            self.tempChange = tempChange
            self.windSpeed = windSpeed
            self.currentTemp = currentTemp
        }
    }

    // MARK: - Personas (current creature vocabulary)

    private struct Persona {
        let emoji: String
        /// Sighting lines about the creature itself. `%@` = display name.
        let lines: [String]
    }

    private static let personas: [String: Persona] = [
        "rabbit": Persona(emoji: "🐰", lines: [
            "A rabbit just hopped across the sky!",
            "Those ears are pure cumulus — it's a sky-bunny.",
            "A cloud rabbit is bounding overhead.",
        ]),
        "fish": Persona(emoji: "🐟", lines: [
            "A fish is swimming through the blue up there!",
            "The sky turned aquarium — one fish, drifting by.",
            "That's a fish gliding on the breeze.",
        ]),
        "cat": Persona(emoji: "🐱", lines: [
            "A cat is lounging up in the sky.",
            "Whiskers in the clouds — a sky-cat has appeared.",
            "That cloud is doing a very convincing cat nap.",
        ]),
        "bird": Persona(emoji: "🐦", lines: [
            "A bird made of cloud is riding the wind!",
            "One puffy bird, cruising the sky.",
            "The clouds grew wings — there's a bird up there.",
        ]),
        "whale": Persona(emoji: "🐋", lines: [
            "A whale is drifting through the sky-ocean!",
            "That's a sky-whale — the gentlest giant overhead.",
            "A cloud whale surfaced above you.",
        ]),
        "turtle": Persona(emoji: "🐢", lines: [
            "A turtle is taking the slow lane across the sky.",
            "A sky-turtle, in absolutely no hurry.",
            "That cloud has a shell — turtle overhead!",
        ]),
        "dragon": Persona(emoji: "🐉", lines: [
            "A dragon is coasting over the clouds!",
            "Look up — a cloud dragon is on patrol.",
            "The sky conjured a dragon just for you.",
        ]),
        "swan": Persona(emoji: "🦢", lines: [
            "A swan is gliding across the blue.",
            "One elegant sky-swan, neck to the wind.",
            "The clouds arranged themselves into a swan.",
        ]),
        "bear": Persona(emoji: "🐻", lines: [
            "A big fluffy bear is ambling across the sky!",
            "That's a cloud bear — extra cuddly today.",
            "A sky-bear wandered into view.",
        ]),
    ]

    /// Generic forms for labels without a persona — future creatures work
    /// on day one. `%@` = display name (lowercased label reads naturally).
    private static let genericLines = [
        "The sky just doodled a %@!",
        "A %@ drifted into view overhead.",
        "There's a %@ floating up there — look!",
    ]
    private static let genericEmoji = "✨"

    // MARK: - Weather lines per trend

    private static func weatherLines(for trend: WeatherTrend, details: WeatherDetails) -> [String] {
        switch trend {
        case .rainComing:
            let t = timePhrase(details.hoursAway ?? 2)
            return [
                "Catch it quick — rain rolls in \(t). ☔",
                "It might need an umbrella soon; rain \(t). 🌧️",
                "One good look before the rain \(t)! 💧",
            ]
        case .gettingWarmer:
            let target = details.targetTemp ?? 75
            return [
                "It's basking — warming up to \(target)°. ☀️",
                "Sunshine ahead: climbing to \(target)° today. 🌞",
                "Warm air rising to \(target)° — perfect sky-watching. ☀️",
            ]
        case .gettingColder:
            let target = details.targetTemp ?? 45
            return [
                "It'll want a scarf — cooling to \(target)°. 🧣",
                "Crisp air coming: dropping to \(target)°. ❄️",
                "Bundle up together — \(target)° on the way. 🧥",
            ]
        case .stormyComing:
            let t = timePhrase(details.hoursAway ?? 3)
            return [
                "It's staying ahead of the thunder \(t). ⚡",
                "Storms brew \(t) — enjoy the calm sky while it lasts. ⛈️",
                "Big weather \(t); the sky's putting on a show first. ⚡",
            ]
        case .windy:
            let wind = details.windSpeed ?? 15
            return [
                "It's surfing the breeze — winds at \(wind) mph. 💨",
                "A blustery ride today: \(wind) mph gusts. 🌬️",
                "Hold your hat — \(wind) mph winds up there. 💨",
            ]
        case .stable:
            let temp = details.currentTemp.map { "\($0)°" } ?? "lovely"
            return [
                "Perfect \(temp) sky-watching weather. ☀️",
                "Calm skies at \(temp) — it's in no rush to leave. 🌤️",
                "Steady and \(temp) — a good day to look up. ☁️",
            ]
        }
    }

    private static func timePhrase(_ hours: Int) -> String {
        hours <= 1 ? "within the hour" : "in about \(hours) hours"
    }

    // MARK: - Public API

    /// Weather-panel quip for a recognized creature: sighting line +
    /// weather line, both seeded.
    static func quip(creature: String, trend: WeatherTrend, details: WeatherDetails, seed: UInt64) -> String {
        var rng = SplitMix64(seed: seed)
        let sighting = sightingLine(for: creature, rng: &rng)
        let weatherOptions = weatherLines(for: trend, details: details)
        let weather = weatherOptions[Int(rng.next() % UInt64(weatherOptions.count))]
        return "\(sighting) \(weather)"
    }

    /// Short share-ready caption for a drawing ("The sky drew me a Dragon 🐉").
    static func caption(creature: String, seed: UInt64) -> String {
        var rng = SplitMix64(seed: seed &+ 0x51EE)
        let key = creature.lowercased()
        let emoji = personas[key]?.emoji ?? genericEmoji
        let display = displayName(for: creature)
        let forms = [
            "I found a \(display) in the clouds today \(emoji)",
            "The sky drew me a \(display) \(emoji)",
            "A \(display), spotted drifting overhead \(emoji)",
            "Cloudoodle caught a \(display) in the sky \(emoji)",
        ]
        return forms[Int(rng.next() % UInt64(forms.count))]
    }

    /// Stable per-drawing seed: same drawing + same hour → same copy (no
    /// flicker across re-renders); new hour or new drawing → fresh copy.
    static func seed(for drawingName: String, hourBucket: UInt64) -> UInt64 {
        StableHash.mix(StableHash.fnv1a(drawingName.lowercased()) ^ StableHash.mix(hourBucket))
    }

    static func currentHourBucket(now: Date = Date()) -> UInt64 {
        UInt64(max(0, now.timeIntervalSince1970) / 3600)
    }

    // MARK: - Internals

    private static func sightingLine(for creature: String, rng: inout SplitMix64) -> String {
        let key = creature.lowercased()
        if let persona = personas[key] {
            return persona.lines[Int(rng.next() % UInt64(persona.lines.count))]
        }
        let form = genericLines[Int(rng.next() % UInt64(genericLines.count))]
        return String(format: form, displayName(for: creature).lowercased())
    }

    private static func displayName(for creature: String) -> String {
        creature.trimmingCharacters(in: .whitespaces).capitalized
    }
}
