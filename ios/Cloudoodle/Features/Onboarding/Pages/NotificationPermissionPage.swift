import SwiftUI

/// Page 05 — notifications prime. Sunset palette + a fake push card
/// previews exactly what a real "Golden hour in 20 min" nudge looks
/// like (the notify-nearby-users edge function ships the same shape).
struct NotificationPermissionPage: View {
    var onAdvance: () -> Void

    var body: some View {
        PermissionPageLayout(
            backdrop: .sunset,
            backdropOverlay: AnyView(NotificationPreviewCard()),
            eyebrow: "Nudges",
            headline: "I'll ping you when the sky shows off",
            italicWord: "shows off",
            body: "Golden hour, dramatic clouds, a sky worth looking up for. A couple of nudges a week — never spam.",
            chips: ["Golden hour", "Big skies", "~2 a week"],
            primaryTitle: "Turn on nudges",
            primaryAction: {
                Task {
                    _ = await NotificationService.shared.requestPermission()
                    onAdvance()
                }
            },
            secondaryTitle: "No thanks",
            secondaryAction: onAdvance
        )
    }
}

/// Mock notification banner — Apple's actual notification chrome at
/// roughly the right size, with the Cloudoodle app icon stamp + a
/// representative payload from notify-nearby-users.
private struct NotificationPreviewCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(CV.Color.accentBlue)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("CLOUDOODLE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.75))
                    Spacer()
                    Text("now")
                        .font(.system(size: 11))
                        .foregroundStyle(.black.opacity(0.55))
                }
                Text("Golden hour in 20 min — there's a whale forming over the river. 🐋")
                    .font(.system(size: 13))
                    .foregroundStyle(.black)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.92))
        )
        .frame(maxWidth: 280)
        .padding(.horizontal, 24)
    }
}
