import SwiftUI
import UIKit
import Observation

/// First-run flow state. Owns the step machine for the onboarding
/// pages. Cloudoodle no longer asks for a username during onboarding
/// — account creation is optional and lives in Settings — so this is
/// down to just the page cursor.
@Observable
@MainActor
final class OnboardingStore {
    var step: Step = .welcome

    init() {}

    enum Step: Int, CaseIterable {
        case welcome, howItWorks, camera, location, notifications, demo, finished

        /// Pages that show the progress-dots header. Welcome/demo/finished
        /// are full-bleed and skip the chrome.
        var showsProgressBar: Bool {
            switch self {
            case .howItWorks, .camera, .location, .notifications: return true
            default: return false
            }
        }

        /// 1-indexed position inside the progress-dot range, or nil if hidden.
        var progressIndex: Int? {
            switch self {
            case .howItWorks: return 1
            case .camera: return 2
            case .location: return 3
            case .notifications: return 4
            default: return nil
            }
        }

        static var progressTotal: Int { 4 }
    }

    func advance() {
        guard let i = Step.allCases.firstIndex(of: step), i + 1 < Step.allCases.count else { return }
        step = Step.allCases[i + 1]
        Self.tap()
    }

    func goBack() {
        guard let i = Step.allCases.firstIndex(of: step), i > 0 else { return }
        step = Step.allCases[i - 1]
        Self.tap()
    }

    /// Soft selection-style haptic on page transitions — feels tactile
    /// without competing with the system permission sheets that fire
    /// their own feedback. Generated once and discarded; cheap.
    private static func tap() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }
}
