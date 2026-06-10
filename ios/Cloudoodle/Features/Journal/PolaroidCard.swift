import SwiftUI

/// "Polaroid in a frame" card — the central artefact of Cloudoodle.
/// The layout mimics a real instant photo: a small white border on
/// top with the date/time stamped in old-timey style, the developed
/// photo in the middle (with an optional shape caption overlaid),
/// and a wider white border at the bottom carrying the weather
/// conditions of the moment.
///
/// Used by the daily home view (TodaysPolaroidView) and the gallery,
/// so both surfaces speak the same visual language.
struct PolaroidCard: View {
    let entry: JournalEntry
    /// When true, overlays the AI-detected shape name as a small
    /// italic caption inside the photo. Driven by the user's setting.
    var showShapeCaption: Bool = false
    /// Subtle stack-tilt for the gallery. Defaults to a hair off-axis
    /// so the card never reads as a digital tile.
    var tilt: Double = -1.2

    var body: some View {
        VStack(spacing: 0) {
            topBorder
            photoStage
            bottomBorder
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
        .shadow(color: .black.opacity(0.30), radius: 8, y: 4)
        .rotationEffect(.degrees(tilt))
        // VoiceOver: collapse the whole card into a single sentence
        // a screen reader can speak. Individual text labels would
        // otherwise speak in geometry order (date, day, time, temp,
        // conditions) which scans badly.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = ["Polaroid"]
        if !entry.shapeName.isEmpty {
            parts.append("of \(entry.shapeName.lowercased())")
        }
        parts.append("captured \(dateStamp.lowercased()) at \(timeStamp)")
        if let temp = entry.temperatureF {
            parts.append("\(temp) degrees, \(entry.conditionsSummary)")
        } else {
            parts.append(entry.conditionsSummary)
        }
        if let city = entry.city, !city.isEmpty {
            parts.append("in \(city)")
        }
        var description = parts.joined(separator: ", ") + "."
        if !entry.quip.isEmpty {
            description += " \(entry.quip)"
        }
        return description
    }

    // MARK: - Top border: date + time, old-timey stamp

    /// Real Polaroid prints had an embossed or handwritten date in
    /// the top-right (and on the SX-70, pre-printed serif numerals).
    /// We split the difference: serif italic day-of-week on the
    /// left, monospaced numeric stamp on the right, both in faded
    /// ink so they read as a print rather than a UI label.
    private var topBorder: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dayOfWeek)
                .font(.system(size: 10, weight: .regular, design: .serif))
                .italic()
                .tracking(1.5)
                .foregroundStyle(.black.opacity(0.55))
            Spacer(minLength: 6)
            Text(dateStamp)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(.black.opacity(0.6))
            Text("·")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
            Text(timeStamp)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(.black.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Photo stage

    /// Renders the developed image (or original as fallback) with a
    /// soft vignette + optional shape caption. The aspect is square
    /// to match the develop crop and the classic Polaroid film frame.
    @ViewBuilder
    private var photoStage: some View {
        ZStack {
            if let developedImage {
                Image(uiImage: developedImage)
                    .resizable()
                    .scaledToFill()
            } else if let originalImage {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.9)
            }

            // Subtle vignette so the photo reads as a physical print
            RadialGradient(
                colors: [.black.opacity(0), .black.opacity(0.18)],
                center: .center, startRadius: 80, endRadius: 280
            )
            .allowsHitTesting(false)

            if showShapeCaption, !entry.shapeName.isEmpty {
                shapeCaption
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }

    /// Faint italic caption tucked into the lower-left of the photo
    /// area. Sized small so it never competes with the cloud subject.
    private var shapeCaption: some View {
        VStack {
            Spacer()
            HStack {
                Text(entry.shapeName.lowercased())
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Bottom border: weather

    /// The big white margin of a Polaroid where people used to write
    /// notes in pen. We print the moment's weather there: temperature
    /// as the headline number, a short italic conditions line, and —
    /// when present — the quip, the one-liner tying the shape to the
    /// day's weather ("Better find shelter, dragon — rain in 30").
    /// The quip IS the handwritten-note feel; it gets the most
    /// character-rich treatment of the three lines.
    private var bottomBorder: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                temperatureLine
                conditionsLine
                if !entry.quip.isEmpty {
                    Text(entry.quip)
                        .font(.system(size: 12.5, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.black.opacity(0.68))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(minHeight: 64)
    }

    @ViewBuilder
    private var temperatureLine: some View {
        if let temp = entry.temperatureF {
            Text("\(temp)°")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(.black.opacity(0.78))
        } else {
            Text("—")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(.black.opacity(0.4))
        }
    }

    private var conditionsLine: some View {
        Text(conditionsString)
            .font(.system(size: 12, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(.black.opacity(0.55))
            .lineLimit(1)
    }

    private var conditionsString: String {
        var parts: [String] = [entry.conditionsSummary]
        if let city = entry.city, !city.isEmpty { parts.append(city) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Derived

    private var originalImage: UIImage? {
        UIImage(data: entry.originalImageData)
    }

    private var developedImage: UIImage? {
        entry.developedImageData.flatMap(UIImage.init(data:))
    }

    private var dayOfWeek: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: entry.createdAt).uppercased()
    }

    private var dateStamp: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: entry.createdAt).uppercased()
    }

    private var timeStamp: String {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f.string(from: entry.createdAt).lowercased()
    }
}
