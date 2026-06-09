// ClientDetail.swift
// Apple-clean detail. Single flowing layout, hairline dividers, no boxy panels.

import SwiftUI
import AppKit

struct ClientDetail: View {
    @EnvironmentObject var store: DataStore
    @Binding var client: Client
    let onBack: () -> Void
    @State private var newActivityKind: String = "note"
    @State private var newActivityText: String = ""
    @State private var showTagEditor = false
    @State private var newTag = ""
    @FocusState private var notesFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider().background(MC.hairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Identity + status inline
                    identityBlock

                    // Quick actions row
                    actionRow

                    // Activity stream
                    activityBlock

                    // Next action (only if set)
                    if let next = client.nextAction, !next.isEmpty {
                        nextActionBlock(next: next)
                    } else {
                        nextActionBlock(next: nil)
                    }

                    // Calendar (next meeting)
                    CalendarEventView(client: client)

                    // Contact details
                    contactBlock

                    // Tags
                    tagsBlock

                    // Notes
                    notesBlock

                    // Danger zone
                    dangerZone

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, MC.pad)
                .padding(.top, 18)
            }
        }
        .onChange(of: client) { _, new in
            store.upsert(new)
        }
        .sheet(isPresented: $showTagEditor) {
            VStack(spacing: 14) {
                Text("Add Tag").font(.system(size: 13, weight: .semibold))
                TextField("tag-name", text: $newTag)
                    .textFieldStyle(MCFieldStyle())
                HStack {
                    Button("Cancel") { showTagEditor = false; newTag = "" }
                        .buttonStyle(MCButtonStyle(variant: .ghost))
                    Spacer()
                    Button("Add") {
                        let t = newTag.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty && !client.tags.contains(t) {
                            client.tags.append(t)
                            newTag = ""
                        }
                        showTagEditor = false
                    }
                    .buttonStyle(MCButtonStyle(variant: .primary))
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 340)
            .background(MC.popoverBackground)
        }
    }

    // MARK: - Header

    private var detailHeader: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MC.textSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(client.status.label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(client.status.systemColor)
        }
        .padding(.horizontal, MC.pad)
        .padding(.vertical, 10)
    }

    // MARK: - Identity

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(MC.textPrimary.opacity(0.04))
                    Text(client.initials.uppercased())
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(MC.textSecondary)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Name", text: $client.name)
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.5)
                        .textFieldStyle(.plain)
                    if let co = client.company, !co.isEmpty {
                        TextField("Company", text: optionalString($client.company))
                            .font(.system(size: 12))
                            .foregroundStyle(MC.textTertiary)
                            .textFieldStyle(.plain)
                    } else {
                        TextField("Add company", text: optionalString($client.company))
                            .font(.system(size: 12))
                            .foregroundStyle(MC.textTertiary)
                            .textFieldStyle(.plain)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Quick Actions

    private var actionRow: some View {
        HStack(spacing: 8) {
            if let h = client.imessageHandle, !h.isEmpty {
                actionChip(title: "Message", system: "message.fill", tint: MC.statusShipped) { openIMessage(to: h) }
            }
            if let p = client.phone, !p.isEmpty {
                actionChip(title: "Call", system: "phone.fill", tint: MC.statusActive) { openTel(p) }
            }
            if let e = client.email, !e.isEmpty {
                actionChip(title: "Email", system: "envelope.fill", tint: .indigo) { openMail(to: e) }
            }
            if let g = client.githubLogin, !g.isEmpty, let url = URL(string: "https://github.com/\(g)") {
                actionChip(title: "@\(g)", system: "chevron.left.forwardslash.chevron.right", tint: .purple) {
                    NSWorkspace.shared.open(url)
                }
            }
            Spacer()
            if !client.isStale {
                Button {
                    client.lastContact = Date()
                } label: {
                    Label("Mark Contacted", systemImage: "checkmark.circle")
                }
                .buttonStyle(MCButtonStyle(variant: .secondary))
            }
        }
    }

    private func actionChip(title: String, system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: system)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(
                RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                    .fill(tint.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Next action

    private func nextActionBlock(next: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("NEXT ACTION")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MC.textTertiary)
                if let due = client.nextActionDue {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(due, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(due < Date() ? MC.stale : MC.textTertiary)
                }
                Spacer()
                if client.nextActionDue != nil {
                    Button {
                        NotificationsManager.shared.scheduleFollowUp(
                            client: client,
                            at: client.nextActionDue!,
                            message: client.nextAction ?? "Check in with \(client.displayName)"
                        )
                    } label: {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MC.accent)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 14))
                    .foregroundStyle(MC.accent)
                    .padding(.top, 1)
                TextField("What's the next move?", text: optionalString($client.nextAction), axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(2...4)
            }
            HStack {
                DatePicker("", selection: Binding(
                    get: { client.nextActionDue ?? Date() },
                    set: { client.nextActionDue = $0 }
                ), displayedComponents: [.date])
                    .labelsHidden()
                    .controlSize(.small)
                if client.nextActionDue != nil {
                    Button("Clear date") { client.nextActionDue = nil }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(MC.textTertiary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Activity

    private var activityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ACTIVITY")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MC.textTertiary)
                Spacer()
                Text("last \(client.activity.count + (store.lastIMessage(for: client) != nil ? 1 : 0))")
                    .font(.system(size: 9.5))
                    .foregroundStyle(MC.textTertiary)
            }
            HStack(spacing: 6) {
                Picker("", selection: $newActivityKind) {
                    Text("Note").tag("note")
                    Text("Call").tag("call")
                    Text("Message").tag("message")
                    Text("Invoice").tag("invoice")
                    Text("Deploy").tag("deploy")
                }
                .labelsHidden()
                .frame(width: 84)
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
            ActivityStream(client: client)
        }
    }

    // MARK: - Contact

    private var contactBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("CONTACT")
            contactRow(label: "Phone", system: "phone", value: optionalString($client.phone), placeholder: "+1…")
            contactRow(label: "Email", system: "envelope", value: optionalString($client.email), placeholder: "name@domain")
            contactRow(label: "iMessage", system: "message", value: optionalString($client.imessageHandle), placeholder: "+1… or email")
            contactRow(label: "GitHub", system: "chevron.left.forwardslash.chevron.right", value: optionalString($client.githubLogin), placeholder: "username")
        }
    }

    private func contactRow(label: String, system: String, value: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: system)
                .font(.system(size: 11))
                .foregroundStyle(MC.textTertiary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MC.textSecondary)
                .frame(width: 70, alignment: .leading)
            TextField(placeholder, text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(MC.textPrimary)
        }
    }

    // MARK: - Tags

    private var tagsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("TAGS")
            FlowLayout(spacing: 6) {
                ForEach(client.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(MC.textSecondary)
                        Button {
                            client.tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(MC.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                            .fill(MC.textPrimary.opacity(0.05))
                    )
                }
                Button {
                    showTagEditor = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .medium))
                        Text("Add")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(MC.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Notes

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NOTES")
            TextEditor(text: $client.notes)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                        .fill(MC.textPrimary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                        .stroke(MC.hairline, lineWidth: 1)
                )
                .focused($notesFocused)
        }
    }

    // MARK: - Danger

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("MORE")
            HStack {
                Button {
                    client.status = (client.status == .archived) ? .active : .archived
                } label: {
                    Label(client.status == .archived ? "Unarchive" : "Archive",
                          systemImage: client.status == .archived ? "tray.and.arrow.up" : "archivebox")
                }
                .buttonStyle(MCButtonStyle(variant: .ghost))

                Spacer()

                Button(role: .destructive) {
                    store.delete(id: client.id)
                    onBack()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(MCButtonStyle(variant: .ghost))
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(MC.textTertiary)
    }
}

// MARK: - Flow layout for tag chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
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

// MARK: - Launchers

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

func optionalString(_ source: Binding<String?>) -> Binding<String> {
    Binding(
        get: { source.wrappedValue ?? "" },
        set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
    )
}
