import SwiftUI

/// Pill used on the Neural Map filter strip.
///
/// Active state per design: deep ink-blue (`blue700`) background, white label.
/// Inactive: white-ish background with separator outline + soft ink text.
struct FilterPill: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ReflectTheme.rounded(13, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : ReflectTheme.inkSoft)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? ReflectTheme.blue700 : Color.white.opacity(0.65))
                        .overlay(
                            Capsule().stroke(
                                isActive ? Color.clear : ReflectTheme.separator,
                                lineWidth: 1
                            )
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(ReflectTheme.springSnappy, value: isActive)
    }
}
