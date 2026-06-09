// OnboardingSheet.swift
// Shown the first time the app is launched with zero clients and no prior data.

import SwiftUI

struct OnboardingSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: DataStore
    @State private var step: Int = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "scope")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(MC.textPrimary)
                Text("Mission Control")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.5)
                Text("Your clients, in one quiet place.")
                    .font(.system(size: 13))
                    .foregroundStyle(MC.textTertiary)
            }
            VStack(alignment: .leading, spacing: 18) {
                stepRow(icon: "scope", color: MC.accent, title: "Live in your menu bar", body: "Click the scope icon — or hit ⌥⌘C from anywhere — to see everyone in 1 second.")
                stepRow(icon: "bell.badge", color: .indigo, title: "Auto-track activity", body: "iMessage, GitHub pushes, calendar meetings — all flow into one timeline per client.")
                stepRow(icon: "icloud", color: .teal, title: "Synced across your Macs", body: "Edit on Mac Pro, see it on MacBook Pro. Instant.")
            }
            .padding(.horizontal, 24)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == step ? MC.textPrimary : MC.hairline)
                        .frame(width: 6, height: 6)
                }
            }
            HStack {
                Button("Skip") { isPresented = false }
                    .buttonStyle(MCButtonStyle(variant: .ghost))
                Spacer()
                Button(step == 2 ? "Add your first client" : "Next") {
                    if step == 2 {
                        isPresented = false
                        store.showAddSheet = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                    }
                }
                .buttonStyle(MCButtonStyle(variant: .primary))
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
        .frame(width: 440, height: 460)
        .background(MC.popoverBackground)
    }

    private func stepRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.10))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MC.textPrimary)
                Text(body)
                    .font(.system(size: 11.5))
                    .foregroundStyle(MC.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
