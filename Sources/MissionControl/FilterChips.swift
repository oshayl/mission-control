// FilterChips.swift
// Horizontal scroller of timeframe + tag chips.

import SwiftUI

struct FilterChips: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Timeframe.allCases) { tf in
                    chip(
                        title: tf.label,
                        isActive: store.timeframe == tf,
                        count: tf == .stale ? store.stats.stale : nil
                    ) {
                        store.timeframe = (store.timeframe == tf) ? .all : tf
                    }
                }
                if !store.allTags.isEmpty {
                    Divider().frame(height: 14).background(MC.hairline)
                    ForEach(store.allTags, id: \.self) { tag in
                        chip(
                            title: "#\(tag)",
                            isActive: store.tagFilter == tag,
                            count: nil
                        ) {
                            store.tagFilter = (store.tagFilter == tag) ? nil : tag
                        }
                    }
                }
            }
            .padding(.horizontal, MC.pad)
            .padding(.vertical, 6)
        }
    }

    private func chip(title: String, isActive: Bool, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(MC.textTertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                    .fill(isActive ? MC.textPrimary.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MC.chipCornerRadius)
                    .stroke(isActive ? MC.hairline : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isActive ? MC.textPrimary : MC.textTertiary)
        }
        .buttonStyle(.plain)
    }
}
