import SwiftUI

/// Editorial entry in the community feed.
///
/// Design choice: the feed never shows other people's photos. Only the
/// AI-generated text — shape name, weather mood, the witty quip,
/// city, time. This collapses the content-moderation surface from
/// "every user's uploaded image" down to "did the AI label something
/// weird," which the report flow handles narrowly. Users still see
/// their OWN photos in Profile → collection; only the community feed
/// is text-only.
///
/// Users are also not surfaced by name — there's no @username byline.
/// What's being broadcast is "people are seeing dragons in Brooklyn,"
/// not "Alice saw a dragon."
struct SightingCard: View {
    let sighting: CloudSighting
    var onLike: (() -> Void)?
    var onTap: (() -> Void)?

    @EnvironmentObject private var supabase: SupabaseService

    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var reportSheetShown = false
    @State private var reportToast: String?

    init(sighting: CloudSighting, onLike: (() -> Void)? = nil, onTap: (() -> Void)? = nil) {
        self.sighting = sighting
        self.onLike = onLike
        self.onTap = onTap
        _isLiked = State(initialValue: sighting.isLikedByCurrentUser)
        _likeCount = State(initialValue: sighting.likes)
    }

    enum ReportReason: String, CaseIterable, Identifiable {
        case inappropriate = "Inappropriate label"
        case nonsense      = "Doesn't describe a cloud"
        case other         = "Something else"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header strip: cloud type · weather mood. Pure typography,
            // no chrome — the editorial aesthetic from the design chat.
            HStack(spacing: 8) {
                Text(sighting.cloudType.uppercased())
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.textTertiary)
                Text("·")
                    .foregroundStyle(CV.Color.textTertiary)
                Text(sighting.weatherMood)
                    .font(CV.Font.shapeName)
                    .foregroundStyle(CV.Color.accent)
                Spacer()
            }

            // The quip is the hero. Italic Instrument Serif at a real
            // reading size. Lets the AI-generated copy carry the page.
            Text(sighting.quip)
                .font(CV.Font.quip)
                .foregroundStyle(CV.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Byline: SHAPE NAME — city. Mono caps, the way a newspaper
            // would credit a piece. No username.
            HStack(spacing: 6) {
                Text(sighting.shapeName.uppercased())
                    .font(CV.Font.mono)
                    .foregroundStyle(CV.Color.textSecondary)
                if let city = sighting.city {
                    Text("·")
                        .foregroundStyle(CV.Color.textTertiary)
                    Text(city)
                        .font(CV.Font.mono)
                        .foregroundStyle(CV.Color.textTertiary)
                }
            }

            // Meta row: time + like. Like remains useful — it's a
            // signal to other readers ("five other people enjoyed
            // this quip"), not a per-user social interaction.
            HStack(spacing: 12) {
                Text(sighting.createdAt, style: .relative)
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textTertiary)
                Spacer()
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
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: CV.Radius.md, style: .continuous)
                .fill(Color(white: 0.07))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        // Report stays useful — the AI occasionally produces a label
        // that doesn't describe a cloud, or worse. No Block: nothing
        // user-attributable is shown to block against. The block table
        // and filter view stay in the schema in case a future social
        // surface needs them.
        .contextMenu {
            if supabase.isAuthenticated {
                Button(role: .destructive) {
                    reportSheetShown = true
                } label: {
                    Label("Report", systemImage: "flag")
                }
            }
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
            Text("We review reports to keep AI labels on-track. This entry won't show in your feed again.")
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

    private func submitReport(reason: ReportReason) async {
        do {
            try await supabase.reportSighting(id: sighting.id, reason: reason.rawValue)
            withAnimation(.spring(response: 0.35)) {
                reportToast = "Thanks — we'll review this."
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { reportToast = nil }
        } catch {
            withAnimation(.spring(response: 0.35)) {
                reportToast = "Couldn't submit report. Try again."
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { reportToast = nil }
        }
    }
}
