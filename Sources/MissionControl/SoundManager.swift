// SoundManager.swift
// Plays subtle system sounds for new activity. Off by default.

import Foundation
import AppKit

final class SoundManager {
    static let shared = SoundManager()
    private(set) var enabled: Bool = false

    private init() {
        enabled = UserDefaults.standard.bool(forKey: "mc.sound.enabled")
    }

    func setEnabled(_ v: Bool) {
        enabled = v
        UserDefaults.standard.set(v, forKey: "mc.sound.enabled")
    }

    func play(_ kind: Kind) {
        guard enabled else { return }
        let name: String
        switch kind {
        case .message: name = "Pop"
        case .github: name = "Tink"
        case .calendar: name = "Glass"
        case .invoice: name = "Hero"
        case .stale: name = "Bottle"
        }
        if let sound = NSSound(named: name) {
            sound.volume = 0.3
            sound.play()
        }
    }

    enum Kind { case message, github, calendar, invoice, stale }
}
