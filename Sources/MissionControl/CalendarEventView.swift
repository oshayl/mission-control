// CalendarEventView.swift
import SwiftUI
import AppKit

struct CalendarEventView: View {
    let client: Client
    @State private var event: CalendarEventLite? = nil
    @State private var loaded = false
    @State private var denied = false

    var body: some View {
        Group {
            if let ev = event {
                GroupBox("Next meeting") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "calendar.circle.fill").foregroundStyle(.red)
                            Text(ev.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.caption2)
                            Text(ev.start, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let loc = ev.location, !loc.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse").font(.caption2)
                                Text(loc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        HStack {
                            Text(ev.calendar).font(.caption2).foregroundStyle(.tertiary)
                            Spacer()
                            if let u = ev.url, let url = URL(string: u) {
                                Button("Open") { NSWorkspace.shared.open(url) }
                                    .controlSize(.mini)
                            }
                        }
                    }
                    .padding(6)
                }
            } else if denied {
                GroupBox("Calendar") {
                    Text("Calendar access denied. Grant in System Settings → Privacy → Calendars.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(6)
                }
            } else if loaded {
                GroupBox("Calendar") {
                    Text("No upcoming meetings with this client.").font(.caption).foregroundStyle(.secondary).padding(6)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        let granted = await CalendarReader.shared.requestAccess()
        await MainActor.run {
            if !granted { self.denied = true; self.loaded = true; return }
        }
        let ev = await CalendarReader.shared.nextEvent(for: client)
        await MainActor.run {
            self.event = ev
            self.loaded = true
        }
    }
}
