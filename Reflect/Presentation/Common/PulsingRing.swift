import SwiftUI

/// The glowing orange ring used everywhere a "voice" affordance is needed.
///
/// No microphone icon — the ring itself is the affordance. Visual values come
/// straight from the `.glow-ring` CSS in the design handoff so the on-device
/// render matches the prototype.
///
/// Standard sizes used across the app:
/// - 76 pt = resting FAB (journal list + entry map mode)
/// - 96 pt = listening (recording surface)
/// - 110 pt = processing (recording surface, fast spin)
/// - 160 pt = tutorial illustration
struct PulsingRing: View {
    enum Mode {
        case resting
        case listening
        case processing
    }

    var mode: Mode = .resting
    var size: CGFloat = 76
    /// `true` when sitting on the cream canvas (softer halos); `false` for the
    /// dark recording surface (richer halos).
    var onLightBackground: Bool = true
    var onTap: (() -> Void)? = nil

    @State private var breathe = false
    @State private var shineRotation: Double = 0

    var body: some View {
        let cfg = visualConfig
        Button(action: { onTap?() }) {
            ZStack {
                // Far halo — wide, slow breathe
                Circle()
                    .fill(cfg.haloFar)
                    .frame(width: size * 3.0, height: size * 3.0)
                    .blur(radius: 12)
                    .opacity(breathe ? 0.95 : 0.55)
                    .scaleEffect(breathe ? 1.08 : 0.94)

                // Near halo — tighter, brighter peach
                Circle()
                    .fill(cfg.haloNear)
                    .frame(width: size * 1.8, height: size * 1.8)
                    .blur(radius: 6)
                    .scaleEffect(breathe ? 1.05 : 0.96)

                // Outer shadow ring — pure CSS-style box-shadow rim glow
                Circle()
                    .fill(Color.clear)
                    .frame(width: size, height: size)
                    .shadow(color: ReflectTheme.primary.opacity(cfg.outerWideGlow),
                            radius: size * 0.7, x: 0, y: 0)
                    .shadow(color: ReflectTheme.primary.opacity(cfg.outerTightGlow),
                            radius: size * 0.22, x: 0, y: 0)

                // The hairline rim itself
                Circle()
                    .stroke(cfg.rimColor, lineWidth: max(1.3, size * 0.020))
                    .frame(width: size, height: size)

                // Inset rim warmth — like `inset 0 0 24px rgba(...)`
                Circle()
                    .strokeBorder(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: ReflectTheme.primarySoft.opacity(0.35), location: 0),
                                .init(color: .clear, location: 0.5)
                            ]),
                            center: .center,
                            startRadius: size * 0.30,
                            endRadius: size * 0.50
                        ),
                        lineWidth: size * 0.18
                    )
                    .frame(width: size, height: size)
                    .blendMode(.plusLighter)
                    .opacity(0.7)

                // Conic shine arc — slowly rotates around the rim
                Circle()
                    .stroke(cfg.shineGradient, lineWidth: max(1.6, size * 0.022))
                    .frame(width: size, height: size)
                    .mask(Circle().strokeBorder(Color.white, lineWidth: max(1.6, size * 0.022)))
                    .rotationEffect(.degrees(shineRotation))
                    .opacity(0.85)
            }
            .frame(width: size, height: size, alignment: .center)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .onAppear {
            withAnimation(.easeInOut(duration: cfg.breatheSeconds)
                .repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.linear(duration: cfg.spinSeconds)
                .repeatForever(autoreverses: false)) {
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
        let outerWideGlow: Double   // mimics box-shadow 0 0 56px rgba(199,78,8,0.25)
        let outerTightGlow: Double  // mimics 0 0 18px rgba(199,78,8,0.45)
        let breatheSeconds: Double
        let spinSeconds: Double
    }

    private var visualConfig: VisualConfig {
        // Per design tokens.css `.glow-ring` values
        let farFarOpacity: Double  = onLightBackground ? 0.16 : 0.22
        let farMidOpacity: Double  = onLightBackground ? 0.06 : 0.10
        let nearFarOpacity: Double = onLightBackground ? 0.30 : 0.38
        let nearMidOpacity: Double = onLightBackground ? 0.10 : 0.14

        let haloFar = RadialGradient(
            gradient: Gradient(stops: [
                .init(color: ReflectTheme.primaryBright.opacity(farFarOpacity), location: 0),
                .init(color: ReflectTheme.primary.opacity(farMidOpacity), location: 0.28),
                .init(color: .clear, location: 0.58)
            ]),
            center: .center, startRadius: 0, endRadius: size * 1.3
        )
        let haloNear = RadialGradient(
            gradient: Gradient(stops: [
                .init(color: ReflectTheme.primarySoft.opacity(nearFarOpacity), location: 0),
                .init(color: ReflectTheme.primarySoft.opacity(nearMidOpacity), location: 0.35),
                .init(color: .clear, location: 0.60)
            ]),
            center: .center, startRadius: 0, endRadius: size * 0.85
        )
        let rimColor = onLightBackground
            ? ReflectTheme.primary.opacity(0.92)
            : ReflectTheme.primarySoft.opacity(0.95)

        let shineGradient = AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.00),
                .init(color: .clear, location: 0.35),
                .init(color: Color(hex: "FFF0DC").opacity(0.95), location: 0.50),
                .init(color: .clear, location: 0.65),
                .init(color: .clear, location: 1.00)
            ]),
            center: .center
        )

        switch mode {
        case .resting:
            return VisualConfig(
                haloFar: haloFar, haloNear: haloNear,
                rimColor: rimColor, shineGradient: shineGradient,
                outerWideGlow:  onLightBackground ? 0.25 : 0.35,
                outerTightGlow: onLightBackground ? 0.45 : 0.55,
                breatheSeconds: 4.8, spinSeconds: 6.5
            )
        case .listening:
            return VisualConfig(
                haloFar: haloFar, haloNear: haloNear,
                rimColor: rimColor, shineGradient: shineGradient,
                outerWideGlow:  onLightBackground ? 0.32 : 0.45,
                outerTightGlow: onLightBackground ? 0.55 : 0.65,
                breatheSeconds: 3.6, spinSeconds: 5.0
            )
        case .processing:
            return VisualConfig(
                haloFar: haloFar, haloNear: haloNear,
                rimColor: rimColor, shineGradient: shineGradient,
                outerWideGlow:  0.50,
                outerTightGlow: 0.70,
                breatheSeconds: 1.4, spinSeconds: 1.6
            )
        }
    }
}

#Preview("Light surfaces") {
    VStack(spacing: 60) {
        PulsingRing(mode: .resting, size: 76)
        PulsingRing(mode: .listening, size: 160)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ReflectTheme.canvas)
}

#Preview("Dark surface") {
    PulsingRing(mode: .listening, size: 96, onLightBackground: false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReflectTheme.blue700)
}
