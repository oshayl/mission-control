// SettingsView.swift
// Apple-clean settings. Sections, hairline dividers, no Form chrome.

import SwiftUI
import ServiceManagement
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @Binding var isOpen: Bool
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var notificationsEnabled = false
    @State private var staleDays: Double = 14
    @State private var webhookRunning = WebhookServer.shared.running

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done") { isOpen = false }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(MCButtonStyle(variant: .primary))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider().background(MC.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("System") {
                        ToggleRow(
                            title: "Launch Mission Control at login",
                            subtitle: "Auto-start when you sign in",
                            isOn: $launchAtLogin
                        ) { newValue in
                            do {
                                if newValue { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                            } catch {
                                NSLog("Login item error: \(error)")
                            }
                        }
                    }

                    section("Notifications") {
                        ToggleRow(
                            title: "Stale client nudges",
                            subtitle: notificationsEnabled
                                ? "Posted daily when active clients need attention"
                                : "Grant permission to enable",
                            isOn: .constant(notificationsEnabled)
                        ) { _ in
                            Task {
                                await NotificationsManager.shared.requestAuthorization()
                                await checkAuth()
                            }
                        }
                        .allowsHitTesting(!notificationsEnabled)
                    }

                    section("Stale threshold") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(Int(staleDays)) days")
                                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                Spacer()
                                Text("After this, clients show as stale.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(MC.textTertiary)
                            }
                            Slider(value: $staleDays, in: 3...60, step: 1) {
                                EmptyView()
                            }
                            .onChange(of: staleDays) { _, new in
                                store.data.settings.staleDays = Int(new)
                            }
                        }
                    }

                    section("Webhook") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lead ingestion endpoint")
                                    .font(.system(size: 12, weight: .medium))
                                Text("POST JSON to http://127.0.0.1:8787/lead")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(MC.textTertiary)
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(webhookRunning ? MC.statusActive : MC.stale)
                                    .frame(width: 6, height: 6)
                                Text(webhookRunning ? "live" : "off")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(MC.textTertiary)
                            }
                        }
                    }

                    section("Storage") {
                        pathRow("Local", path: localPath)
                        pathRow("iCloud", path: iCloudPath)
                        HStack {
                            Button("Open in Finder") { openInFinder(localPath) }
                                .buttonStyle(MCButtonStyle(variant: .secondary))
                            Spacer()
                            Button("Force Save") { store.save() }
                                .buttonStyle(MCButtonStyle(variant: .secondary))
                        }
                    }

                    section("About") {
                        LabeledRow("Version", value: "1.4")
                        LabeledRow("GitHub", value: "oshayl/mission-control", monospaced: true)
                        LabeledRow("Build", value: ISO8601DateFormatter().string(from: Date()), monospaced: true)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 540, height: 560)
        .background(MC.popoverBackground)
        .task {
            await checkAuth()
            staleDays = Double(store.data.settings.staleDays)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(MC.textTertiary)
            content()
        }
    }

    private func pathRow(_ label: String, path: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MC.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(path)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(MC.textTertiary)
                .textSelection(.enabled)
                .lineLimit(2)
            Spacer()
        }
    }

    private var localPath: String {
        let p = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? ""
        return "\(p)/MissionControl/mission.json"
    }

    private var iCloudPath: String {
        if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            return "\(url.path)/Documents/mission.json"
        }
        return "— (iCloud Drive not signed in)"
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

// MARK: - Helper rows

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let onTap: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MC.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(MC.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: isOn) { _, new in
                    if new { onTap(new) }
                }
        }
    }
}

struct LabeledRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false
    init(_ label: String, value: String, monospaced: Bool = false) {
        self.label = label
        self.value = value
        self.monospaced = monospaced
    }
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MC.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: monospaced ? .monospaced : .default))
                .foregroundStyle(MC.textTertiary)
                .textSelection(.enabled)
        }
    }
}
