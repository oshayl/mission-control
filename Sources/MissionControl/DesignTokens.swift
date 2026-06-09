// DesignTokens.swift
// Apple-clean design tokens. Every view uses these.

import SwiftUI

enum MC {
    // Surfaces — pure, no gradients
    static let popoverBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color.clear             // cards are never filled
    static let hairline = Color.primary.opacity(0.08)   // 1px separator
    static let rowHover = Color.primary.opacity(0.04)    // single hover state
    static let rowSelected = Color.accentColor.opacity(0.10)

    // Text — Apple system sizes
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // Accent — system default. Used sparingly.
    static let accent = Color.accentColor

    // Status — desaturated. No neon.
    static let statusActive = Color.green
    static let statusLead = Color.orange
    static let statusShipped = Color.blue
    static let statusPaused = Color.gray
    static let statusArchived = Color.secondary

    // Stale — a single warning color, not orange-everywhere
    static let stale = Color.orange

    // Sizing
    static let popoverWidth: CGFloat = 400
    static let popoverHeight: CGFloat = 620
    static let rowHeight: CGFloat = 48
    static let cornerRadius: CGFloat = 0  // no rounding on cards
    static let chipCornerRadius: CGFloat = 4  // only for inline chips

    // Spacing
    static let pad: CGFloat = 12
    static let padTight: CGFloat = 8
    static let padLoose: CGFloat = 16
}

extension ClientStatus {
    var systemColor: Color {
        switch self {
        case .active: return MC.statusActive
        case .lead: return MC.statusLead
        case .shipped: return MC.statusShipped
        case .paused: return MC.statusPaused
        case .archived: return MC.statusArchived
        }
    }
}
