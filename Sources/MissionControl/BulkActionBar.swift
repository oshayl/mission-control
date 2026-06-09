// BulkActionBar.swift
// Floating bar at the bottom of the list when items are selected.

import SwiftUI

struct BulkActionBar: View {
    @EnvironmentObject var store: DataStore
    @State private var showTagSheet = false
    @State private var newTag = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("\(store.bulkSelectedIDs.count) selected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MC.textSecondary)
            Spacer()
            Button {
                store.bulkMarkContacted(ids: store.bulkSelectedIDs)
            } label: { Label("Contacted", systemImage: "checkmark.circle") }
                .buttonStyle(MCButtonStyle(variant: .secondary))

            Button {
                showTagSheet = true
            } label: { Label("Tag", systemImage: "tag") }
                .buttonStyle(MCButtonStyle(variant: .secondary))

            Button(role: .destructive) {
                store.bulkArchive(ids: store.bulkSelectedIDs)
                store.bulkSelectedIDs.removeAll()
            } label: { Label("Archive", systemImage: "archivebox") }
            .buttonStyle(MCButtonStyle(variant: .ghost))

            Button {
                store.bulkSelectedIDs.removeAll()
            } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(MC.textTertiary)
        }
        .padding(.horizontal, MC.pad)
        .padding(.vertical, 8)
        .background(MC.popoverBackground)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(MC.hairline), alignment: .top)
        .sheet(isPresented: $showTagSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add Tag").font(.headline)
                TextField("Tag name", text: $newTag)
                    .textFieldStyle(MCFieldStyle())
                HStack {
                    Spacer()
                    Button("Cancel") { showTagSheet = false; newTag = "" }
                    Button("Add") {
                        store.bulkTag(ids: store.bulkSelectedIDs, tag: newTag)
                        newTag = ""
                        showTagSheet = false
                    }
                    .buttonStyle(MCButtonStyle(variant: .primary))
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 360)
        }
    }
}
