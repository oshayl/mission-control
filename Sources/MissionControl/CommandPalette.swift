// CommandPalette.swift
// Spotlight-style quick-action palette. ⌘K.

import SwiftUI
import AppKit

struct CommandPalette: View {
    @EnvironmentObject var store: DataStore
    @Binding var isOpen: Bool
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    struct Command: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let system: String
        let tint: Color
        let section: String
        let action: () -> Void
        static func == (lhs: Command, rhs: Command) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    private var commands: [Command] {
        var cmds: [Command] = []

        // Per-client commands
        for c in store.filteredClients {
            let tint = c.status.systemColor
            cmds.append(Command(title: "Open \(c.displayName)", subtitle: c.nextAction ?? c.notes, system: "person.crop.circle", tint: tint, section: "Clients", action: { store.selectedClientID = c.id }))
            if let phone = c.phone, !phone.isEmpty {
                cmds.append(Command(title: "Call \(c.displayName)", subtitle: phone, system: "phone.fill", tint: MC.statusActive, section: "Actions", action: { openTel(phone) }))
            }
            if let im = c.imessageHandle, !im.isEmpty {
                cmds.append(Command(title: "Message \(c.displayName)", subtitle: im, system: "message.fill", tint: MC.statusShipped, section: "Actions", action: { openIMessage(to: im) }))
            }
            if let em = c.email, !em.isEmpty {
                cmds.append(Command(title: "Email \(c.displayName)", subtitle: em, system: "envelope.fill", tint: .indigo, section: "Actions", action: { openMail(to: em) }))
            }
            if let gh = c.githubLogin, !gh.isEmpty {
                cmds.append(Command(title: "GitHub · @\(gh)", subtitle: "Open profile", system: "chevron.left.forwardslash.chevron.right", tint: .purple, section: "Actions", action: {
                    if let u = URL(string: "https://github.com/\(gh)") { NSWorkspace.shared.open(u) }
                }))
            }
            if let due = c.nextActionDue {
                cmds.append(Command(title: "Schedule follow-up · \(c.displayName)", subtitle: "9 AM \(due.formatted(date: .abbreviated, time: .omitted))", system: "bell.badge", tint: MC.accent, section: "Schedule", action: {
                    NotificationsManager.shared.scheduleFollowUp(client: c, at: due, message: c.nextAction ?? "Check in with \(c.displayName)")
                }))
            }
        }

        // Global
        cmds.append(Command(title: "Add new client", subtitle: nil, system: "plus.circle.fill", tint: MC.accent, section: "Actions", action: { store.showAddSheet = true }))
        cmds.append(Command(title: "Open settings", subtitle: "⌘,", system: "gearshape", tint: MC.textSecondary, section: "Actions", action: { store.showSettings = true }))
        cmds.append(Command(title: "Save now", subtitle: "Force iCloud sync", system: "square.and.arrow.down", tint: MC.textSecondary, section: "Actions", action: { store.save() }))
        cmds.append(Command(title: "Reload from iCloud", subtitle: nil, system: "arrow.clockwise", tint: MC.textSecondary, section: "Actions", action: { store.load() }))
        cmds.append(Command(title: "Quit Mission Control", subtitle: nil, system: "power", tint: MC.stale, section: "Actions", action: { NSApp.terminate(nil) }))

        return cmds
    }

    private var filtered: [Command] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return commands }
        return commands.filter {
            $0.title.lowercased().contains(q) || ($0.subtitle?.lowercased().contains(q) ?? false) || $0.section.lowercased().contains(q)
        }
    }

    private var grouped: [(String, [Command])] {
        let groups = Dictionary(grouping: filtered, by: { $0.section })
        return ["Clients", "Actions", "Schedule"].compactMap { name in
            guard let g = groups[name], !g.isEmpty else { return nil }
            return (name, g)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().background(MC.hairline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                        sectionHeader(group.0)
                        ForEach(Array(group.1.enumerated()), id: \.offset) { idx, cmd in
                            CommandRow(cmd: cmd, isSelected: isSelected(cmd))
                                .onTapGesture { run(cmd) }
                                .padding(.horizontal, MC.pad)
                        }
                    }
                    if filtered.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22, weight: .light))
                                .foregroundStyle(MC.textTertiary)
                            Text("No commands match")
                                .font(.system(size: 12))
                                .foregroundStyle(MC.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical, 8)
            }
            Divider().background(MC.hairline)
            footer
        }
        .frame(width: 560, height: 420)
        .background(MC.popoverBackground)
        .onAppear {
            searchFocused = true
            selectedIndex = 0
        }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onKeyPress(.downArrow) { selectedIndex = min(filtered.count - 1, selectedIndex + 1); return .handled }
        .onKeyPress(.upArrow) { selectedIndex = max(0, selectedIndex - 1); return .handled }
        .onKeyPress(.return) {
            if filtered.indices.contains(selectedIndex) { run(filtered[selectedIndex]) }
            return .handled
        }
        .onKeyPress(.escape) { isOpen = false; return .handled }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(MC.textTertiary)
            TextField("Search clients, actions, or type a command…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(MC.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MC.pad)
        .padding(.vertical, 14)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(MC.textTertiary)
            .padding(.horizontal, MC.pad)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            chip("↑↓", label: "navigate")
            chip("↵", label: "run")
            chip("esc", label: "close")
            Spacer()
            Text("\(filtered.count) result\(filtered.count == 1 ? "" : "s")")
                .font(.system(size: 10.5))
                .foregroundStyle(MC.textTertiary)
        }
        .padding(.horizontal, MC.pad)
        .padding(.vertical, 8)
    }

    private func chip(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MC.textPrimary.opacity(0.06))
                )
                .foregroundStyle(MC.textSecondary)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(MC.textTertiary)
        }
    }

    private func isSelected(_ cmd: Command) -> Bool {
        guard filtered.indices.contains(selectedIndex) else { return false }
        return filtered[selectedIndex].id == cmd.id
    }

    private func run(_ cmd: Command) {
        cmd.action()
        isOpen = false
    }
}

struct CommandRow: View {
    let cmd: CommandPalette.Command
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: cmd.system)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(cmd.tint)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(cmd.tint.opacity(0.10))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(cmd.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MC.textPrimary)
                    .lineLimit(1)
                if let s = cmd.subtitle, !s.isEmpty {
                    Text(s)
                        .font(.system(size: 11))
                        .foregroundStyle(MC.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? MC.textPrimary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
