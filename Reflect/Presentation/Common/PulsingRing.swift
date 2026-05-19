import SwiftUI

/// The glowing orange ring used everywhere a "voice" affordance is needed.
///
/// Per the design system: **no microphone icon** — just light. The ring is
/// the entire affordance. Tap it to start a reflection.
///
/// Sizes used in the design:
/// - 68 pt = resting (FAB on Journal + Map, mark on Login)
/// - 85 pt = listening (centred in Recording surface)
/// - 96 pt = processing (fast spin)
/// - 160 pt = tutorial illustration
struct PulsingRing: View {
    enum Mode {
        case resting
        case listening
        case processing
    }

    var mode: Mode = .resting
    var size: CGFloat = 68
    /// `true` when sitting on the cream canvas (softer halos); `false` for the
    /// dark recording surface (richer halos).
    var onLightBackground: Bool = true
    var onTap: (() -> Void)? = nil

    @State private var breathe = false
    @State private var rotation: Double = 0
    @State private var shineRotation: Double = 0

    var body: some View {
        let visual = visualConfig
        Button(action: { onTap?() }) {
            ZStack {
                // Far halo — wide, breathes slowly
                Circle()
                    .fill(visual.haloFar)
                    .frame(width: size * 2.5, height: size * 2.5)
                    .blur(radius: 8)
                    .opacity(breathe ? 0.85 : 0.55)
                    .scaleEffect(breathe ? 1.08 : 0.94)

                // Near halo — tighter, brighter
                Circle()
                    .fill(visual.haloNear)
                    .frame(width: size * 1.44, height: size * 1.44)
                    .blur(radius: 4)
                    .scaleEffect(breathe ? 1.05 : 0.96)

                // Rim — the actual hairline ring
                Circle()
                    .strokeBorder(visual.rimColor, lineWidth: max(1.2, size * 0.018))
                    .frame(width: size, height: size)
                    .shadow(color: ReflectTheme.primaryBright.opacity(visual.outerGlowOpacity),
                            radius: size * 0.22, x: 0, y: 0)
                    .shadow(color: ReflectTheme.primary.opacity(visual.outerGlowOpacity * 0.7),
                            radius: size * 0.07, x: 0, y: 0)

                // Conic shine — a slowly rotating brighter arc along the rim
                Circle()
                    .stroke(visual.shineGradient, lineWidth: max(1.2, size * 0.018))
                    .frame(width: size, height: size)
                    .mask(
                        Circle().strokeBorder(Color.white, lineWidth: max(1.2, size * 0.018))
                    )
                    .rotationEffect(.degrees(shineRotation))
                    .opacity(0.95)
            }
            .frame(width: size, height: size, alignment: .center)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .onAppear {
            withAnimation(.easeInOut(duration: visual.breatheSeconds)
                .repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.linear(duration: visual.spinSeconds)
                .repeatForever(autoreverses: false)) {
                rotation = 360
                shineRotation = 360
            }
        }
    }

    // MARK: - State-driven visuals

    private struct VisualConfig {
        let haloFar: RadialGradient
        let haloNear: RadialGradient
        let rimColor: Color
        let shineGradient: AngularGradient
        let outerGlowOpacity: Double
        let breatheSeconds: Double
        let spinSeconds: Double
    }

    private var visualConfig: VisualConfig {
        let farOpacityFar: Double = onLightBackground ? 0.16 : 0.22
        let farOpacityNear: Double = onLightBackground ? 0.30 : 0.38

        let haloFar = RadialGradient(
            gradient: Gradient(stops: [
                .init(color: ReflectTheme.primaryBright.opacity(farOpacityFar), location: 0),
                .init(color: ReflectTheme.primary.opacity(0.10), location: 0.35),
                .init(color: .clear, location: 0.62)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: size
        )
        let haloNear = RadialGradient(
            gradient: Gradient(stops: [
                .init(color: ReflectTheme.primarySoft.opacity(farOpacityNear), location: 0),
                .init(color: ReflectTheme.primarySoft.opacity(0.14), location: 0.40),
                .init(color: .clear, location: 0.66)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: size * 0.7
        )
        let rimColor = onLightBackground
            ? ReflectTheme.primary.opacity(0.95)
            : ReflectTheme.primarySoft.opacity(0.95)

        let shineGradient = AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.00),
                .init(color: .clear, location: 0.40),
                .init(color: Color(hex: "FFF0DC").opacity(0.95), location: 0.50),
                .init(color: .clear, location: 0.60),
                .init(color: .clear, location: 1.00)
            ]),
            center: .center
        )

        switch mode {
        case .resting:
            return VisualConfig(
                haloFar: haloFar, haloNear: haloNear,
                rimColor: rimColor, shineGradient: shineGradient,
                outerGlowOpacity: onLightBackground ? 0.35 : 0.45,
                breatheSeconds: 4.8, spinSeconds: 6.5
            )
        case .listening:
            return VisualConfig(
                haloFar: haloFar, haloNear: haloNear,
                rimColor: rimColor, shineGradient: shineGradient,
                outerGlowOpacity: onLightBackground ? 0.40 : 0.55,
                breatheSeconds: 3.6, spinSeconds: 5.2
            )
        case .processing:
            return VisualConfig(
                haloFar: haloFar, haloNear: haloNear,
                rimColor: rimColor, shineGradient: shineGradient,
                outerGlowOpacity: 0.60,
                breatheSeconds: 1.4, spinSeconds: 1.6
            )
        }
    }
}

#Preview("Light surfaces") {
    VStack(spacing: 60) {
        PulsingRing(mode: .resting, size: 68)
        PulsingRing(mode: .listening, size: 160)
        PulsingRing(mode: .processing, size: 96)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ReflectTheme.canvas)
}

#Preview("Dark surface") {
    PulsingRing(mode: .listening, size: 200, onLightBackground: false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReflectTheme.blue700)
}
