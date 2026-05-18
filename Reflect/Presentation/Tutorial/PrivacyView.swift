import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReflectTheme.spacingLG + 4) {
                section(
                    title: "Your data stays local",
                    text: "Every reflection is stored on your device. We never upload them to the cloud or share them with third parties."
                )
                section(
                    title: "AI processing",
                    text: "Speech is transcribed on-device using Apple's Speech framework. The resulting text is sent to Groq to identify themes — Groq does not retain transcripts."
                )
                section(
                    title: "No tracking",
                    text: "We don't use analytics, cookies, or any form of tracking. What you say is private."
                )
                section(
                    title: "Delete anytime",
                    text: "Clear all reflections from Settings → Clear all reflections. This is permanent and cannot be undone."
                )
            }
            .padding(ReflectTheme.spacingLG)
        }
        .navigationTitle("Privacy & security")
        .navigationBarTitleDisplayMode(.inline)
        .background(ReflectTheme.canvas)
    }

    private func section(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: ReflectTheme.spacingSM) {
            Text(title)
                .font(ReflectTheme.serif(16, weight: .semibold))
                .foregroundStyle(ReflectTheme.textPrimary)
            Text(text)
                .font(ReflectTheme.rounded(14))
                .foregroundStyle(ReflectTheme.textMuted)
                .lineSpacing(5)
        }
    }
}
