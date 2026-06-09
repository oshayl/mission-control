// NotificationsManager.swift
// Schedules stale-client nudges and handles response.

import Foundation
import UserNotifications
import AppKit

final class NotificationsManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationsManager()
    private let center = UNUserNotificationCenter.current()
    private var authorized = false

    private override init() {
        super.init()
        // Only attach delegate if we're running inside a proper app bundle —
        // UNUserNotificationCenter crashes raw executables.
        if Bundle.main.bundleIdentifier != nil {
            center.delegate = self
        }
    }

    func requestAuthorization() async {
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            authorized = false
        }
    }

    /// Re-evaluates the stale list and posts/updates a summary notification.
    func refreshStaleNotifications(clients: [Client]) {
        guard authorized else { return }
        let center = self.center
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let stale = clients.filter { $0.isStale && $0.status == .active }
            center.removePendingNotificationRequests(withIdentifiers: stale.map { "stale-\($0.id.uuidString)" })
            guard !stale.isEmpty else { return }
            let content = UNMutableNotificationContent()
            content.title = "\(stale.count) client\(stale.count == 1 ? "" : "s") need attention"
            content.body = stale.prefix(3).map { $0.displayName }.joined(separator: ", ")
                + (stale.count > 3 ? " and \(stale.count - 3) more" : "")
            content.sound = .default
            content.categoryIdentifier = "stale-clients"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let req = UNNotificationRequest(identifier: "stale-summary", content: content, trigger: trigger)
            center.add(req) { _ in }
        }
    }

    /// UNUserNotificationCenterDelegate — show banner even when app is in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
