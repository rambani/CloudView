import Foundation

/// Generates the app's personality copy — the weather-panel quip and the
/// share caption — from the current creature vocabulary, the weather trend,
/// and a deterministic seed.
///
/// A quip is ONE integrated thought where the creature's nature collides
/// with the weather ("The dragon had better guard its flame — rain rolls in
/// within the hour"), not a sighting sentence stapled to a forecast
/// sentence. Authored lines live in a creature × trend matrix; cells the
/// matrix doesn't cover fall back to name-aware generic lines, so any
/// future creature label produces good copy on day one — the failure mode
/// of the original template tree (dead branches keyed to deleted labels)
/// can't recur.
///
/// All picks are seeded (SplitMix64): stable across re-renders, fresh per
/// drawing and per hour, and unit-testable.
enum QuipEngine {

    // MARK: - Weather trend model

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
        /// Unit label for {wind} values. Authored lines say "{wind} mph";
        /// render() swaps the unit when the caller's locale reads km/h.
        var windUnit: String

        init(hoursAway: Int? = nil, targetTemp: Int? = nil, tempChange: Int? = nil,
             windSpeed: Int? = nil, currentTemp: Int? = nil, windUnit: String = "mph") {
            self.hoursAway = hoursAway
            self.targetTemp = targetTemp
            self.tempChange = tempChange
            self.windSpeed = windSpeed
            self.currentTemp = currentTemp
            self.windUnit = windUnit
        }
    }

    // MARK: - Emoji per creature (captions + quip suffix)

    private static let creatureEmoji: [String: String] = [
        "rabbit": "🐰", "fish": "🐟", "cat": "🐱", "bird": "🐦", "whale": "🐋",
        "turtle": "🐢", "dragon": "🐉", "swan": "🦢", "bear": "🐻",
        "elephant": "🐘", "giraffe": "🦒", "butterfly": "🦋", "octopus": "🐙",
        "dog": "🐶", "duck": "🦆", "dolphin": "🐬", "dinosaur": "🦕",
        "unicorn": "🦄", "snail": "🐌", "sailboat": "⛵",
        "wizard": "🧙", "castle": "🏰", "basketball": "🏀", "astronaut": "🧑‍🚀",
        "rocket": "🚀", "hot air balloon": "🎈", "ice cream": "🍦",
    ]
    private static let genericEmoji = "✨"

    /// Resolve a display name to its persona key. Prop-decorated names
    /// ("Skateboarding Elephant", "Wizard Cat in a Party Hat") still land on
    /// the base creature's personality — exact match first, then the longest
    /// known key contained in the name (longest so "hot air balloon" beats a
    /// hypothetical "balloon" key).
    private static func resolveKey(from name: String) -> String? {
        let lowered = name.lowercased()
        if creatureEmoji[lowered] != nil { return lowered }
        return creatureEmoji.keys
            .sorted { $0.count > $1.count }
            .first { lowered.contains($0) }
    }

    // MARK: - Authored creature × weather matrix
    //
    // Tokens: {time} (e.g. "within the hour"), {temp} (degrees number),
    // {wind} (mph number). Sparse by design — uncovered cells use the
    // generic bank below. Each line is a single integrated thought.

    private static let creatureTrendLines: [String: [WeatherTrend: [String]]] = [
        "rabbit": [
            .rainComing: ["The sky-rabbit's ears make a terrible umbrella — rain {time}.",
                          "Hop home soon, little cloud rabbit — rain {time}."],
            .gettingWarmer: ["The rabbit is stretched out in the warm air — {temp}° on the way."],
            .gettingColder: ["Good thing that rabbit is all fluff — cooling to {temp}°."],
            .stormyComing: ["The rabbit will be down its cloud burrow before the thunder {time}."],
            .windy: ["That rabbit's ears are flapping like flags — {wind} mph gusts."],
            .stable: ["Perfect hopping weather at {temp}° — the rabbit agrees."],
        ],
        "fish": [
            .rainComing: ["The sky-fish is thrilled — more water arriving {time}.",
                          "Rain {time}? For the fish, that's just the sky joining in."],
            .gettingWarmer: ["The fish found a warm current — {temp}° flowing in."],
            .gettingColder: ["The fish doesn't mind a chill — {temp}° feels like home."],
            .stormyComing: ["The fish is diving deep before the thunder {time}."],
            .windy: ["The fish is swimming upstream against {wind} mph winds."],
            .stable: ["Smooth sailing for the sky-fish — calm {temp}° waters above."],
        ],
        "cat": [
            .rainComing: ["The sky-cat has seen the rain coming {time} and is filing a complaint.",
                          "Rain {time} — the cat will pretend it meant to come inside anyway."],
            .gettingWarmer: ["The cat found the biggest sunbeam in the sky — {temp}° and rising."],
            .gettingColder: ["The cat is already curled up — smart move at {temp}°."],
            .stormyComing: ["The cat will be under the sky-sofa until the storm passes {time}."],
            .windy: ["The cat's fur is going every direction — {wind} mph gusts."],
            .stable: ["Prime napping conditions at {temp}° — the cat approves this sky."],
        ],
        "bird": [
            .rainComing: ["The cloud bird is heading for shelter — rain {time}."],
            .gettingWarmer: ["Perfect thermals for the bird — rising to {temp}°."],
            .gettingColder: ["The bird is fluffing up its cloud feathers — {temp}° incoming."],
            .stormyComing: ["All flights grounded before the thunder {time} — even cloud birds."],
            .windy: ["The bird is loving these {wind} mph tailwinds.",
                     "At {wind} mph, that bird barely has to flap."],
            .stable: ["Easy gliding at {temp}° — the bird's kind of day."],
        ],
        "whale": [
            .rainComing: ["Rain {time}? The whale will feel right at home."],
            .gettingWarmer: ["The sky-whale is basking — waters warming to {temp}°."],
            .gettingColder: ["The whale has blubber for exactly this — {temp}° ahead."],
            .stormyComing: ["The whale is sounding the deep before the storm {time}."],
            .windy: ["The whale is riding {wind} mph swells across the sky."],
            .stable: ["The whale drifts on — calm {temp}° seas up there."],
        ],
        "turtle": [
            .rainComing: ["The turtle brought its own roof — rain {time} won't bother it a bit."],
            .gettingWarmer: ["The turtle is out basking — {temp}° sunshine coming."],
            .gettingColder: ["The turtle is tucking in early — {temp}° tonight."],
            .stormyComing: ["Shell shut before the thunder {time} — turtle logic."],
            .windy: ["Good thing turtles carry a windbreak — {wind} mph gusts."],
            .stable: ["The turtle is in no hurry at a steady {temp}° — never is."],
        ],
        "dragon": [
            .rainComing: ["The dragon had better guard its flame — rain rolls in {time}.",
                          "Rain {time} — expect steam when it reaches the dragon."],
            .gettingWarmer: ["The dragon is stoking the heat — {temp}° and climbing."],
            .gettingColder: ["Even fire-breathers pull on a scarf at {temp}°."],
            .stormyComing: ["The dragon called dibs on the lightning — storms {time}."],
            .windy: ["Ideal soaring for a dragon — {wind} mph under those wings."],
            .stable: ["The dragon patrols a calm {temp}° sky — all is well."],
        ],
        "swan": [
            .rainComing: ["The swan will glide through the rain {time} without ruffling a feather."],
            .gettingWarmer: ["A graceful {temp}° afternoon coming — the swan planned it."],
            .gettingColder: ["The swan tucks its neck in at {temp}° — elegantly, of course."],
            .stormyComing: ["Even the swan makes for shore before thunder {time}."],
            .windy: ["The swan is tacking into {wind} mph winds with total poise."],
            .stable: ["Still {temp}° air, mirror-flat sky — swan weather."],
        ],
        "bear": [
            .rainComing: ["The bear can smell the rain coming {time} — den time soon."],
            .gettingWarmer: ["The bear is sprawled out for the warm-up to {temp}°."],
            .gettingColder: ["{temp}° coming — the bear calls that proper napping weather."],
            .stormyComing: ["The bear is heading for the cave before the thunder {time}."],
            .windy: ["It takes more than {wind} mph to move a cloud bear."],
            .stable: ["A big lazy {temp}° afternoon — the bear is living its best sky."],
        ],
        "elephant": [
            .rainComing: ["The elephant brought its own shower nozzle — real rain joins in {time}."],
            .gettingWarmer: ["The elephant is fanning those big ears — {temp}° on the way."],
            .windy: ["Those big ears catch the breeze — {wind} mph and flapping."],
            .stable: ["The elephant ambles across a steady {temp}° sky."],
        ],
        "giraffe": [
            .rainComing: ["The giraffe will see that rain long before we do — {time}."],
            .gettingColder: ["A neck that long needs a very long scarf — {temp}° coming."],
            .stable: ["The giraffe grazes the treetop clouds — calm {temp}° day."],
        ],
        "butterfly": [
            .rainComing: ["The butterfly needs to land before the rain {time}."],
            .gettingWarmer: ["Perfect flutter weather — warming to {temp}°."],
            .windy: ["A {wind} mph breeze — the butterfly goes wherever the sky decides."],
            .stable: ["The butterfly drifts through a gentle {temp}° afternoon."],
        ],
        "octopus": [
            .rainComing: ["Eight arms, eight umbrellas — the octopus is ready for rain {time}."],
            .windy: ["The octopus is holding on with all eight — {wind} mph gusts."],
            .stable: ["The octopus sprawls across a calm {temp}° sky."],
        ],
        "dog": [
            .rainComing: ["The sky-dog will still want its walk in the rain {time}."],
            .gettingWarmer: ["Tail wags all around — sunny and {temp}° coming."],
            .windy: ["Ears out the window — the dog loves a {wind} mph breeze."],
            .stable: ["The dog is having a great day at {temp}° — dogs always are."],
        ],
        "duck": [
            .rainComing: ["Rain {time} — perfect duck weather, obviously.",
                          "The duck ordered this rain {time} specially."],
            .gettingColder: ["Water off a duck's back, even at {temp}°."],
            .windy: ["The duck bobs along on {wind} mph gusts."],
            .stable: ["The duck paddles a calm {temp}° sky-pond."],
        ],
        "dolphin": [
            .rainComing: ["The dolphin doesn't mind getting wet — rain {time}."],
            .gettingWarmer: ["Warm seas ahead — the dolphin leaps toward {temp}°."],
            .windy: ["The dolphin is surfing the {wind} mph airstream."],
            .stable: ["The dolphin arcs through a smooth {temp}° sky."],
        ],
        "dinosaur": [
            .rainComing: ["The dinosaur has weathered worse than a little rain {time}."],
            .gettingColder: ["An ice age? No — just {temp}°. The dinosaur isn't worried."],
            .stable: ["The dinosaur browses the cloud-tops at an easy {temp}°."],
        ],
        "unicorn": [
            .rainComing: ["Rain {time} means one thing with a unicorn around: rainbows after."],
            .stormyComing: ["The unicorn plans to out-sparkle the lightning {time}."],
            .stable: ["A perfect {temp}° day — suspiciously magical, honestly."],
        ],
        "snail": [
            .rainComing: ["Rain {time}! The snail is beside itself — ideal travel weather."],
            .gettingWarmer: ["The snail picks up the pace in the warmth — a blistering {temp}°."],
            .stable: ["The snail is crossing the sky at a steady {temp}° — see you Tuesday."],
        ],
        "sailboat": [
            .rainComing: ["The sailboat is reefing in before the rain {time}."],
            .stormyComing: ["Make for harbor — storms {time}, says the sailboat."],
            .windy: ["{wind} mph winds — the sailboat is at full sail."],
            .stable: ["Becalmed at {temp}° — the sailboat drifts with the clouds."],
        ],
        "wizard": [
            .rainComing: ["The wizard summoned this rain {time} — probably just showing off."],
            .stormyComing: ["That thunder {time}? The wizard insists it isn't theirs."],
            .windy: ["A {wind} mph wind is doing dramatic things to the wizard's robes."],
            .stable: ["A suspiciously perfect {temp}° — the wizard's doing, no doubt."],
        ],
        "castle": [
            .rainComing: ["The castle has weathered a thousand storms — rain {time} is nothing."],
            .stormyComing: ["Raise the drawbridge — thunder marches in {time}."],
            .windy: ["Banners streaming at {wind} mph over the castle walls."],
            .stable: ["The castle holds the sky at a calm {temp}°."],
        ],
        "basketball": [
            .rainComing: ["Rain delay {time} — even sky basketball has one."],
            .windy: ["A {wind} mph crosswind — tricky free throws up there."],
            .stable: ["Nothing but sky — {temp}° and perfect shooting weather."],
        ],
        "astronaut": [
            .rainComing: ["The astronaut has seen storms from above — this rain {time} is cuter."],
            .gettingColder: ["A space-grade suit laughs at {temp}°."],
            .windy: ["{wind} mph? The astronaut has re-entered atmospheres windier than this."],
            .stable: ["Clear skies at {temp}° — the astronaut can see the whole neighborhood."],
        ],
        "rocket": [
            .rainComing: ["Launch scrubbed — rain moves in {time}."],
            .gettingWarmer: ["Countdown conditions: clear and climbing to {temp}°."],
            .stormyComing: ["Hold the countdown — storms {time}."],
            .stable: ["All systems go at a steady {temp}°."],
        ],
        "hot air balloon": [
            .rainComing: ["The balloon is finding a landing spot — rain {time}."],
            .windy: ["{wind} mph winds — the balloon goes wherever they decide."],
            .stable: ["Perfect ballooning at {temp}° — drifting exactly nowhere, happily."],
        ],
        "ice cream": [
            .rainComing: ["The ice cream welcomes the cooldown — rain {time}."],
            .gettingWarmer: ["Warming to {temp}° — the ice cream is officially on a deadline."],
            .gettingColder: ["Cooling to {temp}° — the ice cream can finally relax."],
            .stable: ["Holding at {temp}° — the ice cream approves of this forecast."],
        ],
    ]

    /// Name-aware fallback for creatures (or cells) the matrix doesn't
    /// cover. `{name}` = lowercased display name.
    private static func genericLines(for trend: WeatherTrend) -> [String] {
        switch trend {
        case .rainComing:
            return ["The {name} might want to borrow an umbrella — rain {time}.",
                    "Catch the {name} before the rain washes in {time}."]
        case .gettingWarmer:
            return ["The {name} is soaking up the warmth — {temp}° ahead."]
        case .gettingColder:
            return ["The {name} will want a fluffier cloud — {temp}° coming."]
        case .stormyComing:
            return ["The {name} is steering well clear of the thunder {time}."]
        case .windy:
            return ["The {name} is getting a {wind} mph push across the sky."]
        case .stable:
            return ["The {name} has settled into a steady {temp}° sky."]
        }
    }

    // MARK: - Public API

    /// One integrated creature-meets-weather quip, seeded. `creature` may be
    /// a prop-decorated display name ("Skateboarding Elephant") — the base
    /// creature's personality is resolved from it.
    static func quip(creature: String, trend: WeatherTrend, details: WeatherDetails, seed: UInt64) -> String {
        var rng = SplitMix64(seed: seed)
        let key = resolveKey(from: creature)

        let bank = key.flatMap { creatureTrendLines[$0]?[trend] } ?? genericLines(for: trend)
        let line = bank[Int(rng.next() % UInt64(bank.count))]
        let emoji = key.flatMap { creatureEmoji[$0] } ?? genericEmoji

        return render(line, creature: creature, trend: trend, details: details) + " " + emoji
    }

    /// Short share-ready caption for a drawing ("The sky drew me a
    /// Skateboarding Elephant 🐘"). Shows the full decorated name; the
    /// emoji comes from the base creature (`subject` when the caller knows
    /// it, otherwise resolved from the name).
    static func caption(creature: String, subject: String? = nil, seed: UInt64) -> String {
        var rng = SplitMix64(seed: seed &+ 0x51EE)
        let emoji = resolveKey(from: subject ?? creature).flatMap { creatureEmoji[$0] } ?? genericEmoji
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

    private static func render(_ line: String, creature: String, trend: WeatherTrend, details: WeatherDetails) -> String {
        var out = line

        if out.contains("{name}") {
            out = out.replacingOccurrences(of: "{name}", with: displayName(for: creature).lowercased())
        }
        if out.contains("{time}") {
            let fallback = trend == .stormyComing ? 3 : 2
            out = out.replacingOccurrences(of: "{time}", with: timePhrase(details.hoursAway ?? fallback))
        }
        if out.contains("{temp}") {
            let temp: Int
            switch trend {
            case .gettingWarmer: temp = details.targetTemp ?? 75
            case .gettingColder: temp = details.targetTemp ?? 45
            default:             temp = details.currentTemp ?? 70
            }
            out = out.replacingOccurrences(of: "{temp}", with: String(temp))
        }
        if out.contains("{wind}") {
            // Authored copy writes "{wind} mph"; retarget the unit before
            // filling the number so km/h locales read the right label.
            out = out.replacingOccurrences(of: "{wind} mph", with: "{wind} \(details.windUnit)")
            out = out.replacingOccurrences(of: "{wind}", with: String(details.windSpeed ?? 15))
        }
        return out
    }

    private static func timePhrase(_ hours: Int) -> String {
        hours <= 1 ? "within the hour" : "in about \(hours) hours"
    }

    private static func displayName(for creature: String) -> String {
        creature.trimmingCharacters(in: .whitespaces).capitalized
    }
}
