// ClientList.swift
import SwiftUI

struct ClientList: View {
    @EnvironmentObject var store: DataStore
    let onSelect: (Client) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if store.filteredClients.isEmpty {
                    EmptyState()
                } else {
                    ForEach(store.filteredClients) { c in
                        ClientRow(client: c)
                            .onTapGesture { onSelect(c) }
                            .contextMenu {
                                Button("Open") { onSelect(c) }
                                Button("Mark Contacted Now") {
                                    if let i = store.data.clients.firstIndex(where: { $0.id == c.id }) {
                                        store.data.clients[i].lastContact = Date()
                                    }
                                }
                                Button("Snooze 7 Days") {
                                    if let i = store.data.clients.firstIndex(where: { $0.id == c.id }) {
                                        store.data.clients[i].lastContact = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                                    }
                                }
                                Divider()
                                if let phone = c.phone, !phone.isEmpty {
                                    Button("Call \(phone)") { openTel(phone) }
                                }
                                if let im = c.imessageHandle, !im.isEmpty {
                                    Button("iMessage") { openIMessage(to: im) }
                                }
                                if let em = c.email, !em.isEmpty {
                                    Button("Email") { openMail(to: em) }
                                }
                                Divider()
                                Button(role: .destructive) {
                                    store.delete(id: c.id)
                                } label: { Text("Delete") }
                            }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

struct ClientRow: View {
    let client: Client

    var body: some View {
        HStack(spacing: 10) {
            Avatar(client: client)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(client.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Circle().fill(client.status.color).frame(width: 6, height: 6)
                }
                if let n = client.nextAction, !n.isEmpty {
                    Text(n).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else if let last = client.lastContact {
                    Text("Last contact \(relative(last))").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Never contacted").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let d = client.daysSinceContact {
                    Text("\(d)d")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(client.isStale ? .orange : .secondary)
                }
                if let amt = client.lastInvoiceAmount {
                    Text(currency(amt)).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct Avatar: View {
    let client: Client
    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            Text(client.initials.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
    }
    var gradient: [Color] {
        // Stable color from name hash
        let h = abs(client.name.hashValue)
        let palettes: [[Color]] = [
            [.purple, .indigo], [.teal, .blue], [.pink, .red],
            [.orange, .yellow], [.green, .mint], [.blue, .cyan],
        ]
        return palettes[h % palettes.count]
    }
}

struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36)).foregroundStyle(.secondary)
            Text("No clients match").font(.subheadline)
            Text("Try a different filter, or add one with +.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

func relative(_ date: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f.localizedString(for: date, relativeTo: Date())
}

func currency(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
}
