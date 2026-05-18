import SwiftUI

/// Central design system for the Reflect app.
///
/// Built on the Warm Minimalism guidelines: paper-warm canvas, soft cards,
/// burnt-orange accent, eight emotion colours, four node categories.
enum ReflectTheme {

    // MARK: - Surface colours

    static let canvas = Color(hex: "FCF9F3")
    static let cardSurface = Color(hex: "F6F3ED")
    static let cardElevated = Color(hex: "FFFFFF")
    static let darkCanvas = Color(hex: "31312D")
    static let darkSurface = Color(hex: "1C1C18")

    static let textPrimary = Color(hex: "1C1C18")
    static let textMuted = Color(hex: "584239")
    static let textOnDark = Color(hex: "F3F0EA")

    static let separator = Color(hex: "E5E2DC")
    static let edgeLine = Color(hex: "E0C0B3")

    // MARK: - Accent

    static let accent = Color(hex: "A03B00")
    static let accentLight = Color(hex: "C74E08")
    static let accentWarm = Color(hex: "9A4606")

    static let accentGradient = LinearGradient(
        colors: [Color(hex: "A03B00"), Color(hex: "C74E08")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradientSoft = LinearGradient(
        colors: [Color(hex: "A03B00").opacity(0.12), Color(hex: "C74E08").opacity(0.06), .clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Category colours

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

    // MARK: - Emotion colours

    static let emotionJoy = Color(hex: "FFD700")
    static let emotionSadness = Color(hex: "6B9BD1")
    static let emotionAnger = Color(hex: "D14B4B")
    static let emotionFear = Color(hex: "9B6BD1")
    static let emotionCuriosity = Color(hex: "4BD1C5")
    static let emotionGratitude = Color(hex: "FF9A56")
    static let emotionRegret = Color(hex: "8E8E93")
    static let emotionNeutral = Color(hex: "D1D1D6")

    static func color(for emotion: Emotion) -> Color {
        switch emotion {
        case .joy:        return emotionJoy
        case .sadness:    return emotionSadness
        case .anger:      return emotionAnger
        case .fear:       return emotionFear
        case .curiosity:  return emotionCuriosity
        case .gratitude:  return emotionGratitude
        case .regret:     return emotionRegret
        case .neutral:    return emotionNeutral
        }
    }

    static func textColor(for emotion: Emotion) -> Color {
        emotion.prefersDarkText ? .black : .white
    }

    // MARK: - Typography

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48
    static let spacingHuge: CGFloat = 64

    // MARK: - Corner radii

    static let cornerRadiusXS: CGFloat = 4
    static let cornerRadiusSM: CGFloat = 8
    static let cornerRadiusMD: CGFloat = 12
    static let cornerRadiusLG: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 24
    static let cornerRadiusFull: CGFloat = 9999

    // MARK: - Shadows

    static let softShadow = Color.black.opacity(0.08)
    static let softShadowRadius: CGFloat = 8
    static let softShadowY: CGFloat = 2
    static let mediumShadow = Color.black.opacity(0.1)
    static let deepShadow = Color.black.opacity(0.16)

    // MARK: - Node sizing

    static func nodeDiameter(prominence: Double) -> CGFloat {
        let minSize: CGFloat = 72
        let maxSize: CGFloat = 136
        return minSize + CGFloat(prominence) * (maxSize - minSize)
    }

    // MARK: - Animations

    static let springSnappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)

    // MARK: - Greeting

    static var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Late night thoughts"
        }
    }

    static var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "☀️"
        case 12..<17: return "🌤"
        case 17..<21: return "🌅"
        default:      return "🌙"
        }
    }
}

// MARK: - Color hex initialiser

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
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View styling helpers

extension View {
    func reflectCard(padding: CGFloat = ReflectTheme.spacingMD) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: ReflectTheme.cornerRadiusLG)
                    .fill(ReflectTheme.cardElevated)
                    .shadow(color: ReflectTheme.softShadow, radius: ReflectTheme.softShadowRadius, y: ReflectTheme.softShadowY)
            )
    }

    func accentGlow(radius: CGFloat = 20, opacity: Double = 0.25) -> some View {
        self.shadow(color: ReflectTheme.accent.opacity(opacity), radius: radius, y: 4)
    }
}
