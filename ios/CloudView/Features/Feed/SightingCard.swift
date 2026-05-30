import SwiftUI

struct SightingCard: View {
    let sighting: CloudSighting
    var onLike: (() -> Void)?
    var onTap: (() -> Void)?

    @State private var isLiked: Bool
    @State private var likeCount: Int

    init(sighting: CloudSighting, onLike: (() -> Void)? = nil, onTap: (() -> Void)? = nil) {
        self.sighting = sighting
        self.onLike = onLike
        self.onTap = onTap
        _isLiked = State(initialValue: sighting.isLikedByCurrentUser)
        _likeCount = State(initialValue: sighting.likes)
    }

    var body: some View {
        // Card outer is a tap gesture target rather than a Button so
        // the inner like Button gets its own hit region. SwiftUI's
        // behaviour for Button-inside-Button is unspecified pre-iOS 18
        // (variously: outer wins, both fire, neither fires depending on
        // gesture timing). Tap gesture on a VStack + Button for the like
        // is the supported pattern.
        VStack(alignment: .leading, spacing: 0) {
            // Photo with overlay
            ZStack(alignment: .bottomLeading) {
                cloudImage
                    .frame(height: 240)
                    .clipped()

                // AI drawing overlay
                CloudOverlayView(sighting: sighting, animationProgress: 1.0)
                    .frame(height: 240)

                // Bottom gradient
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Cloud type chip
                Text(sighting.cloudType)
                    .font(CV.Font.mono)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: CV.Radius.md, style: .continuous))

            // Card body
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(sighting.shapeName)
                        .font(CV.Font.headline)
                        .foregroundStyle(CV.Color.textPrimary)
                    Spacer()
                    Text(sighting.weatherMood)
                        .font(CV.Font.shapeName)
                        .foregroundStyle(CV.Color.accent)
                }

                Text(sighting.quip)
                    .font(CV.Font.quip)
                    .foregroundStyle(CV.Color.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    // Location
                    if let city = sighting.city {
                        Label(city, systemImage: "location.fill")
                            .font(CV.Font.caption)
                            .foregroundStyle(CV.Color.textTertiary)
                    }

                    Spacer()

                    // Time
                    Text(sighting.createdAt, style: .relative)
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textTertiary)

                    // Like button — isolated hit region; tap on this does
                    // not bubble up to the card-tap gesture.
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            isLiked.toggle()
                            likeCount += isLiked ? 1 : -1
                        }
                        onLike?()
                    } label: {
                        Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                            .font(CV.Font.caption)
                            .foregroundStyle(isLiked ? .red : CV.Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    @ViewBuilder
    private var cloudImage: some View {
        if let data = sighting.localImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else if let urlStr = sighting.imageURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    placeholderSky
                default:
                    Color(white: 0.12)
                        .overlay(ProgressView().tint(.white))
                }
            }
        } else {
            placeholderSky
        }
    }

    private var placeholderSky: some View {
        LinearGradient(
            colors: [Color(hue: 0.58, saturation: 0.5, brightness: 0.6),
                     Color(hue: 0.55, saturation: 0.3, brightness: 0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
