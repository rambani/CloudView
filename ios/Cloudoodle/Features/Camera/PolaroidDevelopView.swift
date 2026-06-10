import SwiftUI
import UIKit

/// "Polaroid developing" reveal. Plays while the server-side image-edit
/// API call is in flight (typically 10–25 s) and then transitions
/// to the developed result.
///
/// The metaphor is deliberate: Cloudoodle is editorial-tactile,
/// not feed-tap-fast. Watching a cloud develop on Polaroid film is
/// the closest digital analog to actually staring up at the sky and
/// letting your eye find a shape. The wait IS the experience.
///
/// Visual moves:
///   1. Tilt-down + flip-out — the photo "ejects" from the camera
///      onto a Polaroid frame, with a slight tilt that settles.
///   2. Shake — a brief side-to-side wobble (just like waving the
///      print to develop it). Triggered by a subtle haptic.
///   3. Develop — foggy → sharp via a saturation + brightness
///      curve. The original photo is the "undeveloped negative",
///      the developed image is the AI result that fades in on top.
///   4. Ink fade-in — the white doodle lines materialise last, as
///      if the artist is finishing the sketch.
///   5. Settle — slight bounce to rest, with a success haptic.
struct PolaroidDevelopView: View {
    /// Original captured photo — shown while developing.
    let original: UIImage
    /// Developed result from the API — drives the cross-fade once
    /// available. While nil, the develop animation loops.
    let developed: UIImage?
    /// Progress hint 0…1. Used for the brightness/saturation curves
    /// so the photo "develops" in lock-step with the actual API call
    /// (the parent caller drives this from elapsed time vs. typical
    /// response time, then snaps to 1.0 on completion).
    let progress: Double
    /// Caller fires this when the user taps the developed Polaroid
    /// to dismiss the reveal and land in today's home view.
    var onTap: () -> Void = {}
    /// Journal entry created when develop succeeded. Currently unused
    /// inside the view (the parent uses it for routing) but kept as
    /// the explicit signal that develop is done + saved.
    var journalEntryId: UUID? = nil

    @State private var tiltSettled = false
    @State private var shakeOffset: CGFloat = 0
    @State private var hasShaken = false
    @State private var hasSettled = false

    var body: some View {
        ZStack {
            // Soft ambient backdrop — a warm darkroom red.
            // Reads as "we're developing this photo in a darkroom",
            // matches the metaphor without being literal.
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.07, blue: 0.09),
                         Color(red: 0.04, green: 0.02, blue: 0.03)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                polaroidCard
                developingCaption
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            // Tilt settles in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                tiltSettled = true
            }
            // Shake after a beat
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeInOut(duration: 0.10).repeatCount(5, autoreverses: true)) {
                    shakeOffset = 12
                }
                try? await Task.sleep(for: .milliseconds(550))
                withAnimation(.easeOut(duration: 0.12)) { shakeOffset = 0 }
                hasShaken = true
            }
        }
        .onChange(of: developed != nil) { _, isDone in
            if isDone, !hasSettled {
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                        hasSettled = true
                    }
                }
            }
        }
    }

    // MARK: - The Polaroid card

    private var polaroidCard: some View {
        VStack(spacing: 0) {
            ZStack {
                // Undeveloped photo — washed out, foggy
                photoStage
                    .opacity(developed == nil ? 1 : (1 - min(1, max(0, progress * 1.2))))
                    .saturation(developSaturation)
                    .brightness(developBrightness)
                    .overlay(
                        // Film grain over the developing photo
                        FilmGrain(opacity: developed == nil ? 0.18 : 0.06)
                            .blendMode(.softLight)
                    )

                // Developed image cross-fades in
                if let developed {
                    Image(uiImage: developed)
                        .resizable()
                        .scaledToFill()
                        .opacity(min(1, progress * 1.4))
                        .transition(.opacity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .overlay(
                // A subtle vignette so the photo reads as "real print"
                RadialGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.18)],
                    center: .center, startRadius: 80, endRadius: 240
                )
                .allowsHitTesting(false)
            )

            // Polaroid bottom border — wider than the sides, where
            // captions live on real Polaroids.
            HStack {
                if hasSettled {
                    Text(developed != nil ? "Developed ☁︎" : "Developing…")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(.black.opacity(0.65))
                        .transition(.opacity)
                }
                Spacer()
                if developed != nil {
                    Text(Self.timeStamp())
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.45))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 64)
        }
        .background(Color(white: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .rotationEffect(.degrees(tiltSettled ? -1.5 : -12))
        .offset(x: shakeOffset, y: tiltSettled ? 0 : -200)
        .scaleEffect(tiltSettled ? 1 : 0.85)
        .onTapGesture {
            if developed != nil { onTap() }
        }
    }

    private var photoStage: some View {
        Image(uiImage: original)
            .resizable()
            .scaledToFill()
    }

    /// Saturation grows from 0.1 (foggy) to 1.0 (fully developed) as
    /// progress runs from 0 → 1. Slightly nonlinear so the transition
    /// reads as photochemical rather than digital.
    private var developSaturation: Double {
        if developed == nil {
            return 0.10 + 0.35 * progress
        }
        return 0.45 + 0.55 * progress
    }

    private var developBrightness: Double {
        if developed == nil {
            return 0.35 - 0.20 * progress
        }
        return 0.15 - 0.15 * progress
    }

    // MARK: - Caption

    private var developingCaption: some View {
        VStack(spacing: 10) {
            if let _ = developed, hasSettled {
                Text("Tap to keep watching")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(1)
            } else {
                HStack(spacing: 10) {
                    BlinkingDot()
                    Text(devText)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1)
                        .id(devText)
                        .transition(.opacity.animation(.easeInOut(duration: 0.35)))
                }
                // The guessing game — cloud-watchers (especially the
                // small ones standing next to their parents) are
                // already guessing out loud during the wait. Honor it.
                // Turns 10-25s of dead air into the game itself.
                Text("What do you think it is?")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    /// Cycles through evocative phrases while the API call is in
    /// flight. Keeps the wait feeling deliberate rather than stuck.
    private var devText: String {
        // Pick a phrase based on elapsed progress so the user sees
        // motion through the wait.
        let phrases = [
            "letting the cloud develop",
            "shaking the print",
            "looking for the shape",
            "drawing what's already there",
            "almost done — settling the ink"
        ]
        let idx = min(phrases.count - 1, Int(progress * Double(phrases.count)))
        return phrases[idx]
    }

    private static func timeStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy · HH:mm"
        return f.string(from: Date())
    }
}

// MARK: - Helpers

/// Blinking dot that pulses to indicate live processing.
private struct BlinkingDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 6, height: 6)
            .opacity(on ? 0.9 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

/// Procedural film grain — a Canvas drawing of randomized dots,
/// sized to the photo. Re-renders on each frame so the grain feels
/// alive while the photo is developing.
private struct FilmGrain: View {
    let opacity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { _ in
            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                // Cheap deterministic-ish jitter
                var rng = SystemRandomNumberGenerator()
                let count = Int(w * h / 600)
                for _ in 0..<count {
                    let x = CGFloat.random(in: 0..<w, using: &rng)
                    let y = CGFloat.random(in: 0..<h, using: &rng)
                    let r = CGFloat.random(in: 0.4...1.2, using: &rng)
                    let alpha = CGFloat.random(in: 0.2...0.6, using: &rng)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(.white.opacity(alpha * opacity))
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}
