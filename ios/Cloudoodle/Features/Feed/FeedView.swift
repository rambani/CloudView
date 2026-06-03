import SwiftUI

struct FeedView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var supabase: SupabaseService

    @State private var sightings: [CloudSighting] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var page = 0
    @State private var showSettings = false
    @State private var loadMoreError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header

                    if isLoading && sightings.isEmpty {
                        loadingState
                    } else if let error, sightings.isEmpty {
                        errorState(error)
                    } else if sightings.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 28) {
                            ForEach(sightings) { sighting in
                                SightingCard(sighting: sighting)
                                .onAppear {
                                    if sighting.id == sightings.last?.id {
                                        Task { await loadMore() }
                                    }
                                }
                            }

                            if isLoading {
                                ProgressView()
                                    .tint(CV.Color.accentBlue)
                                    .padding()
                            }

                            if let loadMoreError {
                                Text(loadMoreError)
                                    .font(CV.Font.caption)
                                    .foregroundStyle(CV.Color.textTertiary)
                                    .padding()
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Color.clear.frame(height: 100) // tab bar clearance
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { await refresh() }

        }
        .task { await refresh() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cloudoodle")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(CV.Color.textPrimary)
                Text("What's in the sky today")
                    .font(CV.Font.caption)
                    .foregroundStyle(CV.Color.textTertiary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CV.Color.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CV.Radius.md)
                    .fill(Color(white: 0.12))
                    .frame(height: 280)
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.cloud")
                .font(.system(size: 48))
                .foregroundStyle(CV.Color.textTertiary)
            Text(error.localizedDescription)
                .font(CV.Font.ui)
                .foregroundStyle(CV.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await refresh() }
            }
            .foregroundStyle(CV.Color.accentBlue)
        }
        .padding(40)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("☁️")
                .font(.system(size: 64))
            Text("No sightings yet")
                .font(CV.Font.headline)
                .foregroundStyle(CV.Color.textPrimary)
            Text("Be the first to find a shape in the sky.")
                .font(CV.Font.ui)
                .foregroundStyle(CV.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                appState.selectedTab = .capture
            } label: {
                Label("Scan the Sky", systemImage: "camera.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: CV.Radius.md).fill(CV.Color.accent))
            }
        }
        .padding(40)
    }

    // MARK: - Data

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        page = 0
        do {
            let fresh = try await supabase.fetchFeed(limit: 20, offset: 0)
            sightings = fresh
            page = 1
        } catch {
            if sightings.isEmpty { self.error = error }
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let more = try await supabase.fetchFeed(limit: 20, offset: page * 20)
            sightings.append(contentsOf: more)
            page += 1
        } catch {
            // Don't blow away the existing feed for a transient
            // load-more failure — flash a small banner under the
            // spinner so the user knows pagination stalled.
            withAnimation(.spring(response: 0.3)) {
                loadMoreError = "Couldn't load more — pull to refresh."
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { loadMoreError = nil }
        }
        isLoading = false
    }
}

// MARK: - Shimmer modifier
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: .white.opacity(0.06), location: phase),
                        .init(color: .clear, location: phase + 0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: phase)
            )
            .onAppear { phase = 1.3 }
            .clipped()
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
