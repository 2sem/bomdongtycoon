import Foundation
import UserNotifications

enum NotificationManager {

    private static let requestLock = NSLock()
    nonisolated(unsafe) private static var isRequesting = false

    /// Asks only while the status is `.notDetermined`, so it is safe to call
    /// from every launch and never prompts twice. `GameRootView` calls it once
    /// the shop is named, so the system alert never stacks on an in-game modal.
    /// `isRequesting` covers the async gap between reading the status and the
    /// system recording the answer, where two calls would both see
    /// `.notDetermined`.
    static func requestPermissionIfUndetermined() {
        requestLock.lock()
        guard !isRequesting else { requestLock.unlock(); return }
        isRequesting = true
        requestLock.unlock()

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                finishRequest()
                return
            }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                finishRequest()
            }
        }
    }

    private static func finishRequest() {
        requestLock.lock()
        isRequesting = false
        requestLock.unlock()
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
