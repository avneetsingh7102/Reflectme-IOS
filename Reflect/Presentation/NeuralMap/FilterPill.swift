import SwiftUI

/// A pill at the bottom of the neural map: tap to filter visible nodes by
/// category. The "All" pill clears the filter.
struct FilterPill: View {
    let label: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ReflectTheme.rounded(12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : ReflectTheme.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? color : ReflectTheme.cardSurface)
                        .overlay(
                            Capsule()
                                .stroke(isActive ? Color.clear : ReflectTheme.separator, lineWidth: 0.5)
                        )
                )
        }
        .animation(ReflectTheme.springSnappy, value: isActive)
    }
}
