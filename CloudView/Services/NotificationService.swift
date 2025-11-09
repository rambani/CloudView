import Foundation
import UserNotifications
import UIKit

class NotificationService: ObservableObject {
    @Published var notificationsEnabled = false
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?

    private let notificationCenter = UNUserNotificationCenter.current()
    private let backendURL = "https://cloud-view-backend.vercel.app/api/register-device"

    init() {
        checkNotificationAuthorization()
    }

    // MARK: - Permission Handling

    func checkNotificationAuthorization() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationPermissionStatus = settings.authorizationStatus
                self?.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.notificationsEnabled = granted
                if granted {
                    print("Notification permission granted")
                    // Register for remote notifications with APNs
                    self?.registerForRemoteNotifications()
                } else {
                    print("Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
                }
                self?.checkNotificationAuthorization()
            }
        }
    }

    // MARK: - Remote Notification Registration

    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        // Convert device token to string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString

        print("📱 Device token: \(tokenString)")

        // Send token to backend (with user's region if available)
        registerDeviceWithBackend(token: tokenString)
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Local Notification (for testing)

    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Cloud Watching Alert! ☁️"
        content.body = "Lots of animals spotted in clouds near you today! 🦁"
        content.sound = .default

        // Trigger in 5 seconds for testing
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Backend Registration

    private func registerDeviceWithBackend(token: String, region: String? = nil) {
        guard let url = URL(string: backendURL) else {
            print("❌ Invalid backend URL")
            return
        }

        let payload: [String: Any] = [
            "deviceToken": token,
            "region": region ?? "Unknown",
            "notificationsEnabled": true
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("❌ Failed to encode device registration")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error registering device: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Device registered with backend successfully")
                } else {
                    print("❌ Device registration failed with status: \(httpResponse.statusCode)")
                }
            }
        }

        task.resume()
    }

    func updateRegion(_ region: String) {
        // Update region when location becomes available
        if let token = deviceToken {
            registerDeviceWithBackend(token: token, region: region)
        }
    }
}

// MARK: - Notification Content Examples

extension NotificationService {
    // Example notification messages based on regional data
    static func generateNotificationMessage(for category: DrawingCategory, count: Int, region: String) -> (title: String, body: String) {
        switch category {
        case .animals:
            if count > 20 {
                return ("Animals Everywhere! 🦁☁️", "Lots of animal shapes spotted in \(region) clouds today!")
            } else if count > 10 {
                return ("Animal Sightings! 🐻", "People are finding animal drawings in \(region) - look up!")
            }

        case .mythical:
            if count > 15 {
                return ("Magical Skies! 🐉✨", "Dragons and unicorns appearing in \(region) clouds!")
            } else if count > 8 {
                return ("Mythical Creatures! 🦄", "Magical beings spotted in the clouds near you!")
            }

        case .landmarks:
            if count > 10 {
                return ("Architectural Wonders! 🗼", "Famous landmarks forming in \(region) clouds!")
            }

        case .vehicles:
            if count > 10 {
                return ("Sky Traffic! ✈️", "Vehicles and aircraft appearing in \(region) skies!")
            }

        case .food:
            if count > 10 {
                return ("Tasty Clouds! 🍕", "Delicious shapes forming in \(region) - take a look!")
            }

        case .nature:
            if count > 10 {
                return ("Natural Beauty! 🌸", "Beautiful nature patterns in \(region) clouds!")
            }
        }

        // Default
        return ("Cloud Watching Time! ☁️", "Perfect conditions in \(region) - others finding amazing shapes!")
    }

    static func generateGeneralActivityMessage(totalCount: Int, region: String) -> (title: String, body: String) {
        if totalCount > 50 {
            return ("Amazing Cloud Day! 🌤️", "\(totalCount) drawings found in \(region) today - don't miss out!")
        } else if totalCount > 30 {
            return ("Active Sky Watching! ☁️", "People in \(region) are spotting great clouds right now!")
        } else {
            return ("Cloud Watching Weather! 🌤️", "Perfect conditions in \(region) - look at the sky!")
        }
    }
}

// Drawing categories for privacy-preserving aggregation
enum DrawingCategory: String, Codable {
    case animals = "animals"
    case mythical = "mythical"
    case landmarks = "landmarks"
    case vehicles = "vehicles"
    case food = "food"
    case nature = "nature"

    // Helper to categorize a drawing by its subject
    static func categorize(drawingName: String) -> DrawingCategory {
        let name = drawingName.lowercased()

        // Animals
        if name.contains("cat") || name.contains("dog") || name.contains("bird") ||
           name.contains("bear") || name.contains("lion") || name.contains("tiger") ||
           name.contains("elephant") || name.contains("penguin") || name.contains("fox") ||
           name.contains("wolf") || name.contains("deer") || name.contains("rabbit") {
            return .animals
        }

        // Mythical
        if name.contains("dragon") || name.contains("unicorn") || name.contains("phoenix") ||
           name.contains("griffin") || name.contains("wizard") || name.contains("fairy") ||
           name.contains("mermaid") || name.contains("centaur") {
            return .mythical
        }

        // Landmarks
        if name.contains("tower") || name.contains("castle") || name.contains("bridge") ||
           name.contains("statue") || name.contains("temple") || name.contains("pyramid") {
            return .landmarks
        }

        // Vehicles
        if name.contains("car") || name.contains("plane") || name.contains("boat") ||
           name.contains("train") || name.contains("rocket") || name.contains("helicopter") {
            return .vehicles
        }

        // Food
        if name.contains("pizza") || name.contains("burger") || name.contains("cake") ||
           name.contains("ice cream") || name.contains("donut") || name.contains("taco") {
            return .food
        }

        // Default to nature
        return .nature
    }
}
