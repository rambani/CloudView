import SwiftUI

/// Page 05 — notifications prime. The only notification Cloudoodle
/// actually fires today is the daily reminder — one quiet nudge at
/// a time the user picks (see DailyReminderService). The page sells
/// that honestly: a single daily fire, only on days they haven't
/// already scanned.
struct NotificationPermissionPage: View {
    var onAdvance: () -> Void

    var body: some View {
        PermissionPageLayout(
            backdrop: .sunset,
            backdropOverlay: AnyView(NotificationPreviewCard()),
            eyebrow: "Reminders",
            headline: "A quiet nudge, once a day",
            italicWord: "once a day",
            bodyText: "Pick a time in Settings. I'll only nudge you on days you haven't already scanned. No spam — and you can turn it off anytime.",
            chips: ["1 nudge/day", "Skips days you scan", "Off by default"],
            primaryTitle: "Allow reminders",
            primaryAction: {
                Task {
                    let granted = await NotificationService.shared.requestPermission()
                    if granted {
                        // Pre-enable the daily reminder so the user
                        // sees an immediate value from saying yes —
                        // they can fine-tune the time in Settings.
                        DailyReminderService.shared.enabled = true
                    }
                    onAdvance()
                }
            },
            secondaryTitle: "Maybe later",
            secondaryAction: onAdvance
        )
    }
}

/// Mock notification banner — Apple's actual notification chrome at
/// roughly the right size, with the Cloudoodle app icon stamp + a
/// representative reminder payload.
private struct NotificationPreviewCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(CV.Color.accentBlue)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "cloud.fill")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("CLOUDOODLE")
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(.black.opacity(0.75))
                    Spacer()
                    Text("11:00 am")
                        .scaledFont(size: 11)
                        .foregroundStyle(.black.opacity(0.55))
                }
                Text("Today's sky is waiting ☁︎")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(.black)
                Text("Five minutes with the sky. That's the whole thing.")
                    .scaledFont(size: 12)
                    .foregroundStyle(.black.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.92))
        )
        .frame(maxWidth: 300)
        .padding(.horizontal, 24)
    }
}
