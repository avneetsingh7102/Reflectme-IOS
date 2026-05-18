import SwiftUI

/// Short bottom sheet explaining why two theme nodes are connected.
struct EdgeExplanationSheet: View {
    let sourceTheme: String
    let targetTheme: String
    let strength: Int
    let relationship: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ReflectTheme.spacingSM + 4) {
            HStack(spacing: ReflectTheme.spacingSM) {
                Circle()
                    .fill(ReflectTheme.accent.opacity(0.2))
                    .frame(width: 8, height: 8)
                Text("\(sourceTheme) → \(targetTheme)")
                    .font(ReflectTheme.serif(16, weight: .semibold))
                    .foregroundStyle(ReflectTheme.textPrimary)
            }

            if let relationship, !relationship.isEmpty {
                Text("Relationship: \(relationship)")
                    .font(ReflectTheme.rounded(13, weight: .medium))
                    .foregroundStyle(ReflectTheme.accent)
            }

            Text(connectionReason)
                .font(ReflectTheme.rounded(14))
                .foregroundStyle(ReflectTheme.textMuted)
                .lineSpacing(4)

            HStack {
                Text("Connection strength")
                    .font(ReflectTheme.rounded(12))
                    .foregroundStyle(ReflectTheme.textMuted)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < strength ? ReflectTheme.accent : ReflectTheme.separator)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(ReflectTheme.spacingLG)
    }

    private var connectionReason: String {
        if strength >= 4 {
            return "These themes appear together frequently, suggesting they're deeply intertwined in how you process experiences."
        } else if strength >= 2 {
            return "You've mentioned both themes in the same session a few times — worth exploring."
        } else {
            return "These themes co-occurred once. The connection may strengthen as you reflect more."
        }
    }
}
