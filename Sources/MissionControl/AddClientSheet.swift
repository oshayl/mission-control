// AddClientSheet.swift
// Apple-clean new-client form. Single column, placeholder-as-label, no chrome.

import SwiftUI

struct AddClientSheet: View {
    @EnvironmentObject var store: DataStore
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var company: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var imessage: String = ""
    @State private var github: String = ""
    @State private var nextAction: String = ""
    @State private var status: ClientStatus = .lead
    @State private var tags: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(MC.textSecondary)
                Spacer()
                Text("New Client")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Add") { commit() }
                    .buttonStyle(MCButtonStyle(variant: .primary))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider().background(MC.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Identity") {
                        bigField("Name", text: $name, placeholder: "John Wilbers", focused: $nameFocused)
                        bigField("Company", text: $company, placeholder: "Wilbers Law Firm (optional)")
                    }
                    section("Status") {
                        Picker("", selection: $status) {
                            ForEach(ClientStatus.allCases, id: \.self) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    section("Reach them") {
                        bigField("Phone", text: $phone, placeholder: "+1 314 555 1234")
                        bigField("Email", text: $email, placeholder: "name@domain.com")
                        bigField("iMessage", text: $imessage, placeholder: "+1… or email")
                        bigField("GitHub", text: $github, placeholder: "username")
                    }
                    section("Action") {
                        bigField("Next action", text: $nextAction, placeholder: "What's the next move?")
                        bigField("Tags", text: $tags, placeholder: "retainer, legal, stl (comma-separated)")
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 560)
        .background(MC.popoverBackground)
        .onAppear { nameFocused = true }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(MC.textTertiary)
            content()
        }
    }

    private func bigField(_ label: String, text: Binding<String>, placeholder: String, focused: FocusState<Bool>.Binding? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(MC.textTertiary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                        .stroke(MC.hairline, lineWidth: 1)
                )
                .if(focused != nil) { view in
                    view.focused(focused!)
                }
        }
    }

    private func commit() {
        let c = Client(
            name: name,
            company: company.isEmpty ? nil : company,
            status: status,
            nextAction: nextAction.isEmpty ? nil : nextAction,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            imessageHandle: imessage.isEmpty ? nil : imessage,
            githubLogin: github.isEmpty ? nil : github,
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        )
        store.upsert(c)
        isPresented = false
    }
}

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }
}
