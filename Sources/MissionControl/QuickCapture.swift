// QuickCapture.swift
// Global hotkey (⌥⌘Space) for instant activity capture.
// Opens a tiny window, no popover, just type + Enter.

import SwiftUI
import AppKit
import Carbon

final class QuickCaptureController {
    static let shared = QuickCaptureController()
    private var window: NSWindow?
    private var hotKeyRef: EventHotKeyRef?

    func start() {
        let keyCode: UInt32 = 49   // Space
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var hotKeyID = EventHotKeyID(signature: OSType(0x4D435150), id: 2)  // "MCQP"
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, _, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let ctl = Unmanaged<QuickCaptureController>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { ctl.show() }
            return noErr
        }, 1, &eventType, userData, nil)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func show() {
        if let w = window, w.isVisible { w.makeKeyAndOrderFront(nil); return }
        let frame = NSRect(x: 0, y: 0, width: 540, height: 56)
        let win = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        win.title = "Quick Capture"
        win.titlebarAppearsTransparent = true
        win.isFloatingPanel = true
        win.becomesKeyOnlyIfNeeded = true
        win.level = .floating
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false
        win.center()
        let host = NSHostingController(rootView: QuickCaptureView(onClose: { [weak win] in
            win?.orderOut(nil)
        }))
        host.view.frame = frame
        win.contentViewController = host
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }
}

struct QuickCaptureView: View {
    let onClose: () -> Void
    @State private var text: String = ""
    @State private var taggedClient: Client? = nil
    @State private var allClients: [Client] = []
    @State private var clientQuery: String = ""
    @State private var showClientPicker: Bool = false
    @State private var kind: String = "note"
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: iconForKind)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MC.textSecondary)
                    .frame(width: 20)
                Picker("", selection: $kind) {
                    Text("Note").tag("note")
                    Text("Call").tag("call")
                    Text("Message").tag("message")
                    Text("Invoice").tag("invoice")
                    Text("Deploy").tag("deploy")
                }
                .labelsHidden()
                .frame(width: 90)
                if let c = taggedClient {
                    HStack(spacing: 4) {
                        Circle().fill(c.status.systemColor).frame(width: 5, height: 5)
                        Text(c.displayName)
                            .font(.system(size: 12, weight: .medium))
                        Button {
                            taggedClient = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(MC.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                            .fill(MC.textPrimary.opacity(0.05))
                    )
                } else {
                    Button {
                        showClientPicker = true
                        allClients = loadClients()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 11))
                            Text("Tag client")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .foregroundStyle(MC.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showClientPicker, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Find client…", text: $clientQuery)
                                .textFieldStyle(MCFieldStyle())
                            ScrollView {
                                VStack(spacing: 2) {
                                    ForEach(allClients.filter {
                                        clientQuery.isEmpty || $0.displayName.lowercased().contains(clientQuery.lowercased())
                                    }.prefix(8)) { c in
                                        Button {
                                            taggedClient = c
                                            showClientPicker = false
                                        } label: {
                                            HStack {
                                                Circle().fill(c.status.systemColor).frame(width: 6, height: 6)
                                                Text(c.displayName)
                                                    .font(.system(size: 12))
                                                Spacer()
                                            }
                                            .padding(.horizontal, 8).padding(.vertical, 5)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding(10)
                        .frame(width: 240)
                    }
                }
                TextField("What's on your mind?", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($focused)
                    .onSubmit { submit() }
                Text("↵")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(MC.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(MC.popoverBackground)
        .onAppear { focused = true }
        .onExitCommand { onClose() }
    }

    private var iconForKind: String {
        switch kind {
        case "call": return "phone.fill"
        case "message": return "message.fill"
        case "invoice": return "dollarsign.circle.fill"
        case "deploy": return "arrow.up.circle.fill"
        case "commit": return "chevron.left.forwardslash.chevron.right"
        default: return "note.text"
        }
    }

    private func loadClients() -> [Client] {
        // Read directly from disk for instant load (avoids passing DataStore through app context)
        let fm = FileManager.default
        let p = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? ""
        let url = URL(fileURLWithPath: p).appendingPathComponent("MissionControl/mission.json")
        if let data = try? Data(contentsOf: url),
           let d = try? JSONDecoder.iso.decode(MissionData.self, from: data) {
            return d.clients
        }
        return []
    }

    private func submit() {
        guard !text.isEmpty else { onClose(); return }
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? ""
        let url = URL(fileURLWithPath: appSupport).appendingPathComponent("MissionControl/mission.json")
        guard var data = try? JSONDecoder.iso.decode(MissionData.self, from: Data(contentsOf: url)) else {
            onClose(); return
        }
        let entry = ActivityEntry(timestamp: Date(), kind: kind, summary: text)
        if let id = taggedClient?.id, let i = data.clients.firstIndex(where: { $0.id == id }) {
            data.clients[i].activity.append(entry)
        } else {
            // No tag: add to "Inbox" client, or create one
            let inboxName = "Inbox"
            if let i = data.clients.firstIndex(where: { $0.name == inboxName }) {
                data.clients[i].activity.append(entry)
            } else {
                var c = Client(name: inboxName, status: .active)
                c.activity = [entry]
                data.clients.append(c)
            }
        }
        if let encoded = try? JSONEncoder.iso.encode(data) {
            try? encoded.write(to: url)
        }
        onClose()
    }
}
