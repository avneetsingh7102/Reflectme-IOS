import SwiftUI

/// Central design system for Reflect — Warm Minimalism.
///
/// Tokens come straight from `tokens.css` in the design handoff bundle so the
/// SwiftUI surfaces match the prototypes pixel-for-pixel. Three semantic
/// families live here:
///
/// 1. **Canvas/Surface ramp** — paper-warm backgrounds (no pure white).
/// 2. **Accents** — burnt orange (only primary action), mustard (passive
///    emphasis), ink blue (contemplative surfaces).
/// 3. **Emotion palette** — 8 tints for nodes / pills / legends.
enum ReflectTheme {

    // MARK: - Canvas / surface

    static let canvas    = Color(hex: "FCF9F3")
    static let surface   = Color(hex: "F6F3ED")
    static let surface2  = Color(hex: "F0EEE8")
    static let surface3  = Color(hex: "EBE8E2")
    static let surface4  = Color(hex: "E5E2DC")

    /// Background "outside" the device frame — a touch dimmer than canvas.
    static let pageBackground = Color(hex: "EFECE6")

    // Aliases for backwards compatibility with existing code paths.
    static let cardSurface  = surface
    static let cardElevated = Color.white
    static let darkCanvas   = blue700
    static let darkSurface  = Color(hex: "1C1C18")

    // MARK: - Ink (text)

    static let ink       = Color(hex: "1C1C18")
    static let inkSoft   = Color(hex: "584239")
    static let inkFaint  = Color(hex: "8C7167")

    static let textPrimary = ink
    static let textMuted   = inkSoft
    static let textOnDark  = Color(hex: "F3F0EA")

    static let separator = Color(hex: "E0DDD5")
    static let edgeLine  = Color(hex: "E0C0B3")

    // MARK: - Primary (burnt orange)

    static let primary       = Color(hex: "A03B00")
    static let primaryBright = Color(hex: "C74E08")
    static let primarySoft   = Color(hex: "FD9352")
    static let primaryTint   = Color(hex: "FDE2D4")
    static let onPrimary     = Color(hex: "FFFDF8")

    static let accent       = primary
    static let accentLight  = primaryBright
    static let accentWarm   = Color(hex: "9A4606")

