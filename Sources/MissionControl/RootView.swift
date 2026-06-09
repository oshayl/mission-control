// RootView.swift
// The SwiftUI popover content — Apple-clean.

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: DataStore
    @State private var showCommandPalette = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .environmentObject(store)
            Divider().background(MC.hairline)
            FilterBar()
                .environmentObject(store)
            Divider().background(MC.hairline)
            FilterChips()
                .environmentObject(store)
            TodayHero()
                .environmentObject(store)
            Divider().background(MC.hairline)
            if let selID = store.selectedClientID,
               let binding = bindingForClient(id: selID) {
                ClientDetail(client: binding, onBack: { store.selectedClientID = nil })
                    .environmentObject(store)
            } else {
                ClientList(onSelect: { store.selectedClientID = $0.id })
                    .environmentObject(store)
            }
        }
        .frame(width: MC.popoverWidth, height: MC.popoverHeight)
        .background(MC.popoverBackground)
        .sheet(isPresented: $store.showAddSheet) {
            AddClientSheet(isPresented: $store.showAddSheet)
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showSettings) {
            SettingsView(isOpen: $store.showSettings)
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
        .onChange(of: store.showCommandPalette) { _, new in
            if new { showCommandPalette = true; store.showCommandPalette = false }
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

// MARK: - Header

struct HeaderView: View {
    @EnvironmentObject var store: DataStore
    @State private var now = Date()
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MC.textPrimary)
                Spacer()
                statsView
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(greeting)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MC.textPrimary)
                        .tracking(-0.4)
                    Text(dateString)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(MC.textTertiary)
                        .onReceive(tick) { _ in now = Date() }
                }
                Spacer()
            }
        }
        .padding(.horizontal, MC.pad)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning, O'Shay"
        case 12..<17: return "Good afternoon, O'Shay"
        case 17..<22: return "Good evening, O'Shay"
        default: return "Up late, O'Shay"
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: now)
    }

    @ViewBuilder
    private var statsView: some View {
        let s = store.stats
        HStack(spacing: 10) {
            if s.dueThisWeek > 0 {
                statPill(count: s.dueThisWeek, color: MC.accent, label: "due")
            }
            if s.stale > 0 {
                statPill(count: s.stale, color: MC.stale, label: "stale")
            }
            statPill(count: s.active, color: MC.statusActive, label: "active")
        }
    }

    private func statPill(count: Int, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(MC.textSecondary)
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(MC.textTertiary)
        }
    }
}

// MARK: - Filter Bar

struct FilterBar: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(MC.textTertiary)
                .frame(width: 14)
            TextField("Search", text: $store.search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !store.search.isEmpty {
                Button {
                    store.search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(MC.textTertiary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            Toggle(isOn: $store.showStaleOnly) { Text("Stale") }
                .toggleStyle(MCToggleStyle())
            Button {
                store.showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MC.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Add client")
        }
        .padding(.horizontal, MC.pad)
        .padding(.vertical, 8)
    }
}

struct MCToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(configuration.isOn ? MC.textPrimary : MC.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                        .fill(configuration.isOn ? MC.textPrimary.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}
