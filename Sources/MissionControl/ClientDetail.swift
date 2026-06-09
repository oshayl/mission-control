// ClientDetail.swift
import SwiftUI
import AppKit

struct ClientDetail: View {
    @EnvironmentObject var store: DataStore
    @Binding var client: Client
    let onBack: () -> Void
    @State private var newActivityKind: String = "note"
    @State private var newActivityText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Avatar(client: client).scaleEffect(1.2)
                VStack(alignment: .leading) {
                    TextField("Name", text: $client.name).font(.headline).textFieldStyle(.plain)
                    TextField("Company", text: Binding($client.company, replacingNilWith: "")).font(.subheadline).textFieldStyle(.plain).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Status + next action
                    GroupBox("Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("", selection: $client.status) {
                                ForEach(ClientStatus.allCases, id: \.self) { s in
                                    Text(s.label).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("Next action").font(.caption).foregroundStyle(.secondary)
                            TextField("What's the next move?", text: Binding($client.nextAction, replacingNilWith: ""), axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)

                            HStack {
                                DatePicker("Due", selection: Binding(get: { client.nextActionDue ?? Date() }, set: { client.nextActionDue = $0 }), displayedComponents: [.date])
                                    .controlSize(.small)
                                Spacer()
                                Button("Clear") { client.nextActionDue = nil }
                                    .controlSize(.small)
                            }
                        }
                        .padding(6)
                    }

                    // Contact
                    GroupBox("Contact") {
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledField(label: "Phone", value: Binding($client.phone, replacingNilWith: ""), placeholder: "+1…")
                            LabeledField(label: "Email", value: Binding($client.email, replacingNilWith: ""), placeholder: "name@domain")
                            LabeledField(label: "iMessage", value: Binding($client.imessageHandle, replacingNilWith: ""), placeholder: "+1… or email")
                            LabeledField(label: "GitHub", value: Binding($client.githubLogin, replacingNilWith: ""), placeholder: "username")
                        }
                        .padding(6)
                    }

                    // iMessage activity (auto-detected)
                    if let lastMsg = store.lastIMessage(for: client) {
                        GroupBox("Last iMessage") {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(lastMsg.lastFromMe ? "You:" : "Them:")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(lastMsg.lastFromMe ? .blue : .green)
                                    Spacer()
                                    Text(lastMsg.lastMessageAt, style: .relative)
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                Text(lastMsg.lastMessageText)
                                    .font(.caption)
                                    .lineLimit(3)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(6)
                        }
                    }

                    // GitHub activity (auto-fetched)
                    if let g = client.githubLogin, !g.isEmpty {
                        GitHubActivityView(login: g) {
                            await store.githubActivity(for: client)
                        }
                    }

                    // Calendar — next meeting
                    CalendarEventView(client: client)

                    // Quick actions
                    HStack(spacing: 6) {
                        ActionButton(title: "iMessage", system: "message.fill") {
                            if let h = client.imessageHandle, !h.isEmpty { openIMessage(to: h) }
                        }
                        ActionButton(title: "Call", system: "phone.fill") {
                            if let p = client.phone, !p.isEmpty { openTel(p) }
                        }
                        ActionButton(title: "Email", system: "envelope.fill") {
                            if let e = client.email, !e.isEmpty { openMail(to: e) }
                        }
                        ActionButton(title: "GitHub", system: "chevron.left.forwardslash.chevron.right") {
                            if let g = client.githubLogin, !g.isEmpty {
                                if let url = URL(string: "https://github.com/\(g)") { NSWorkspace.shared.open(url) }
                            }
                        }
                    }
                    .padding(.horizontal, 4)

                    // Activity log
                    GroupBox("Activity") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Picker("", selection: $newActivityKind) {
                                    Text("Note").tag("note")
                                    Text("Call").tag("call")
                                    Text("Message").tag("message")
                                    Text("Invoice").tag("invoice")
                                    Text("Deploy").tag("deploy")
                                    Text("Commit").tag("commit")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 130)
                                TextField("Add a quick activity…", text: $newActivityText)
                                Button {
                                    guard !newActivityText.isEmpty else { return }
                                    let entry = ActivityEntry(timestamp: Date(), kind: newActivityKind, summary: newActivityText)
                                    if client.projects.isEmpty {
                                        // store-level activity fallback: keep on client via notes append
                                        client.notes += (client.notes.isEmpty ? "" : "\n") + "[\(newActivityKind)] \(newActivityText)"
                                    } else {
                                        client.projects[0].activity.append(entry)
                                    }
                                    newActivityText = ""
                                    store.upsert(client)
                                } label: { Image(systemName: "plus.circle.fill") }
                                .buttonStyle(.borderless)
                            }
                            Divider().opacity(0.3)
                            let entries = client.projects.first?.activity ?? []
                            if entries.isEmpty {
                                Text("No activity yet.").font(.caption).foregroundStyle(.secondary)
                            } else {
                                ForEach(entries.sorted(by: { $0.timestamp > $1.timestamp })) { e in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: iconFor(e.kind))
                                            .foregroundStyle(colorFor(e.kind))
                                            .frame(width: 14)
                                        VStack(alignment: .leading) {
                                            Text(e.summary).font(.caption)
                                            Text(e.timestamp, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(6)
                    }

                    // Notes
                    GroupBox("Notes") {
                        TextEditor(text: $client.notes)
                            .font(.caption)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(4)
                    }
                }
                .padding(12)
            }

            Divider().opacity(0.3)
            HStack {
                Button(role: .destructive) {
                    store.delete(id: client.id)
                    onBack()
                } label: { Label("Delete", systemImage: "trash") }
                Spacer()
                Button("Done") {
                    store.upsert(client)
                    onBack()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(10)
        }
        .onChange(of: client) { _, new in
            store.upsert(new)
        }
    }

    private func iconFor(_ kind: String) -> String {
        switch kind {
        case "call": return "phone.fill"
        case "message": return "message.fill"
        case "invoice": return "dollarsign.circle.fill"
        case "deploy": return "arrow.up.circle.fill"
        case "commit": return "chevron.left.forwardslash.chevron.right"
        default: return "note.text"
        }
    }
    private func colorFor(_ kind: String) -> Color {
        switch kind {
        case "call": return .green
        case "message": return .blue
        case "invoice": return .orange
        case "deploy": return .purple
        case "commit": return .indigo
        default: return .secondary
        }
    }
}

struct LabeledField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .trailing)
            TextField(placeholder, text: $value)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
        }
    }
}

struct ActionButton: View {
    let title: String
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: system)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith nilValue: String) {
        self.init(
            get: { source.wrappedValue ?? nilValue },
            set: { newValue in
                source.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}

// MARK: - External app launchers

func openIMessage(to handle: String) {
    // On macOS, `imessage://` opens Messages app pre-targeted. Falls back gracefully.
    // `sms:` is iOS-only; we use `messages:` for phone numbers and `mailto:` for emails.
    let s = handle.trimmingCharacters(in: .whitespaces)
    if s.contains("@") {
        if let url = URL(string: "imessage://\(s)") { NSWorkspace.shared.open(url) }
    } else {
        if let url = URL(string: "messages://\(s)") { NSWorkspace.shared.open(url) }
    }
}
func openTel(_ phone: String) {
    let p = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
    if let url = URL(string: "tel:\(p)") { NSWorkspace.shared.open(url) }
}
func openMail(to email: String) {
    if let url = URL(string: "mailto:\(email)") { NSWorkspace.shared.open(url) }
}
