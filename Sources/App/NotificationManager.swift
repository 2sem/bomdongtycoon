import UserNotifications

enum NotificationManager {

    /// Asks only while the status is `.notDetermined`, so it is safe to call
    /// from every launch and never prompts twice. Called from `GameRootView`
    /// once the first-run tutorial is out of the way, not from the splash.
    static func requestPermissionIfUndetermined() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func scheduleStallFullNotification(afterHours hours: Double = 2) {
        let content = UNMutableNotificationContent()
        content.title = "봄동 가게"
        content.body = "가게가 꽉 찼어요! 봄동이 기다리고 있어요 🥬"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: hours * 3600,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "bomdong.stall.full",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
