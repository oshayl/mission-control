// AddClientSheet.swift
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("New Client").font(.headline)
                Spacer()
                Button("Cancel") { isPresented = false }
            }
            Form {
                TextField("Name", text: $name)
                TextField("Company", text: $company)
                Picker("Status", selection: $status) {
                    ForEach(ClientStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                TextField("Phone", text: $phone)
                TextField("Email", text: $email)
                TextField("iMessage", text: $imessage)
                TextField("GitHub Login", text: $github)
                TextField("Next Action", text: $nextAction)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Add") {
                    let c = Client(
                        name: name, company: company.isEmpty ? nil : company,
                        status: status, nextAction: nextAction.isEmpty ? nil : nextAction,
                        phone: phone.isEmpty ? nil : phone, email: email.isEmpty ? nil : email,
                        imessageHandle: imessage.isEmpty ? nil : imessage,
                        githubLogin: github.isEmpty ? nil : github
                    )
                    store.upsert(c)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 460)
    }
}
