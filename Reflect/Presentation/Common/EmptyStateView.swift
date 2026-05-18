import SwiftUI

/// Onboarding/empty state: serif invitation displayed when the journal is empty.
///
/// The bottom padding keeps this view clear of the floating PulsingOrbButton
/// that sits at the bottom of the same ZStack in JournalListView.
struct EmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(ReflectTheme.accent.opacity(0.4))

            Text("No reflections yet")
                .font(ReflectTheme.serif(22, weight: .semibold))
                .foregroundStyle(ReflectTheme.textPrimary)

            Text("Tap the mic below to begin")
                .font(ReflectTheme.rounded(14))
                .foregroundStyle(ReflectTheme.textMuted)

            Spacer()
        }
        // Leave the bottom 140pt clear so the PulsingOrbButton underneath
        // in the ZStack is always tappable.
        .padding(.bottom, 140)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
