import Foundation
import UserNotifications

/// Local reminders only (no push). The system prompt is shown only after the player says YES
/// on the in-game pre-prompt.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let dailyBonusID = "daily-bonus-ready"

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedules "your free coins are ready" for when the next daily bonus unlocks.
    func scheduleDailyBonusReminder(at date: Date) async {
        guard await authorizationStatus() == .authorized else { return }
        center.removePendingNotificationRequests(withIdentifiers: [dailyBonusID])
        let content = UNMutableNotificationContent()
        content.title = "Daily free coins are ready"
        content.body = "Your daily coins are waiting in Pharaoh Spin. Coins are for fun only."
        content.sound = .default
        let interval = max(60, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: dailyBonusID, content: content, trigger: trigger))
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
