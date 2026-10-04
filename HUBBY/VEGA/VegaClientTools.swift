import Foundation
import UserNotifications

// MARK: - Reminder scheduling tool

enum ReminderTool {
    static func schedule(title: String, at date: Date) async {
        let center   = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content   = UNMutableNotificationContent()
        content.title = "VEGA Reminder"
        content.body  = title
        content.sound = .default

        let comps  = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req     = UNNotificationRequest(identifier: "vega.reminder.\(UUID())", content: content, trigger: trigger)

        try? await center.add(req)
    }
}
