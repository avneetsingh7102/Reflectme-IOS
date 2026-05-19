import SwiftUI

/// Legend explaining what each emotion color means on the neural map.
///
/// Per design: serif eyebrow "Eight ways your thoughts feel.", then 8 white
/// card rows with a 44pt color disc on the left, emotion name + mono hex on
/// top right, and a short serif description.
struct ColorGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReflectTheme.spacingMD) {
                headerBlock
                    .padding(.horizontal, ReflectTheme.edge)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    ForEach(Emotion.allCases, id: \.self) { e in
                        row(emotion: e)
                    }
                }
                .padding(.horizontal, ReflectTheme.spacingMD)
                .padding(.bottom, ReflectTheme.spacingXL)
            }
        }
        .background(ReflectTheme.canvas.ignoresSafeArea())
        .navigationTitle("Color Guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eight ways\nyour thoughts feel.")
                .font(.system(size: 28, weight: .medium, design: .serif))
                .foregroundStyle(ReflectTheme.ink)
                .lineSpacing(2)
            Text("Reflect listens for emotional shape, then tints each node so your map reads at a glance.")
                .font(ReflectTheme.serif(15))
                .foregroundStyle(ReflectTheme.inkSoft)
                .lineSpacing(3)
        }
    }

    private func row(emotion: Emotion) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(ReflectTheme.color(for: emotion))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(emotion.label)
                        .font(ReflectTheme.serif(18, weight: .medium))
                        .foregroundStyle(ReflectTheme.ink)
                    Spacer()
                    Text(ReflectTheme.hex(for: emotion))
                        .font(ReflectTheme.mono(11))
                        .foregroundStyle(ReflectTheme.inkFaint)
                        .tracking(0.4)
                }
                Text(ReflectTheme.description(for: emotion))
                    .font(ReflectTheme.serif(13.5))
                    .foregroundStyle(ReflectTheme.inkSoft)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: ReflectTheme.softShadow, radius: 6, y: 2)
        )
    }
}
