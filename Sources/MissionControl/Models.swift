// Models.swift
// Core data models for Mission Control.

import Foundation
import SwiftUI

enum ClientStatus: String, Codable, CaseIterable {
    case active
    case lead
    case shipped
    case paused
    case archived

    var color: Color {
        switch self {
        case .active: return .green
        case .lead: return .yellow
        case .shipped: return .blue
        case .paused: return .orange
        case .archived: return .gray
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

struct Client: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var company: String?
    var status: ClientStatus = .active
    var nextAction: String?
    var nextActionDue: Date?
    var lastContact: Date?
    var lastInvoice: Date?
    var lastInvoiceAmount: Double?
    var lastInvoiceStatus: String?   // paid / sent / overdue / draft
    var phone: String?
    var email: String?
    var imessageHandle: String?      // phone or email
    var githubLogin: String?
    var notes: String = ""
    var tags: [String] = []
    var activity: [ActivityEntry] = []   // lifted to client level (was nested in projects)
    var projects: [Project] = []
    var attachments: [Attachment] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var displayName: String { company ?? name }
    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }
    var daysSinceContact: Int? {
        guard let lastContact else { return nil }
        return Calendar.current.dateComponents([.day], from: lastContact, to: Date()).day
    }
    var isStale: Bool {
        guard let d = daysSinceContact else { return true }
        return d >= 14
    }
}

struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var status: String = "active"  // active / shipped / on-hold
    var dueDate: Date?
    var url: String?
    var notes: String = ""
    var activity: [ActivityEntry] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct ActivityEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date
    var kind: String      // message / invoice / commit / call / note / deploy / pr / issue
    var summary: String
    var meta: String?
}

struct Attachment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var url: String           // file:// or https://
    var sizeBytes: Int?
    var addedAt: Date = Date()
}

struct MissionData: Codable {
    var version: Int = 1
    var clients: [Client] = []
    var archivedClients: [Client] = []
    var settings: Settings = Settings()

    struct Settings: Codable {
        var staleDays: Int = 14
        var githubOrgs: [String] = ["oshayl"]
        var autoLaunch: Bool = true
        var notifyStale: Bool = true
        var themeRaw: String = "system"   // system / light / dark
        var syncedAt: Date = Date()
    }
}
