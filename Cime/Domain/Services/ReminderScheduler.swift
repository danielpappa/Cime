//
//  ReminderScheduler.swift
//  Cime
//
//  Created by Daniel Pappalardo on 07/11/2026.
//

import UserNotifications

enum ReminderScheduler {
    private static let id = "cime.morning-reminder"

    /// Shows the iOS permission prompt if needed. Call when the user flips the toggle ON.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default: return false
        }
    }

    /// Never prompts. Schedules a daily 8:00 (device time zone) reminder, or removes it.
    static func apply(enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled else { return }
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }
        let content = UNMutableNotificationContent()
        content.title = "Set your three daily peaks"
        content.body = "What will you summit today?"
        content.sound = .default
        var time = DateComponents(); time.hour = 8; time.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
