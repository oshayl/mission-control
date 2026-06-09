// ActivityStream.swift
// Interleaves iMessage + GitHub + Calendar + manual entries into one chronological feed.

import SwiftUI

enum StreamItem: Identifiable, Hashable {
    case manual(ActivityEntry)
    case message(IMessageContact)
    case github(GitHubActivity)
    case calendar(CalendarEventLite)

    var id: String {
        switch self {
        case .manual(let e): return "m-\(e.id.uuidString)"
        case .message(let m): return "i-\(m.lastMessageAt.timeIntervalSince1970)"
        case .github(let g): return "g-\(g.repo)-\(g.timestamp.timeIntervalSince1970)"
        case .calendar(let c): return "c-\(c.start.timeIntervalSince1970)"
        }
    }
    var timestamp: Date {
        switch self {
        case .manual(let e): return e.timestamp
        case .message(let m): return m.lastMessageAt
        case .github(let g): return g.timestamp
        case .calendar(let c): return c.start
        }
    }
}

struct ActivityStream: View {
    let client: Client
    @EnvironmentObject var store: DataStore
    @State private var githubItems: [GitHubActivity] = []

    private var stream: [StreamItem] {
        var items: [StreamItem] = []
        for a in client.activity { items.append(.manual(a)) }
        if let m = store.lastIMessage(for: client) { items.append(.message(m)) }
        for g in githubItems.prefix(8) { items.append(.github(g)) }
        return items.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(stream) { item in
                row(item)
                if item != stream.last {
                    Divider().background(MC.hairline).padding(.leading, 22)
                }
            }
            if stream.isEmpty {
                Text("Nothing yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(MC.textTertiary)
                    .padding(.vertical, 4)
            }
        }
        .task {
            githubItems = await store.githubActivity(for: client)
        }
    }

    private func row(_ item: StreamItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            iconColumn(item)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(item))
                    .font(.system(size: 12))
                    .foregroundStyle(MC.textPrimary)
                    .lineLimit(2)
                Text(item.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(MC.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func iconColumn(_ item: StreamItem) -> some View {
        let (icon, color): (String, Color) = {
            switch item {
            case .manual(let e):
                switch e.kind {
                case "call": return ("phone.fill", MC.statusActive)
                case "message": return ("message.fill", MC.statusShipped)
                case "invoice": return ("dollarsign.circle.fill", MC.statusLead)
                case "deploy": return ("arrow.up.circle.fill", .purple)
                case "commit": return ("chevron.left.forwardslash.chevron.right", .indigo)
                default: return ("note.text", MC.textTertiary)
                }
            case .message: return ("message.fill", MC.statusShipped)
            case .github(let g):
                switch g.kind {
                case "push": return ("arrow.up.circle.fill", .purple)
                case "pr": return ("arrow.triangle.pull", MC.statusShipped)
                case "issue": return ("exclamationmark.circle", MC.statusLead)
                case "release": return ("tag.fill", MC.statusActive)
                case "star": return ("star.fill", MC.statusLead)
                default: return ("circle.fill", MC.textTertiary)
                }
            case .calendar: return ("calendar.circle.fill", .red)
            }
        }()
        Image(systemName: icon)
            .font(.system(size: 11))
            .foregroundStyle(color)
            .frame(width: 16)
    }

    private func title(_ item: StreamItem) -> String {
        switch item {
        case .manual(let e): return e.summary
        case .message(let m): return "\(m.lastFromMe ? "You" : "Them"): \(m.lastMessageText)"
        case .github(let g): return "\(g.kind) · \(g.repo) · \(g.title)"
        case .calendar(let c): return "\(c.title) · \(c.calendar)"
        }
    }
}
