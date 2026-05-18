import SwiftUI

/// A circular theme bubble on the neural map. Pulses gently, scales when
/// selected, and uses the node's emotion to choose its colour.
struct ThoughtNodeView: View {
    let node: PositionedNode
    let isSelected: Bool
    let onTap: () -> Void

    @State private var appeared = false
    @State private var breatheScale: CGFloat = 1.0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(nodeColor.opacity(isSelected ? 0.18 : 0.08))
                    .frame(width: diameter + 24, height: diameter + 24)
                    .scaleEffect(breatheScale)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [nodeColor.opacity(0.22), nodeColor.opacity(0.08)],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: diameter
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .stroke(
                                nodeColor.opacity(isSelected ? 0.6 : 0.25),
                                lineWidth: isSelected ? 1.5 : 0.75
                            )
                    )
                    .shadow(
                        color: nodeColor.opacity(isSelected ? 0.25 : 0.1),
                        radius: isSelected ? 16 : 8,
                        y: 2
                    )

                Text(node.label)
                    .font(ReflectTheme.rounded(labelSize, weight: .semibold))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(10)
                    .frame(width: diameter - 8, height: diameter - 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(appeared ? (isSelected ? 1.08 : 1.0) : 0.2)
        .opacity(appeared ? 1 : 0)
        .animation(ReflectTheme.springGentle.delay(node.animationDelay), value: appeared)
        .animation(ReflectTheme.springSnappy, value: isSelected)
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 3.5 + Double.random(in: 0...1.5))
                .repeatForever(autoreverses: true)) {
                breatheScale = 1.05 + CGFloat(node.prominence) * 0.04
            }
        }
    }

    private var diameter: CGFloat { ReflectTheme.nodeDiameter(prominence: node.prominence) }
    private var nodeColor: Color { ReflectTheme.color(for: node.emotion) }
    private var textColor: Color { ReflectTheme.textColor(for: node.emotion) }
    private var labelSize: CGFloat { diameter < 90 ? 11 : diameter < 110 ? 12 : 13 }
}
