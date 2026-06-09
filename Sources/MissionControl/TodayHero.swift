// TodayHero.swift
// Above-list card highlighting the most pressing items.

import SwiftUI

struct TodayHero: View {
    @EnvironmentObject var store: DataStore

    private var dueThisWeek: [Client] {
        store.data.clients
            .filter { $0.status == .active }
            .filter { c in
                guard let d = c.nextActionDue else { return false }
                return d <= Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            }
            .sorted { ($0.nextActionDue ?? .distantFuture) < ($1.nextActionDue ?? .distantFuture) }
            .prefix(3)
            .map { $0 }
    }

    private var stale: [Client] {
        store.data.clients
            .filter { $0.status == .active && $0.isStale }
            .sorted { ($0.daysSinceContact ?? 999) > ($1.daysSinceContact ?? 999) }
            .prefix(2)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !dueThisWeek.isEmpty {
                heroSection(
                    label: "Due this week",
                    count: store.stats.dueThisWeek,
                    items: dueThisWeek,
                    accent: MC.accent
                )
            }
            if !stale.isEmpty {
                heroSection(
                    label: "Need attention",
                    count: store.stats.stale,
                    items: stale,
                    accent: MC.stale
                )
            }
            if dueThisWeek.isEmpty && stale.isEmpty {
                allClearCard
            }
        }
        .padding(.horizontal, MC.pad)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func heroSection(label: String, count: Int, items: [Client], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MC.textSecondary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(MC.textTertiary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { c in
                    HStack(spacing: 8) {
                        Text(c.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MC.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        if let due = c.nextActionDue {
                            Text(due, format: .relative(presentation: .named))
                                .font(.system(size: 10))
                                .foregroundStyle(MC.textTertiary)
                        } else if let d = c.daysSinceContact {
                            Text("\(d)d")
                                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(MC.stale)
                        }
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .onTapGesture { store.selectedClientID = c.id }
                    if c != items.last {
                        Divider().background(MC.hairline)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(MC.textPrimary.opacity(0.025))
            )
        }
    }

    private var allClearCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(MC.statusActive)
            VStack(alignment: .leading, spacing: 1) {
                Text("All caught up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MC.textPrimary)
                Text("Nothing due or stale. Inbox zero.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(MC.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(MC.statusActive.opacity(0.06))
        )
    }
}
