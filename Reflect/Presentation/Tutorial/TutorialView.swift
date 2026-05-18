import SwiftUI

struct TutorialView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReflectTheme.spacingLG) {
                section(
                    icon: "mic.fill",
                    title: "1. Speak your thoughts",
                    description: "Tap the glowing mic button and speak freely. There's no structure — just let your thoughts flow naturally."
                )
                section(
                    icon: "brain.head.profile",
                    title: "2. See your mind",
                    description: "Your thoughts become a neural map. Each coloured bubble is a theme that emerged from what you said."
                )
                section(
                    icon: "bubble.left.and.bubble.right",
                    title: "3. Explore deeper",
                    description: "Tap any theme to see why it came up, read your own words, and answer a gentle question that takes you further."
                )
                section(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "4. Notice patterns",
                    description: "Over time you'll see which themes recur, how they connect, and what that reveals about your inner world."
                )
            }
            .padding(ReflectTheme.spacingLG)
        }
        .navigationTitle("How it works")
        .navigationBarTitleDisplayMode(.inline)
        .background(ReflectTheme.canvas)
    }

    private func section(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: ReflectTheme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(ReflectTheme.accent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(ReflectTheme.accent.opacity(0.1)))
            VStack(alignment: .leading, spacing: ReflectTheme.spacingXS + 2) {
                Text(title)
                    .font(ReflectTheme.serif(17, weight: .semibold))
                    .foregroundStyle(ReflectTheme.textPrimary)
                Text(description)
                    .font(ReflectTheme.rounded(14))
                    .foregroundStyle(ReflectTheme.textMuted)
                    .lineSpacing(4)
            }
        }
    }
}