    static let accentGradient = LinearGradient(
        colors: [primary, primaryBright],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradientSoft = LinearGradient(
        colors: [primary.opacity(0.12), primaryBright.opacity(0.06), .clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Mustard (aged highlighter — passive emphasis)

    static let mustard50  = Color(hex: "FBF2D4")
    static let mustard100 = Color(hex: "F4E2A1")
    static let mustard300 = Color(hex: "E5C043")
    static let mustard500 = Color(hex: "C79A18")
    static let mustard700 = Color(hex: "8A6608")

    // MARK: - Ink blue (fountain pen — contemplative)

    static let blue50  = Color(hex: "E4EBF2")
    static let blue100 = Color(hex: "B8C7D8")
    static let blue300 = Color(hex: "3B5778")
    static let blue500 = Color(hex: "1F3A5F")
    static let blue700 = Color(hex: "0F2440")

    // MARK: - Tertiary warms

    static let rust  = Color(hex: "A96428")
    static let brown = Color(hex: "6F3800")

    // MARK: - Emotion palette (8)

    static let emoJoy        = Color(hex: "E5C043")
    static let emoCuriosity  = Color(hex: "F4B06A")
    static let emoGratitude  = Color(hex: "C26849")
    static let emoAnger      = Color(hex: "C74E08")
    static let emoRegret     = Color(hex: "8B4C11")
    static let emoSadness    = Color(hex: "3B5778")
    static let emoFear       = Color(hex: "0F2440")
    static let emoNeutral    = Color(hex: "8C7167")

    static func color(for emotion: Emotion) -> Color {
        switch emotion {
        case .joy:        return emoJoy
        case .sadness:    return emoSadness
        case .anger:      return emoAnger
        case .fear:       return emoFear
        case .curiosity:  return emoCuriosity
        case .gratitude:  return emoGratitude
        case .regret:     return emoRegret
        case .neutral:    return emoNeutral
        }
    }

    /// Hex string for displaying alongside the emotion in the color guide.
    static func hex(for emotion: Emotion) -> String {
        switch emotion {
        case .joy:        return "#E5C043"
        case .sadness:    return "#3B5778"
        case .anger:      return "#C74E08"
        case .fear:       return "#0F2440"
        case .curiosity:  return "#F4B06A"
        case .gratitude:  return "#C26849"
        case .regret:     return "#8B4C11"
        case .neutral:    return "#8C7167"
        }
    }

    /// Whether a node label sitting on this emotion needs dark text.
    static func textColor(for emotion: Emotion) -> Color {
        emotion.prefersDarkText ? ink : Color(hex: "FFFDF8")
    }

    /// Short description shown in the color guide rows.
    static func description(for emotion: Emotion) -> String {
        switch emotion {
        case .joy:        return "Light, energizing thoughts and moments of delight."
        case .curiosity:  return "Wondering, questioning, exploring — open mind."
        case .gratitude:  return "Appreciation, warmth toward people or places."
        case .anger:      return "Frustration, friction that needs naming."
        case .regret:     return "Looking back with weight — wishing differently."
        case .sadness:    return "Heaviness, grief, the quiet kind of low."
        case .fear:       return "Worry, anticipation, the unknown ahead."
        case .neutral:    return "Steady, observational — no strong charge."
        }
    }

    // MARK: - Category colours (used for filter pills, kept compatible)

    static let nodeSelf          = Color(hex: "A569BD")
    static let nodeRelationships = Color(hex: "F08080")
    static let nodeGrowth        = Color(hex: "48C9B0")
    static let nodeAuthenticity  = Color(hex: "F5B041")
    static let nodeOther         = Color(hex: "9FA8DA")

    static func color(for category: NodeCategory) -> Color {
        switch category {
        case .self:          return nodeSelf
        case .relationships: return nodeRelationships
        case .growth:        return nodeGrowth
        case .authenticity:  return nodeAuthenticity
        case .other:         return nodeOther
        }
    }

    // MARK: - Typography
    //
    // Three design tiers mapped to the closest iOS system fonts so we don't
    // need to ship the Google fonts in the bundle:
    //
    // - serif (Newsreader)        → SF Pro `.serif`  (New York)
    // - rounded (Plus Jakarta Sans) → SF Pro `.rounded`
    // - mono (Space Grotesk)      → SF Mono `.monospaced`

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: - Spacing scale (8pt rhythm, 24pt edge)

    static let spacingXS:   CGFloat = 4
    static let spacingSM:   CGFloat = 8
    static let spacingMD:   CGFloat = 16
    static let spacingLG:   CGFloat = 24
    static let spacingXL:   CGFloat = 32
    static let spacingXXL:  CGFloat = 48
    static let spacingHuge: CGFloat = 64

    /// Mandatory 24pt screen edge padding per design system.
    static let edge: CGFloat = 24

    // MARK: - Corner radii

    static let cornerRadiusXS:   CGFloat = 4
    static let cornerRadiusSM:   CGFloat = 8
    static let cornerRadiusMD:   CGFloat = 12
    static let cornerRadiusLG:   CGFloat = 20
    static let cornerRadiusXL:   CGFloat = 28
    static let cornerRadiusFull: CGFloat = 9999

    // MARK: - Shadows

    static let softShadow = Color.black.opacity(0.08)
    static let softShadowRadius: CGFloat = 8
    static let softShadowY: CGFloat = 2
    static let mediumShadow = Color.black.opacity(0.10)
    static let deepShadow   = Color.black.opacity(0.16)

    // MARK: - Node sizing (map bubbles)

    static func nodeDiameter(prominence: Double) -> CGFloat {
        let minSize: CGFloat = 56
        let maxSize: CGFloat = 124
        return minSize + CGFloat(prominence) * (maxSize - minSize)
    }

    // MARK: - Animation curves

    static let springSnappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let springGentle = Animation.spring(response: 0.50, dampingFraction: 0.80)
    static let springBouncy = Animation.spring(response: 0.40, dampingFraction: 0.60)

    // MARK: - Time-of-day greeting

    static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Late night thoughts"
        }
    }

    static var greetingEmoji: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "☀️"
        case 12..<17: return "🌤"
        case 17..<21: return "🌅"
        default:      return "🌙"
        }
    }
}

// MARK: - Color(hex:) initialiser

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Reusable view modifiers

extension View {
    /// Floating elevated card — soft shadow, white surface.
    func reflectCard(padding: CGFloat = ReflectTheme.spacingMD,
                     radius: CGFloat = ReflectTheme.cornerRadiusLG) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(ReflectTheme.cardElevated)
                    .shadow(color: ReflectTheme.softShadow,
                            radius: ReflectTheme.softShadowRadius,
                            y: ReflectTheme.softShadowY)
            )
    }

    /// Subtle orange ambient glow.
    func accentGlow(radius: CGFloat = 20, opacity: Double = 0.25) -> some View {
        self.shadow(color: ReflectTheme.accent.opacity(opacity), radius: radius, y: 4)
    }

    /// Small uppercase eyebrow label.
    func eyebrowStyle(color: Color = ReflectTheme.inkSoft) -> some View {
        self
            .font(ReflectTheme.rounded(11, weight: .bold))
            .foregroundStyle(color)
            .textCase(.uppercase)
            .tracking(1.6)
    }
}
