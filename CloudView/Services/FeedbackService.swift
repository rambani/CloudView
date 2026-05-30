import Foundation
import AudioToolbox
import UIKit

/// Centralized audio + haptic cues for the cloud-watching loop. Today
/// uses Apple's built-in SystemSound library and UIFeedbackGenerator
/// shims — no custom audio assets required. Custom sounds drop in
/// later by replacing the systemSoundID(for:) mapping with a fileURL +
/// AVAudioPlayer.
///
/// Cues are intentionally subtle. A 4+ kids' app outdoors competes with
/// real-world background sound; loud or piercing audio is wrong, and a
/// kid scanning many clouds in a row shouldn't hear the same chime
/// pierce their attention twenty times. Most cues are sub-haptic +
/// quiet.
enum FeedbackEvent {
    /// User just successfully scanned and a cloud is being identified.
    /// Quiet, brief — "I see something."
    case sightingBegan

    /// A cloud drawing has been recognized and rendered.
    /// Slightly more satisfying — "look what we made."
    case drawingRevealed

    /// Recognition tried and didn't find a confident match. No sound;
    /// just a soft haptic so the kid knows something happened.
    case noMatch
}

final class FeedbackService {
    static let shared = FeedbackService()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let success = UINotificationFeedbackGenerator()

    /// Per-event cooldown so a kid sweeping the sky doesn't get the
    /// same chime 20× in 10 seconds. Keyed by event.
    private var lastFired: [String: Date] = [:]
    private let cooldown: TimeInterval = 1.5

    private init() {
        // Warm the haptic generators so the first call isn't laggy.
        lightImpact.prepare()
        mediumImpact.prepare()
        success.prepare()
    }

    /// Fire the audio + haptic combo for the given event, respecting
    /// the per-event cooldown so we don't spam either modality.
    func fire(_ event: FeedbackEvent) {
        let key = "\(event)"
        if let last = lastFired[key], Date().timeIntervalSince(last) < cooldown {
            return
        }
        lastFired[key] = Date()

        switch event {
        case .sightingBegan:
            lightImpact.impactOccurred()
            playSound(1306)  // Tock — quiet, brief

        case .drawingRevealed:
            mediumImpact.impactOccurred()
            playSound(1322)  // Photo shutter feel — a "moment captured"

        case .noMatch:
            lightImpact.impactOccurred(intensity: 0.5)
            // No sound — silence is the right cue for "nothing found"
        }
    }

    private func playSound(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
}
