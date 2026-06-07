import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(AppState.self) private var appState

    @State private var userSightings: [CloudSighting] = []
    @State private var isLoading = false

    @State private var showSettings = false
    @State private var showJournal = false
    @State private var journalStore = JournalStore.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if supabase.isAuthenticated, let user = supabase.currentUser {
                authenticatedProfile(user)
            } else {
                signInPrompt
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showJournal) { JournalGalleryView() }
        .task { await journalStore.loadIfNeeded() }
    }

    private func authenticatedProfile(_ user: AppUser) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                profileHeader(user)
                    .padding(.bottom, 28)

                // Stats row
                statsRow(user)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                journalRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                // Collection grid
                if isLoading {
                    ProgressView()
                        .tint(CV.Color.accentBlue)
                        .padding(40)
                } else if userSightings.isEmpty {
                    emptyCollection
                } else {
                    collectionGrid
                }

                Color.clear.frame(height: 100)
            }
        }
        .scrollIndicators(.hidden)
        .task { await loadSightings() }
    }

    private func profileHeader(_ user: AppUser) -> some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CV.Color.accent, CV.Color.accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Text(String(user.username.prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.black)
            }
            .padding(.top, 60)

            Text(user.username)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(CV.Color.textPrimary)

            if let city = user.city {
                Label(city, systemImage: "location.fill")
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textTertiary)
            }
        }
    }

    private func statsRow(_ user: AppUser) -> some View {
        HStack(spacing: 0) {
            StatCell(value: "\(user.totalSightings)", label: "Sightings")
            Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
            StatCell(value: "\(user.streakDays)", label: "Day Streak")
            Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
            StatCell(value: topShape ?? "—", label: "Top Shape")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CV.Radius.md)
                .fill(Color(white: 0.08))
        )
    }

    /// Card that opens the Polaroid journal. Sits below the stats so
    /// it reads as a separate, more personal collection — the develop-
    /// and-write ritual rather than the community sightings feed.
    private var journalRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showJournal = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(white: 0.96))
                        .frame(width: 40, height: 46)
                        .rotationEffect(.degrees(-6))
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.11, green: 0.15, blue: 0.24))
                        .rotationEffect(.degrees(-6))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Polaroid journal")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(CV.Color.textPrimary)
                    Text(journalSubtitle)
                        .font(CV.Font.caption)
                        .foregroundStyle(CV.Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CV.Color.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: CV.Radius.md)
                    .fill(Color(white: 0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var journalSubtitle: String {
        let n = journalStore.entries.count
        if n == 0 { return "Start your stack — develop a Polaroid" }
        if n == 1 { return "1 Polaroid · tap to revisit" }
        return "\(n) Polaroids · tap to revisit"
    }

    private var topShape: String? {
        userSightings
            .map(\.shapeName)
            .reduce(into: [:]) { $0[$1, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key
    }

    private var collectionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Collection")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CV.Color.textPrimary)
                .padding(.horizontal, 20)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ], spacing: 2) {
                ForEach(userSightings) { sighting in
                    CollectionThumbnail(sighting: sighting)
                }
            }
        }
    }

    private var emptyCollection: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(CV.Color.textTertiary)
            Text("No sightings yet")
                .font(CV.Font.headline)
                .foregroundStyle(CV.Color.textPrimary)
            Text("Capture your first cloud to start your collection.")
                .font(CV.Font.ui)
                .foregroundStyle(CV.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var signInPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.dashed")
                .font(.system(size: 72))
                .foregroundStyle(CV.Color.textTertiary)
            Text("Your Cloud Collection")
                .font(CV.Font.headline)
                .foregroundStyle(CV.Color.textPrimary)
            Text("Sign in to save your sightings and track your streak.")
                .font(CV.Font.ui)
                .foregroundStyle(CV.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showSettings = true
            } label: {
                Text("Sign In")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: CV.Radius.md).fill(CV.Color.accent))
            }
        }
        .padding(40)
    }

    private func loadSightings() async {
        guard let userId = supabase.currentUser?.id else { return }
        isLoading = true
        do {
            userSightings = try await supabase.fetchUserSightings(userId: userId)
        } catch {}
        isLoading = false
    }
}

// MARK: - Stat Cell
private struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CV.Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(CV.Font.caption)
                .foregroundStyle(CV.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Collection Thumbnail
private struct CollectionThumbnail: View {
    let sighting: CloudSighting

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = sighting.localImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else if let urlStr = sighting.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Color(white: 0.12)
                        }
                    }
                } else {
                    Color(white: 0.12)
                }
            }
            .frame(width: UIScreen.main.bounds.width / 3, height: UIScreen.main.bounds.width / 3)
            .clipped()

            // AI overlay at thumbnail scale
            CloudOverlayView(sighting: sighting, animationProgress: 1.0)
                .frame(
                    width: UIScreen.main.bounds.width / 3,
                    height: UIScreen.main.bounds.width / 3
                )

            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)

            Text(sighting.shapeName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(4)
        }
        .frame(width: UIScreen.main.bounds.width / 3, height: UIScreen.main.bounds.width / 3)
        .clipped()
    }
}
