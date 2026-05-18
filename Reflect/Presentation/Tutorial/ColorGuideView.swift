import SwiftUI

/// Legend explaining what each emotion colour means on the neural map.
struct ColorGuideView: View {
    var body: some View {
        List {
            ForEach(Emotion.allCases, id: \.self) { emotion in
                row(emotion: emotion, description: description(for: emotion))
            }
        }
        .listStyle(.plain)
        .navigationTitle("Emotion colours")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(emotion: Emotion, description: String) -> some View {
        HStack(alignment: .top, spacing: ReflectTheme.spacingSM + 4) {
            Circle()
                .fill(ReflectTheme.color(for: emotion))
                .frame(width: 16, height: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: ReflectTheme.spacingXS) {
                Text(emotion.label)
                    .font(ReflectTheme.serif(16, weight: .semibold))
                    .foregroundStyle(ReflectTheme.textPrimary)
                Text(description)
                    .font(ReflectTheme.rounded(13))
                    .foregroundStyle(ReflectTheme.textMuted)
                    .lineSpacing(3)
            }
        }
        .padding(.vertical, ReflectTheme.spacingSM)
    }

    private func description(for emotion: Emotion) -> String {
        switch emotion {
        case .joy:        return "Moments of happiness, excitement, or achievement"
        case .sadness:    return "Feelings of sorrow, loss, or grief"
        case .anger:      return "Frustration, unfairness, or irritation"
        case .fear:       return "Anxiety, worry, or apprehension"
        case .curiosity:  return "Exploring new ideas, questioning, wondering"
        case .gratitude:  return "Thankfulness, appreciation, or relief"
        case .regret:     return "Wishing things were different, guilt"
        case .neutral:    return "Objective observation, routine details"
        }
    }
}
