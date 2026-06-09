// RootView.swift
// The SwiftUI popover content.

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: DataStore
    @State private var showCommandPalette = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .environmentObject(store)
            Divider().opacity(0.3)
            FilterBar()
                .environmentObject(store)
            Divider().opacity(0.3)
            if let selID = store.selectedClientID,
               let binding = bindingForClient(id: selID) {
                ClientDetail(client: binding, onBack: { store.selectedClientID = nil })
                    .environmentObject(store)
            } else {
                ClientList(onSelect: { store.selectedClientID = $0.id })
                    .environmentObject(store)
            }
        }
        .frame(width: 420, height: 560)
        .background(BackgroundLayer())
        .sheet(isPresented: $store.showAddSheet) {
            AddClientSheet(isPresented: $store.showAddSheet)
                .environmentObject(store)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPalette(isOpen: $showCommandPalette)
                .environmentObject(store)
        }
        .onKeyPress("k", phases: .down) { _ in
            if NSEvent.modifierFlags.contains(.command) {
                showCommandPalette = true
                return .handled
            }
            return .ignored
        }
    }

    private func bindingForClient(id: UUID) -> Binding<Client>? {
        guard let i = store.data.clients.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { store.data.clients[i] },
            set: { store.data.clients[i] = $0; store.data.clients[i].updatedAt = Date() }
        )
    }
}

struct BackgroundLayer: View {
    var body: some View {
        ZStack {
            // Frosted, dark-tinted base
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [Color.black.opacity(0.10), Color.black.opacity(0.02)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct HeaderView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Mission Control").font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            let s = store.stats
            StatPill(value: s.active, label: "active", color: .green)
            StatPill(value: s.stale, label: "stale", color: .orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    var subtitle: String {
        if let s = store.lastSync {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return "Synced \(f.localizedString(for: s, relativeTo: Date()))"
        }
        return "Loading…"
    }
}

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value) \(label)").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(color.opacity(0.10), in: Capsule())
    }
}

struct FilterBar: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clients, tags, notes…", text: $store.search)
                .textFieldStyle(.plain)
            Toggle(isOn: $store.showStaleOnly) { Text("Stale") }
                .toggleStyle(.button)
                .controlSize(.small)
                .font(.caption)
            Button {
                store.showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add client")
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}
