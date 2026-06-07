import Foundation
import Observation
import UserNotifications

/// Schedules the daily "today's sky is waiting" reminder.
///
/// Two pieces meet here:
///   1. **Local scheduling** — a repeating local notification at the
///      user's chosen hour:minute. Fires only on days they haven't
///      already scanned (`recordScan` clears the next fire).
///   2. **Future personalization** — once a backend aggregation
///      function exists, a real push from the server can replace
///      the local fire with personalized content ("23 people near
///      you saw animals in the sky today"). Until then the body is
///      warm-generic so the ritual is in place from day one.
///
/// We do NOT register for remote pushes here; that's APNS + Supabase
/// edge-function territory and is tracked in the setup TODO. Local
/// notifications don't need entitlements beyond the standard
/// UNUserNotificationCenter authorization (already requested by
/// NotificationService).
@Observable
@MainActor
final class DailyReminderService {
    static let shared = DailyReminderService()

    /// User preferences. Stored in UserDefaults via these helper
    /// keys; not @AppStorage because we live outside SwiftUI and
    /// want to mutate them from anywhere.
    private enum K {
        static let enabled = "cloudoodle.dailyReminder.enabled"
        static let hour    = "cloudoodle.dailyReminder.hour"
        static let minute  = "cloudoodle.dailyReminder.minute"
    }

    /// Stable identifier so we can find + cancel + replace this
    /// notification without affecting any future ones we add.
    private let requestID = "cloudoodle.dailyReminder"

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: K.enabled) as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: K.enabled)
            Task { await rescheduleIfNeeded() }
        }
    }

    /// Default 11:00am local — a gentle late-morning nudge that's
    /// past most morning routines but well before sunset.
    var hour: Int {
        get { UserDefaults.standard.object(forKey: K.hour) as? Int ?? 11 }
        set {
            UserDefaults.standard.set(newValue, forKey: K.hour)
            Task { await rescheduleIfNeeded() }
        }
    }

    var minute: Int {
        get { UserDefaults.standard.object(forKey: K.minute) as? Int ?? 0 }
        set {
            UserDefaults.standard.set(newValue, forKey: K.minute)
            Task { await rescheduleIfNeeded() }
        }
    }

    var reminderTime: Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    // MARK: - Scheduling

    /// Re-evaluate scheduling state. Called on launch, on prefs
    /// change, and after every scan completes.
    ///
    /// Uses a non-repeating trigger scheduled for the next fire
    /// date — that way "skip today because they already scanned"
    /// is a natural consequence of choosing tomorrow's date, not
    /// a separate cancellation pass. Each fire (and each scan)
    /// reschedules, so the chain is self-sustaining.
    func rescheduleIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])

        guard enabled else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional else {
            return
        }

        let fireDate = nextFireDate()
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )

        let content = UNMutableNotificationContent()
        content.title = "Today's sky is waiting ☁︎"
        content.body = defaultBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: requestID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )

        do { try await center.add(request) } catch { /* best-effort */ }
    }

    /// Called after a successful scan. Cancels today's pending
    /// reminder (if any) and queues tomorrow's.
    func notifyDidScan() async {
        await rescheduleIfNeeded()
    }

    /// The next moment we should fire the reminder:
    ///   • Today at hour:minute if we haven't passed it yet AND
    ///     the user hasn't already scanned today
    ///   • Otherwise tomorrow at hour:minute
    private func nextFireDate() -> Date {
        let cal = Calendar.current
        let now = Date()
        let alreadyScanned = SubscriptionService.shared.scannedToday

        var todayComps = cal.dateComponents([.year, .month, .day], from: now)
        todayComps.hour = hour
        todayComps.minute = minute
        let todayFire = cal.date(from: todayComps) ?? now

        if !alreadyScanned && todayFire > now {
            return todayFire
        }
        return cal.date(byAdding: .day, value: 1, to: todayFire) ?? now.addingTimeInterval(86_400)
    }

    // MARK: - Personalization (forward-looking)

    /// The generic local-fire body. Once the backend aggregation
    /// edge function ships, real push deliveries will replace this
    /// with something specific ("23 people near Brooklyn saw shapes
    /// in the sky today"). Until then, a warm steady invitation.
    private var defaultBody: String {
        let pool = [
            "Look up — what's drifting overhead?",
            "Five minutes with the sky. That's the whole thing.",
            "Today's sky is unrepeatable. Catch a frame.",
            "Whatever shape finds you today — develop it.",
            "Out the window, just for a second."
        ]
        // Stable per-day selection so the user doesn't see the same
        // line on every test run, but also doesn't see "random" feel.
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return pool[day % pool.count]
    }
}
