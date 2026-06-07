import SwiftUI

/// Static "Polaroid in a frame" card — used by both the post-
/// develop reveal and the journal gallery. The reveal view animates
/// in / shakes / cross-fades; this just renders the final state
/// with the caption bar and the developed (or undeveloped) photo.
///
/// Visual goal: feels like a real instant photo. White paper border,
/// drop shadow, a subtle tilt to break the grid feel.
struct PolaroidCard: View {
    let original: UIImage
    let developed: UIImage?
    let caption: String
    var subtitle: String? = nil
    var tilt: Double = -1.2

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Image(uiImage: original)
                    .resizable()
                    .scaledToFill()
                    .opacity(developed == nil ? 1 : 0)
                if let developed {
                    Image(uiImage: developed)
                        .resizable()
                        .scaledToFill()
                }
                // Subtle vignette — sells the "physical photo" feel
                RadialGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.18)],
                    center: .center, startRadius: 80, endRadius: 240
                )
                .allowsHitTesting(false)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()

            // Polaroid bottom border. Slightly off-white for paper feel.
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(caption)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.72))
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.black.opacity(0.5))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .padding(.bottom, 8)
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
        .shadow(color: .black.opacity(0.30), radius: 8, y: 4)
        .rotationEffect(.degrees(tilt))
    }
}
