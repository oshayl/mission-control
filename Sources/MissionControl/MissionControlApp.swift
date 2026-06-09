// MissionControlApp.swift
// Mission Control — main entry point
// Native macOS menu bar HUD for client + project awareness.

import SwiftUI
import AppKit
import Carbon
import Combine

@main
struct MissionControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let store = DataStore()
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar app only
        NSApp.setActivationPolicy(.accessory)

        // Register deep link handler
        DeepLinkHandler.shared.store = store
        DeepLinkHandler.shared.appDelegate = self
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        // Status item with SF Symbol — left-click toggles popover, right-click shows menu.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "scope", accessibilityDescription: "Mission Control")
            img?.isTemplate = true
            button.image = img
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Popover hosting the root SwiftUI view
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 560)
        let host = NSHostingController(rootView: RootView().environmentObject(store))
        popover.contentViewController = host

        // Right-click menu on status item (for quit, refresh, etc.)
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Mission Control", action: #selector(showPopover), keyEquivalent: "")
        menu.addItem(withTitle: "Command Palette…", action: #selector(openCommandPalette), keyEquivalent: "k")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Save Now", action: #selector(saveNow), keyEquivalent: "s")
        menu.addItem(withTitle: "Reload from iCloud", action: #selector(reloadFromCloud), keyEquivalent: "r")
        menu.addItem(withTitle: "Preferences…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Mission Control", action: #selector(quitApp), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        // Global hotkey ⌥⌘C (Carbon API)
        registerGlobalHotkey()

        // Refresh badge whenever data changes
        refreshBadgeObserver = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.updateBadge()
                }
            }
        }

        // Request notification permission
        Task { await NotificationsManager.shared.requestAuthorization() }

        // Watch iCloud file for external edits
        ICloudWatcher.shared.start { [weak self] in
            guard let self = self else { return }
            self.store.load()
            self.flashBadge()
        }

        // Start local webhook server for incoming leads (CRM integration)
        WebhookServer.shared.start(store: store)

        // Refresh badge
        updateBadge()
    }

    private var refreshBadgeObserver: AnyCancellable?

    @objc func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func saveNow() {
        store.save()
        flashBadge()
    }

    @objc func reloadFromCloud() {
        store.load()
        flashBadge()
    }

    @objc func openCommandPalette() {
        showPopover()
        // CommandPalette is presented from RootView; trigger it via a flag
        store.showCommandPalette = true
    }

    @objc func openSettings() {
        showPopover()
        store.showSettings = true
    }

    @objc func quitApp() {
        store.save()
        NSApp.terminate(nil)
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlStr = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlStr) else { return }
        DeepLinkHandler.shared.handle(url)
    }

    func updateBadge() {
        let stale = store.data.clients.filter { $0.isStale && $0.status == .active }.count
        guard let button = statusItem.button else { return }
        if stale > 0 {
            button.title = " \(stale)"
            button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: nil)
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: nil)
        }
    }

    private func flashBadge() {
        guard let button = statusItem.button else { return }
        let original = button.title
        button.title = " ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateBadge()
            _ = original
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func registerGlobalHotkey() {
        // ⌥⌘C → Carbon hotkey
        // Key code 8 = 'C' on US layout
        let keyCode: UInt32 = 8
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Install handler
        InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    appDelegate.showPopover()
                }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)

        var hotKeyID = EventHotKeyID(signature: OSType(0x4D434348), id: 1) // "MCCH"
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Mission Control: failed to register global hotkey (status \(status))")
        }
    }
}
