// ActivityChart.swift
// 30-day bar chart of activity events per client.

import SwiftUI

struct ActivityChart: View {
    let client: Client
    @EnvironmentObject var store: DataStore
    @State private var githubItems: [GitHubActivity] = []

    private var days: [(date: Date, count: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [(Date, Int)] = []
        for i in stride(from: 29, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -i, to: today) ?? today
            var count = 0
            for a in client.activity where cal.isDate(a.timestamp, inSameDayAs: day) {
                count += 1
            }
            if let m = store.lastIMessage(for: client), cal.isDate(m.lastMessageAt, inSameDayAs: day) {
                count += 1
            }
            for g in githubItems {
                if cal.isDate(g.timestamp, inSameDayAs: day) { count += 1 }
            }
            out.append((day, count))
        }
        return out
    }

    private var maxCount: Int {
        max(1, days.map { $0.count }.max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("LAST 30 DAYS")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MC.textTertiary)
                Spacer()
                Text("\(days.map { $0.count }.reduce(0, +)) events")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(MC.textTertiary)
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { idx, d in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(barColor(for: d.count))
                            .frame(height: barHeight(d.count))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40)
            HStack {
                Text(days.first?.date ?? Date(), format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9))
                    .foregroundStyle(MC.textTertiary)
                Spacer()
                Text(days.last?.date ?? Date(), format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9))
                    .foregroundStyle(MC.textTertiary)
            }
        }
        .task { githubItems = await store.githubActivity(for: client) }
    }

    private func barHeight(_ count: Int) -> CGFloat {
        let ceiling: CGFloat = 40
        if count == 0 { return 1 }
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(2, ceiling * ratio)
    }

    private func barColor(for count: Int) -> Color {
        if count == 0 { return MC.hairline }
        if count >= maxCount / 2 { return MC.accent }
        return MC.accent.opacity(0.5)
    }
}
