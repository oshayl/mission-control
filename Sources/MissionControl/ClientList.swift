// ClientList.swift
// Apple-clean client list. Hairline separators, no fills, no shadows.

import SwiftUI

struct ClientList: View {
    @EnvironmentObject var store: DataStore
    let onSelect: (Client) -> Void
    @State private var hoverID: UUID? = nil
    @State private var keyboardSelectedID: UUID? = nil

    private var effectiveSelection: UUID? {
        store.selectedClientID ?? keyboardSelectedID
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.filteredClients.isEmpty {
                EmptyState()
            } else {
                clientScrollView
            }
            if !store.bulkSelectedIDs.isEmpty {
                BulkActionBar().environmentObject(store)
            }
        }
        .focusable()
        .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
        .onKeyPress(.return) {
            if let id = keyboardSelectedID, let c = store.filteredClients.first(where: { $0.id == id }) {
                onSelect(c)
            }
            return .handled
        }
        .onAppear {
            if keyboardSelectedID == nil {
                keyboardSelectedID = store.filteredClients.first?.id
            }
        }
    }

    private var clientScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.filteredClients) { c in
                        clientRowView(c)
                        Divider().background(MC.hairline).padding(.leading, 44)
                    }
                }
            }
            .onChange(of: keyboardSelectedID) { _, new in
                if let id = new {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private func clientRowView(_ c: Client) -> some View {
        ClientRow(
            client: c,
            isHovered: hoverID == c.id,
            isSelected: effectiveSelection == c.id,
            isBulkSelected: store.bulkSelectedIDs.contains(c.id)
        )
        .id(c.id)
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                keyboardSelectedID = c.id
                if store.bulkSelectedIDs.contains(c.id) {
                    store.bulkSelectedIDs.remove(c.id)
                } else {
                    store.bulkSelectedIDs.insert(c.id)
                }
            } else {
                keyboardSelectedID = c.id
                onSelect(c)
            }
        }
        .onHover { hoverID = $0 ? c.id : (hoverID == c.id ? nil : hoverID) }
        .contextMenu { rowContextMenu(c) }
    }

    @ViewBuilder
    private func rowContextMenu(_ c: Client) -> some View {
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

    private func moveSelection(by delta: Int) {
        let list = store.filteredClients
        guard !list.isEmpty else { return }
        let currentIndex = list.firstIndex(where: { $0.id == keyboardSelectedID }) ?? -1
        let raw = currentIndex + delta
        let lo = 0
        let hi = list.count - 1
        let next = min(max(raw, lo), hi)
        keyboardSelectedID = list[next].id
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
        if let last = client.lastContact {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return "Last contact \(f.localizedString(for: last, relativeTo: Date()))"
        }
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

    private func currency(_ amt: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amt)) ?? "$\(Int(amt))"
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
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(MC.hairline, lineWidth: 1)
                    .frame(width: 56, height: 56)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundStyle(MC.textSecondary)
            }
            VStack(spacing: 4) {
                Text(emptyTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MC.textPrimary)
                Text(emptySubtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(MC.textTertiary)
                    .multilineTextAlignment(.center)
            }
            if store.data.clients.isEmpty {
                Button("Add your first client") { store.showAddSheet = true }
                    .buttonStyle(MCButtonStyle(variant: .primary))
            } else {
                Button("Add another") { store.showAddSheet = true }
                    .buttonStyle(MCButtonStyle(variant: .secondary))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var emptyTitle: String {
        if store.search.isEmpty { return "No clients match" }
        return "Nothing matches \"\(store.search)\""
    }
    private var emptySubtitle: String {
        if store.data.clients.isEmpty {
            return "Press ⌘N to add one, or use the + button above."
        }
        return "Try a different search, or add one with the + button."
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

enum Formatters {
    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

    private func amountString(_ amt: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amt)) ?? "$\(Int(amt))"
    }

extension Comparable {
    func clampedTo(_ range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

