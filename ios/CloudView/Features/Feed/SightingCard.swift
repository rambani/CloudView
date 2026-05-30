import SwiftUI

struct SightingCard: View {
    let sighting: CloudSighting
    var onLike: (() -> Void)?
    var onTap: (() -> Void)?

    @EnvironmentObject private var supabase: SupabaseService

    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var reportSheetShown = false
    @State private var blockSheetShown = false
    @State private var reportReason: ReportReason = .inappropriate
    @State private var reportSubmitting = false
    @State private var reportToast: String?

    init(sighting: CloudSighting, onLike: (() -> Void)? = nil, onTap: (() -> Void)? = nil) {
        self.sighting = sighting
        self.onLike = onLike
        self.onTap = onTap
        _isLiked = State(initialValue: sighting.isLikedByCurrentUser)
        _likeCount = State(initialValue: sighting.likes)
    }

    // App Review (UGC apps) requires a way to flag objectionable content.
    // Keeping the reason set short and human-readable so the moderation
    // queue is actually triagable.
    enum ReportReason: String, CaseIterable, Identifiable {
        case inappropriate = "Inappropriate content"
        case spam          = "Spam or off-topic"
        case harassment    = "Harassment or hate"
        case other         = "Something else"
        var id: String { rawValue }
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
        // Long-press exposes the moderation actions Apple requires for
        // UGC feeds. Less prominent than a dedicated button (the like
        // count is the primary action), but discoverable via the
        // standard iOS long-press affordance.
        .contextMenu {
            if supabase.isAuthenticated {
                Button(role: .destructive) {
                    reportSheetShown = true
                } label: {
                    Label("Report", systemImage: "flag")
                }
                if let posterId = sighting.userId,
                   posterId != supabase.currentUser?.id {
                    Button(role: .destructive) {
                        blockSheetShown = true
                    } label: {
                        Label("Block this user", systemImage: "hand.raised")
                    }
                }
            }
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: $blockSheetShown,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task { await submitBlock() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You won't see any of their sightings in your feed or on the map. You can unblock them in Settings.")
        }
        .confirmationDialog(
            "Report this sighting?",
            isPresented: $reportSheetShown,
            titleVisibility: .visible
        ) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.rawValue) {
                    Task { await submitReport(reason: reason) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Reports are reviewed by our team. You won't see this sighting in your feed again.")
        }
        .overlay(alignment: .top) {
            if let toast = reportToast {
                Text(toast)
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
    }

    private func submitBlock() async {
        guard let posterId = sighting.userId else { return }
        do {
            try await supabase.blockUser(id: posterId)
            withAnimation(.spring(response: 0.35)) {
                reportToast = "User blocked. Refresh to see changes."
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { reportToast = nil }
        } catch {
            withAnimation(.spring(response: 0.35)) {
                reportToast = "Couldn't block. Try again."
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { reportToast = nil }
        }
    }

    private func submitReport(reason: ReportReason) async {
        reportSubmitting = true
        do {
            try await supabase.reportSighting(id: sighting.id, reason: reason.rawValue)
            withAnimation(.spring(response: 0.35)) {
                reportToast = "Thanks — we'll review this."
            }
            // Auto-dismiss after 3s
            try? await Task.sleep(for: .seconds(3))
            withAnimation { reportToast = nil }
        } catch {
            withAnimation(.spring(response: 0.35)) {
                reportToast = "Couldn't submit report. Try again."
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { reportToast = nil }
        }
        reportSubmitting = false
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
