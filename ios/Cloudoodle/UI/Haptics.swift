import UIKit

/// Cloudoodle's haptic vocabulary — one place so the whole app
/// speaks a consistent dialect instead of scattering ad-hoc
/// generator calls.
///
/// The grammar:
///   • selection — a control snapped between discrete states
///     (drawer position, Ink/Original toggle)
///   • tap       — a card or row acknowledged the touch
///   • soft      — a spatial transition committed (swipe-to-gallery,
///     zoom toggle); quieter than tap, felt more than heard
///   • shutter   — the capture moment; the one medium-weight hit
///     in the app
///   • success   — a Polaroid finished developing
///   • warning   — something was prevented (night-sky guard)
///
/// Generators are created per-call: at our interaction frequency
/// (a handful per session) the alloc cost is irrelevant, and it
/// sidesteps stale-generator no-fire bugs after long idle.
enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    static func shutter() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
