// GitHubActivityView.swift
import SwiftUI
import AppKit

struct GitHubActivityView: View {
    let login: String
    let fetcher: () async -> [GitHubActivity]
    @State private var items: [GitHubActivity] = []
    @State private var loading = false
    @State private var loaded = false
    @State private var error: String? = nil

    var body: some View {
        GroupBox("GitHub · @\(login)") {
            VStack(alignment: .leading, spacing: 6) {
                if loading && items.isEmpty {
                    HStack { ProgressView().controlSize(.small); Text("Loading…").font(.caption) }
                } else if let err = error {
                    Text(err).font(.caption).foregroundStyle(.red)
                } else if items.isEmpty && loaded {
                    Text("No recent public activity.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(items.prefix(5), id: \.self) { a in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: iconFor(a.kind))
                                .foregroundStyle(colorFor(a.kind))
                                .frame(width: 14)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(a.title).font(.caption).lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(a.repo).font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                                    Text("·").font(.caption2).foregroundStyle(.tertiary)
                                    Text(a.timestamp, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let u = a.url, let url = URL(string: u) { NSWorkspace.shared.open(url) }
                        }
                    }
                    if items.count > 5 {
                        Text("+\(items.count - 5) more").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        Task { await load() }
                    } label: { Image(systemName: "arrow.clockwise") }
                        .controlSize(.small)
                        .buttonStyle(.borderless)
                }
            }
            .padding(6)
        }
        .task { if !loaded { await load() } }
    }

    private func load() async {
        loading = true
        error = nil
        let result = await fetcher()
        items = result
        loaded = true
        loading = false
        if result.isEmpty { error = "No activity (rate-limited or private)." }
    }

    private func iconFor(_ kind: String) -> String {
        switch kind {
        case "push": return "arrow.up.circle.fill"
        case "pr": return "arrow.triangle.pull"
        case "issue": return "exclamationmark.circle"
        case "release": return "tag.fill"
        case "star": return "star.fill"
        case "fork": return "tuningfork"
        case "create": return "plus.circle"
        default: return "circle.fill"
        }
    }
    private func colorFor(_ kind: String) -> Color {
        switch kind {
        case "push": return .purple
        case "pr": return .blue
        case "issue": return .orange
        case "release": return .green
        case "star": return .yellow
        case "fork": return .indigo
        case "create": return .teal
        default: return .secondary
        }
    }
}
