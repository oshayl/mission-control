// SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @Binding var isOpen: Bool
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var notificationsEnabled = false
    @State private var iCloudPath: String = "—"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { isOpen = false }.keyboardShortcut(.defaultAction)
            }
            Form {
                Section("General") {
                    Toggle("Launch Mission Control at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                NSLog("Login item error: \(error)")
                            }
                        }
                    HStack {
                        Text("Stale threshold")
                        Stepper("\(store.data.settings.staleDays) days", value: $store.data.settings.staleDays, in: 1...90)
                    }
                }
                Section("Notifications") {
                    HStack {
                        Text("Stale client nudges")
                        Spacer()
                        if notificationsEnabled {
                            Text("Enabled").foregroundStyle(.green).font(.caption)
                        } else {
                            Button("Enable") {
                                Task {
                                    await NotificationsManager.shared.requestAuthorization()
                                    await checkAuth()
                                }
                            }
                        }
                    }
                    Text("Posts a single daily summary when active clients haven't been touched in \(store.data.settings.staleDays)+ days.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Storage") {
                    LabeledContent("Local") { Text(localPath).font(.caption.monospaced()).foregroundStyle(.secondary) }
                    LabeledContent("iCloud") { Text(iCloudPath).font(.caption.monospaced()).foregroundStyle(.secondary) }
                    HStack {
                        Button("Open in Finder") { openInFinder(localPath) }
                        Spacer()
                        Button("Force Save") { store.save() }
                    }
                }
                Section("About") {
                    LabeledContent("Version") { Text("0.7").font(.caption) }
                    LabeledContent("Repo") { Text("github.com/oshayl/mission-control").font(.caption.monospaced()) }
                }
            }
            .formStyle(.grouped)
        }
        .padding(16)
        .frame(width: 520, height: 480)
        .task { await checkAuth() }
    }

    private var localPath: String {
        let p = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? ""
        return "\(p)/MissionControl/mission.json"
    }

    private func checkAuth() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private func openInFinder(_ path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        let dir = (expanded as NSString).deletingLastPathComponent
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: dir)])
    }
}

import UserNotifications
