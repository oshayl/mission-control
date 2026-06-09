// ClientDetail.swift
// Apple-clean detail. Sections separated by hairlines, no panel chrome.

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
            detailHeader
            Divider().background(MC.hairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusSection
                    contactSection
                    calendarSection
                    activityStreamSection
                    notesSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, MC.pad)
                .padding(.top, 16)
            }
            Divider().background(MC.hairline)
            detailFooter
        }
        .onChange(of: client) { _, new in
            store.upsert(new)
        }
    }

    // MARK: - Header

    private var detailHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MC.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            Text(client.initials.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(MC.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(MC.hairline, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                TextField("Name", text: $client.name)
                    .font(.system(size: 14, weight: .semibold))
                    .textFieldStyle(.plain)
                if let co = client.company, !co.isEmpty {
                    Text(co)
                        .font(.system(size: 11))
                        .foregroundStyle(MC.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, MC.pad)
        .padding(.vertical, 10)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Status")
            Picker("", selection: $client.status) {
                ForEach(ClientStatus.allCases, id: \.self) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField("Next action", text: optionalString($client.nextAction))
                .textFieldStyle(MCFieldStyle())
                .font(.system(size: 13))

            HStack {
                DatePicker("Due", selection: Binding(
                    get: { client.nextActionDue ?? Date() },
                    set: { client.nextActionDue = $0 }
                ), displayedComponents: [.date])
                    .controlSize(.small)
                    .labelsHidden()
                if client.nextActionDue != nil {
                    Button("Clear") { client.nextActionDue = nil }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(MC.textTertiary)
                }
                Spacer()
                if let due = client.nextActionDue {
                    Button {
                        NotificationsManager.shared.scheduleFollowUp(
                            client: client,
                            at: due,
                            message: client.nextAction ?? "Check in with \(client.displayName)"
                        )
                    } label: {
                        Label("Remind 9 AM", systemImage: "bell")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(MCButtonStyle(variant: .secondary))
                }
            }
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Contact")
            field(label: "Phone", binding: $client.phone, placeholder: "+1…")
            field(label: "Email", binding: $client.email, placeholder: "name@domain")
            field(label: "iMessage", binding: $client.imessageHandle, placeholder: "+1… or email")
            field(label: "GitHub", binding: $client.githubLogin, placeholder: "username")

            HStack(spacing: 6) {
                actionButton(title: "Message", system: "message") {
                    if let h = client.imessageHandle, !h.isEmpty { openIMessage(to: h) }
                }
                actionButton(title: "Call", system: "phone") {
                    if let p = client.phone, !p.isEmpty { openTel(p) }
                }
                actionButton(title: "Email", system: "envelope") {
                    if let e = client.email, !e.isEmpty { openMail(to: e) }
                }
            }
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        CalendarEventView(client: client)
    }

    // MARK: - Activity stream (interleaved)

    private var activityStreamSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Activity")
            ActivityStream(client: client)
            HStack(spacing: 6) {
                Picker("", selection: $newActivityKind) {
                    Text("Note").tag("note")
                    Text("Call").tag("call")
                    Text("Message").tag("message")
                    Text("Invoice").tag("invoice")
                    Text("Deploy").tag("deploy")
                }
                .labelsHidden()
                .frame(width: 90)
                TextField("Log a quick note…", text: $newActivityText)
                    .textFieldStyle(MCFieldStyle())
                Button {
                    guard !newActivityText.isEmpty else { return }
                    client.activity.append(ActivityEntry(timestamp: Date(), kind: newActivityKind, summary: newActivityText))
                    newActivityText = ""
                    store.upsert(client)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(MC.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Notes")
            TextEditor(text: $client.notes)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                        .stroke(MC.hairline, lineWidth: 1)
                )
        }
    }

    // MARK: - Footer

    private var detailFooter: some View {
        HStack {
            Button(role: .destructive) {
                store.delete(id: client.id)
                onBack()
            } label: {
                Text("Delete")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(MC.stale)

            Spacer()

            Button("Done") {
                store.upsert(client)
                onBack()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(MCButtonStyle(variant: .primary))
        }
        .padding(.horizontal, MC.pad)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(MC.textTertiary)
    }

    private func field(label: String, binding: Binding<String?>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(MC.textTertiary)
                .frame(width: 64, alignment: .trailing)
            TextField(placeholder, text: optionalString(binding))
                .textFieldStyle(MCFieldStyle())
        }
    }

    private func actionButton(title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: system).font(.system(size: 11))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                    .stroke(MC.hairline, lineWidth: 1)
            )
            .foregroundStyle(MC.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Field style

struct MCFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                    .stroke(MC.hairline, lineWidth: 1)
            )
            .font(.system(size: 12))
    }
}

// MARK: - iMessage / tel / mail launchers

func openIMessage(to handle: String) {
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

func optionalString(_ source: Binding<String?>) -> Binding<String> {
    Binding(
        get: { source.wrappedValue ?? "" },
        set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
    )
}
