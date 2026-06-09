// DataStore.swift
// ObservableObject backing the UI. Loads/saves to Application Support + iCloud Drive.

import Foundation
import SwiftUI
import Combine

@MainActor
final class DataStore: ObservableObject {
    @Published var data: MissionData = MissionData()
    @Published var search: String = ""
    @Published var statusFilter: ClientStatus? = nil
    @Published var tagFilter: String? = nil
    @Published var timeframe: Timeframe = .all
    @Published var showStaleOnly: Bool = false
    @Published var lastError: String? = nil
    @Published var lastSync: Date? = nil
    @Published var showAddSheet: Bool = false
    @Published var showSettings: Bool = false
    @Published var showCommandPalette: Bool = false
    @Published var showArchive: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var selectedClientID: UUID? = nil
    @Published var bulkSelectedIDs: Set<UUID> = []
    @Published var pulseAt: Date? = nil   // for icon animation when new activity arrives

    let onboardingKey = "mc.onboarding.dismissed"

    private let appSupportURL: URL
    private let iCloudURL: URL?
    private var saveTimer: AnyCancellable?
    private var imessageRefreshTimer: AnyCancellable?

    init() {
        let fm = FileManager.default
        let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil,
                                     create: true)
        let dir = appSupport?.appendingPathComponent("MissionControl", isDirectory: true)
        if let dir { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        self.appSupportURL = dir?.appendingPathComponent("mission.json") ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mission.json")

        // iCloud Drive container (ubiquity)
        if let ubiquity = fm.url(forUbiquityContainerIdentifier: nil) {
            let iCloudDir = ubiquity.appendingPathComponent("Documents", isDirectory: true)
            try? fm.createDirectory(at: iCloudDir, withIntermediateDirectories: true)
            self.iCloudURL = iCloudDir.appendingPathComponent("mission.json")
        } else {
            self.iCloudURL = nil
        }

        load()
        seedIfEmpty()
        startAutoSave()
    }

    // MARK: - Persistence

    func load() {
        // Prefer iCloud copy if present, else local
        if let iCloudURL, FileManager.default.fileExists(atPath: iCloudURL.path) {
            if let d: MissionData = Self.read(iCloudURL) { self.data = d; return }
        }
        if FileManager.default.fileExists(atPath: appSupportURL.path) {
            if let d: MissionData = Self.read(appSupportURL) { self.data = d; return }
        }
    }

    func save() {
        data.settings.syncedAt = Date()
        if let iCloudURL {
            Self.write(data, to: iCloudURL)
        }
        Self.write(data, to: appSupportURL)
        lastSync = Date()
    }

