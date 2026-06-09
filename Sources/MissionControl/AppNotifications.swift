// AppNotifications.swift
// Notification names used to coordinate between views.

import Foundation

extension Notification.Name {
    static let mcFocusSearch = Notification.Name("mc.focusSearch")
    static let mcPulse = Notification.Name("mc.pulse")
    static let mcWebhookStatusChanged = Notification.Name("mc.webhookStatusChanged")
}
