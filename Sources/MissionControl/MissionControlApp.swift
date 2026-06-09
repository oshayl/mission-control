// MissionControlApp.swift
// Mission Control — main entry point
// Native macOS menu bar HUD for client + project awareness.

import SwiftUI
import AppKit

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
    private var eventMonitor: Any?
    let store = DataStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar app only
        NSApp.setActivationPolicy(.accessory)

        // Status item with SF Symbol
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

        // Global hotkey: ⌥⌘C
        registerGlobalHotkey()
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
        // Register ⌥⌘C as the summon hotkey via Carbon-style registration.
        // We use NSEvent.addGlobalMonitorForEvents for now; Carbon hotkey in enhancement pass.
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            // Placeholder — Carbon RegisterEventHotKey will be wired in enhancements
            _ = self
        }
    }
}