    private func startAutoSave() {
        saveTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.save()
            }
        // Refresh iMessage data every 60s.
        imessageRefreshTimer = Timer.publish(every: 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshIMessageData()
            }
        // Also refresh once on launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshIMessageData()
        }
    }

    // MARK: - iMessage refresh

    func refreshIMessageData() {
        let reader = IMessageReader.shared
        var changed = false
        for i in data.clients.indices {
            let client = data.clients[i]
            guard let handle = client.imessageHandle, !handle.isEmpty else { continue }
            guard let contact = reader.lastMessage(with: handle) else { continue }
            // If message is more recent than lastContact (or lastContact is nil), update.
            if let lc = client.lastContact {
                if contact.lastMessageAt > lc {
                    data.clients[i].lastContact = contact.lastMessageAt
                    changed = true
                }
            } else {
                data.clients[i].lastContact = contact.lastMessageAt
                changed = true
            }
        }
        if changed {
            objectWillChange.send()
        }
        // Refresh notifications whenever data changes
        NotificationsManager.shared.refreshStaleNotifications(clients: data.clients)
    }

    /// Public lookup used by the detail view to show last iMessage preview.
    func lastIMessage(for client: Client) -> IMessageContact? {
        guard let h = client.imessageHandle, !h.isEmpty else { return nil }
        return IMessageReader.shared.lastMessage(with: h)
    }

    /// Async fetcher for GitHub activity.
    func githubActivity(for client: Client) async -> [GitHubActivity] {
        guard let g = client.githubLogin, !g.isEmpty else { return [] }
        return await GitHubClient.shared.recentActivity(for: g)
    }

    private static func read<T: Decodable>(_ url: URL) -> T? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder.iso.decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try JSONEncoder.iso.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            // swallow — UI shows lastError
        }
    }

    // MARK: - Mutations

    func upsert(_ client: Client) {
        if let i = data.clients.firstIndex(where: { $0.id == client.id }) {
            var c = client; c.updatedAt = Date()
            data.clients[i] = c
        } else {
            data.clients.append(client)
        }
    }

    func delete(id: UUID) {
        data.clients.removeAll { $0.id == id }
    }

    // MARK: - Bulk ops

    func bulkMarkContacted(ids: Set<UUID>) {
        let now = Date()
        for i in data.clients.indices {
            if ids.contains(data.clients[i].id) {
                data.clients[i].lastContact = now
            }
        }
    }

    func bulkArchive(ids: Set<UUID>) {
        var toMove: [Client] = []
        data.clients.removeAll { c in
            if ids.contains(c.id) {
                toMove.append(c); return true
            }
            return false
        }
        data.archivedClients.append(contentsOf: toMove)
    }

    func bulkTag(ids: Set<UUID>, tag: String) {
        let t = tag.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        for i in data.clients.indices where ids.contains(data.clients[i].id) {
            if !data.clients[i].tags.contains(t) {
                data.clients[i].tags.append(t)
            }
        }
    }

    func restoreFromArchive(id: UUID) {
        guard let i = data.archivedClients.firstIndex(where: { $0.id == id }) else { return }
        let c = data.archivedClients.remove(at: i)
        data.clients.append(c)
    }

    // MARK: - CSV import/export

    func exportCSV() -> String {
        var rows: [String] = []
        let header = "name,company,status,phone,email,imessage,github,next_action,next_action_due,last_contact,last_invoice_amount,last_invoice_status,tags,notes"
        rows.append(header)
        let f = ISO8601DateFormatter()
        for c in data.clients {
            let cols: [String] = [
                c.name, c.company ?? "", c.status.rawValue,
                c.phone ?? "", c.email ?? "", c.imessageHandle ?? "",
                c.githubLogin ?? "", c.nextAction ?? "",
                c.nextActionDue.map(f.string(from:)) ?? "",
                c.lastContact.map(f.string(from:)) ?? "",
                c.lastInvoiceAmount.map { String($0) } ?? "",
                c.lastInvoiceStatus ?? "",
                c.tags.joined(separator: ";"),
                c.notes.replacingOccurrences(of: "\n", with: " ")
            ]
            rows.append(cols.map(csvEscape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    func importCSV(_ text: String) -> Int {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > 1 else { return 0 }
        let header = parseCSVRow(String(lines[0]))
        guard header.count >= 1 else { return 0 }
        var added = 0
        let f = ISO8601DateFormatter()
        for line in lines.dropFirst() {
            let cols = parseCSVRow(String(line))
            guard cols.count >= 1, !cols[0].isEmpty else { continue }
            func col(_ name: String) -> String? {
                guard let i = header.firstIndex(of: name), i < cols.count else { return nil }
                return cols[i].isEmpty ? nil : cols[i]
            }
            var c = Client(name: cols[0])
            c.company = col("company")
            c.status = ClientStatus(rawValue: col("status") ?? "active") ?? .active
            c.phone = col("phone")
            c.email = col("email")
            c.imessageHandle = col("imessage")
            c.githubLogin = col("github")
            c.nextAction = col("next_action")
            c.nextActionDue = col("next_action_due").flatMap { f.date(from: $0) }
            c.lastContact = col("last_contact").flatMap { f.date(from: $0) }
            if let amt = col("last_invoice_amount"), let d = Double(amt) { c.lastInvoiceAmount = d }
            c.lastInvoiceStatus = col("last_invoice_status")
            c.tags = (col("tags") ?? "").split(separator: ";").map(String.init).filter { !$0.isEmpty }
            c.notes = col("notes") ?? ""
            upsert(c)
            added += 1
        }
        return added
    }

    private func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }

    private func parseCSVRow(_ line: String) -> [String] {
        var cols: [String] = []
        var current = ""
        var inQuotes = false
        for c in line {
            if c == "\"" { inQuotes.toggle() }
            else if c == "," && !inQuotes { cols.append(current); current = "" }
            else { current.append(c) }
        }
        cols.append(current)
        return cols
    }

    // MARK: - Pulse trigger

    func triggerPulse() {
        pulseAt = Date()
    }

    // MARK: - Derived

    var filteredClients: [Client] {
        var list = data.clients
        if let s = statusFilter { list = list.filter { $0.status == s } }
        if showStaleOnly { list = list.filter { $0.isStale } }
        if let tag = tagFilter, !tag.isEmpty {
            list = list.filter { $0.tags.contains(where: { $0.lowercased() == tag.lowercased() }) }
        }
        list = timeframe.filter(list)
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(q)
                || ($0.company ?? "").lowercased().contains(q)
                || $0.notes.lowercased().contains(q)
                || $0.tags.contains(where: { $0.lowercased().contains(q) })
                || ($0.nextAction ?? "").lowercased().contains(q)
            }
        }
        return list.sorted {
            ($0.lastContact ?? .distantPast) > ($1.lastContact ?? .distantPast)
        }
    }

    var allTags: [String] {
        let set = Set(data.clients.flatMap { $0.tags })
        return set.sorted()
    }

    var stats: (active: Int, stale: Int, leads: Int, shipped: Int, dueThisWeek: Int) {
        let active = data.clients.filter { $0.status == .active }.count
        let stale = data.clients.filter { $0.isStale && $0.status == .active }.count
        let leads = data.clients.filter { $0.status == .lead }.count
        let shipped = data.clients.filter { $0.status == .shipped }.count
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let dueThisWeek = data.clients.filter {
            guard let d = $0.nextActionDue else { return false }
            return d >= Date() && d <= weekEnd
        }.count
        return (active, stale, leads, shipped, dueThisWeek)
    }

    // MARK: - Seed

    private func seedIfEmpty() {
        guard data.clients.isEmpty else { return }
        // Don't seed if the user has previously dismissed onboarding — respect an empty start.
        let dismissed = UserDefaults.standard.bool(forKey: onboardingKey)
        if !dismissed { showOnboarding = true }
        // Always seed sample clients so the app demos nicely.
        let now = Date()
        data.clients = [
            Client(
                name: "John Wilbers", company: "Wilbers Law Firm", status: .active,
                nextAction: "Seth wants blog about Cash Stash community impact",
                nextActionDue: Calendar.current.date(byAdding: .day, value: 5, to: now),
                lastContact: Calendar.current.date(byAdding: .day, value: -2, to: now),
                phone: "+13144438966",
                email: "jwilbers@thewilberslawfirm.com",
                imessageHandle: "+13144438966",
                notes: "Site live at thewilberslawfirm.com. Contract through Cash Stash (Seth Spurlock).",
                tags: ["legal", "stl", "retainer"]
            ),
            Client(
                name: "Chandler Wells", company: "Brothers & Co", status: .active,
                nextAction: "Google Business Page + domain connect",
                lastContact: Calendar.current.date(byAdding: .day, value: -5, to: now),
                phone: nil, email: nil,
                imessageHandle: nil,
                notes: "$500/mo retainer. brothers-co.pages.dev live.",
                tags: ["construction", "retainer"]
            ),
            Client(
                name: "Jackson Bell", company: "Complete Coverage Roofing", status: .active,
                nextAction: "Wait on approval + media processing",
                lastContact: Calendar.current.date(byAdding: .day, value: -20, to: now),
                phone: "417-414-2545",
                email: "jackson@completecoverageroofing.com",
                notes: "Site live at complete-coverage-roofing.pages.dev.",
                tags: ["roofing", "stale"]
            ),
            Client(
                name: "Miriah Adams", company: "Ozark Aesthetician", status: .shipped,
                lastContact: Calendar.current.date(byAdding: .day, value: -30, to: now),
                phone: "7282270765", email: "theozarkaesthetician@gmail.com",
                notes: "Shipped. Site at ozark-aesthetician.pages.dev.",
                tags: ["spa", "shipped"]
            ),
            Client(
                name: "Kyler", company: "Social Cue SGF", status: .lead,
                nextAction: "Wed 7pm call for site update approval",
                nextActionDue: Calendar.current.date(byAdding: .day, value: 3, to: now),
                notes: "socialcuessgf.com. Media replacement + copy revisions in progress.",
                tags: ["event", "springfield"]
            )
        ]
    }
}

extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}

extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

enum Timeframe: String, CaseIterable, Identifiable {
    case all
    case today
    case thisWeek
    case dueSoon
    case stale

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .dueSoon: return "Due Soon"
        case .stale: return "Stale"
        }
    }

    func filter(_ clients: [Client]) -> [Client] {
        let now = Date()
        let cal = Calendar.current
        switch self {
        case .all: return clients
        case .today:
            return clients.filter { c in
                if let lc = c.lastContact, cal.isDateInToday(lc) { return true }
                if let due = c.nextActionDue, cal.isDateInToday(due) { return true }
                return false
            }
        case .thisWeek:
            let weekEnd = cal.date(byAdding: .day, value: 7, to: now) ?? now
            return clients.filter { c in
                if let lc = c.lastContact, lc >= now.addingTimeInterval(-7*24*3600) { return true }
                if let due = c.nextActionDue, due >= now && due <= weekEnd { return true }
                return false
            }
        case .dueSoon:
            let weekEnd = cal.date(byAdding: .day, value: 7, to: now) ?? now
            return clients.filter { c in
                guard let due = c.nextActionDue else { return false }
                return due >= now && due <= weekEnd
            }
        case .stale:
            return clients.filter { $0.isStale }
        }
    }
}
