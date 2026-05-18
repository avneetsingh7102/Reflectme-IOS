import SwiftUI

/// The glowing orb FAB that lives on the journal list and detail sheets.
struct PulsingOrbButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var glowIntensity: Double = 0.5

    private let colors: [Color] = [
        Color(hex: "E85D04"),
        Color(hex: "F4A623"),
        Color(hex: "C94E02"),
        Color(hex: "FFB347")
    ]

    var body: some View {
        Button(action: action) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: colors,
                                center: .center,
                                angle: .degrees(rotation + Double(i * 90))
                            )
                            .opacity(0.15 - Double(i) * 0.04),
                            lineWidth: 2
                        )
                        .frame(width: 80 + CGFloat(i * 20), height: 80 + CGFloat(i * 20))
                        .scaleEffect(pulseScale + CGFloat(i) * 0.05)
                        .blur(radius: 1 + CGFloat(i))
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                colors[0].opacity(0.4),
                                colors[1].opacity(0.2),
                                colors[0].opacity(0.1)
                            ],
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: colors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .opacity(0.6),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: colors[0].opacity(glowIntensity),
                        radius: isRecording ? 25 : 15,
                        y: 4
                    )

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: isRecording ? 20 : 24, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: isRecording)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear { startAnimations() }
        .onChange(of: isRecording) { _, new in
            glowIntensity = new ? 0.8 : 0.5
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = isRecording ? 0.9 : 0.6
        }
    }
}
