// ClientList.swift
// Apple-clean client list. Hairline separators, no fills, no shadows.

import SwiftUI

struct ClientList: View {
    @EnvironmentObject var store: DataStore
    let onSelect: (Client) -> Void
    @State private var hoverID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            if store.filteredClients.isEmpty {
                EmptyState()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.filteredClients) { c in
                            ClientRow(
                                client: c,
                                isHovered: hoverID == c.id,
                                isSelected: store.selectedClientID == c.id,
                                isBulkSelected: store.bulkSelectedIDs.contains(c.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if NSEvent.modifierFlags.contains(.command) {
                                    if store.bulkSelectedIDs.contains(c.id) {
                                        store.bulkSelectedIDs.remove(c.id)
                                    } else {
                                        store.bulkSelectedIDs.insert(c.id)
                                    }
                                } else {
                                    onSelect(c)
                                }
                            }
                            .onHover { hoverID = $0 ? c.id : (hoverID == c.id ? nil : hoverID) }
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
                            Divider().background(MC.hairline).padding(.leading, 44)
                        }
                    }
                }
            }
            if !store.bulkSelectedIDs.isEmpty {
                BulkActionBar().environmentObject(store)
            }
        }
    }
}

struct ClientRow: View {
    let client: Client
    let isHovered: Bool
    let isSelected: Bool
    let isBulkSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            avatarBlock
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(client.displayName)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(MC.textPrimary)
                        .tracking(-0.2)
                        .lineLimit(1)
                    if client.nextActionDue != nil {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(MC.accent)
                    }
                    if let amt = client.lastInvoiceAmount, amt > 0 {
                        Text(currency(amt))
                            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(MC.textTertiary)
                    }
                }
                HStack(spacing: 6) {
                    Text(secondary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(MC.textTertiary)
                        .lineLimit(1)
                    if !client.tags.isEmpty {
                        Text("·").font(.system(size: 11.5)).foregroundStyle(MC.textTertiary)
                        Text(client.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                            .font(.system(size: 11))
                            .foregroundStyle(MC.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let d = client.daysSinceContact {
                    Text(daysLabel(d))
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(client.isStale ? MC.stale : MC.textTertiary)
                }
                Text(client.status.label.uppercased())
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(client.status.systemColor.opacity(0.85))
            }
        }
        .padding(.horizontal, MC.pad)
        .frame(height: MC.rowHeight)
        .background(rowBackground)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatarBlock: some View {
        if isBulkSelected {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(MC.accent)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        } else {
            Text(client.initials.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(MC.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(MC.textPrimary.opacity(0.04))
                )
        }
    }

    private var secondary: String {
        if let n = client.nextAction, !n.isEmpty { return n }
        if let last = client.lastContact { return "Last contact \(relative(last))" }
        return "Never contacted"
    }

    private var rowBackground: some View {
        Group {
            if isBulkSelected { MC.rowSelected }
            else if isSelected { MC.rowSelected }
            else if isHovered { MC.rowHover }
            else { Color.clear }
        }
    }

    private func daysLabel(_ d: Int) -> String {
        switch d {
        case 0: return "today"
        case 1: return "1d"
        default: return "\(d)d"
        }
    }
}

struct EmptyState: View {
    @EnvironmentObject var store: DataStore
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(MC.textTertiary)
            Text("No clients match")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MC.textPrimary)
            Text("Add one with ⌘N or the + button.")
                .font(.system(size: 11))
                .foregroundStyle(MC.textTertiary)
            Button("Add Client") { store.showAddSheet = true }
                .buttonStyle(MCButtonStyle(variant: .primary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MCButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, ghost }
    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(background(isPressed: configuration.isPressed))
            .foregroundStyle(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                    .stroke(border, lineWidth: borderWidth)
            )
    }

    private func background(isPressed: Bool) -> Color {
        switch variant {
        case .primary: return isPressed ? MC.accent.opacity(0.8) : MC.accent
        case .secondary: return isPressed ? MC.textPrimary.opacity(0.08) : MC.textPrimary.opacity(0.05)
        case .ghost: return Color.clear
        }
    }
    private var foreground: Color {
        switch variant {
        case .primary: return .white
        case .secondary, .ghost: return MC.textPrimary
        }
    }
    private var border: Color {
        switch variant {
        case .primary: return .clear
        case .secondary: return MC.hairline
        case .ghost: return .clear
        }
    }
    private var borderWidth: CGFloat {
        variant == .secondary ? 1 : 0
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
