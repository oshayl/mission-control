// CommandPalette.swift
// ⌘K quick-action palette.

import SwiftUI
import AppKit

struct CommandPalette: View {
    @EnvironmentObject var store: DataStore
    @Binding var isOpen: Bool
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0

    struct Command: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let system: String
        let action: () -> Void
        static func == (lhs: Command, rhs: Command) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var commands: [Command] {
        var cmds: [Command] = []
        // Per-client commands
        for c in store.filteredClients {
            cmds.append(Command(
                title: "Open \(c.displayName)",
                subtitle: c.nextAction ?? c.notes,
                system: "person.crop.circle",
                action: { store.selectedClientID = c.id }
            ))
            if let phone = c.phone, !phone.isEmpty {
                cmds.append(Command(
                    title: "Call \(c.displayName)",
                    subtitle: phone, system: "phone.fill",
                    action: { openTel(phone) }
                ))
            }
            if let im = c.imessageHandle, !im.isEmpty {
                cmds.append(Command(
                    title: "iMessage \(c.displayName)",
                    subtitle: im, system: "message.fill",
                    action: { openIMessage(to: im) }
                ))
            }
            if let em = c.email, !em.isEmpty {
                cmds.append(Command(
                    title: "Email \(c.displayName)",
                    subtitle: em, system: "envelope.fill",
                    action: { openMail(to: em) }
                ))
            }
            if let gh = c.githubLogin, !gh.isEmpty {
                cmds.append(Command(
                    title: "GitHub · @\(gh)",
                    subtitle: "Open profile", system: "chevron.left.forwardslash.chevron.right",
                    action: {
                        if let u = URL(string: "https://github.com/\(gh)") { NSWorkspace.shared.open(u) }
                    }
                ))
            }
        }
        // Global commands
        cmds.append(Command(title: "Add new client", subtitle: nil, system: "plus.circle", action: { store.showAddSheet = true }))
        cmds.append(Command(title: "Save now", subtitle: "Force save + iCloud sync", system: "square.and.arrow.down", action: { store.save() }))
        cmds.append(Command(title: "Reload from iCloud", subtitle: "Discard local changes", system: "arrow.clockwise", action: { store.load() }))
        cmds.append(Command(title: "Quit Mission Control", subtitle: nil, system: "power", action: { NSApp.terminate(nil) }))
        return cmds
    }

    var filtered: [Command] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return commands }
        return commands.filter {
            $0.title.lowercased().contains(q) || ($0.subtitle?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Type a command or search…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.body)
                Text("ESC").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Divider().opacity(0.2)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filtered.enumerated()), id: \.offset) { idx, cmd in
                        CommandRow(cmd: cmd, isSelected: idx == selectedIndex)
                            .onTapGesture { run(cmd) }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
            }
        }
        .frame(width: 520, height: 380)
        .background(MC.popoverBackground)
        .onAppear { selectedIndex = 0 }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onKeyPress(.downArrow) { selectedIndex = min(filtered.count - 1, selectedIndex + 1); return .handled }
        .onKeyPress(.upArrow) { selectedIndex = max(0, selectedIndex - 1); return .handled }
        .onKeyPress(.return) {
            if filtered.indices.contains(selectedIndex) { run(filtered[selectedIndex]) }
            return .handled
        }
        .onKeyPress(.escape) { isOpen = false; return .handled }
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
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.06))
                )
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(cmd.title).font(.subheadline)
                if let s = cmd.subtitle, !s.isEmpty {
                    Text(s).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
    }
}
