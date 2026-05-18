import Foundation

/// The unified emotion taxonomy used across the app.
///
/// Mirrors the 8 categories the LLM is prompted to emit. Parsing accepts any
/// casing and falls back to `.neutral` for unknown values.
enum Emotion: String, Codable, CaseIterable, Sendable {
    case joy
    case sadness
    case anger
    case fear
    case curiosity
    case gratitude
    case regret
    case neutral

    init(apiString: String?) {
        guard let raw = apiString?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              let value = Emotion(rawValue: raw) else {
            self = .neutral
            return
        }
        self = value
    }

    var label: String {
        switch self {
        case .joy:        return "Joy"
        case .sadness:    return "Sadness"
        case .anger:      return "Anger"
        case .fear:       return "Fear"
        case .curiosity:  return "Curiosity"
        case .gratitude:  return "Gratitude"
        case .regret:     return "Regret"
        case .neutral:    return "Neutral"
        }
    }

    var iconName: String {
        switch self {
        case .joy:        return "sun.max"
        case .sadness:    return "cloud.rain"
        case .anger:      return "flame"
        case .fear:       return "exclamationmark.triangle"
        case .curiosity:  return "sparkles"
        case .gratitude:  return "heart"
        case .regret:     return "clock.arrow.circlepath"
        case .neutral:    return "circle"
        }
    }

    /// Whether the emotion color is light enough that overlaid text should be black.
    var prefersDarkText: Bool {
        switch self {
        case .joy, .curiosity, .neutral: return true
        default: return false
        }
    }
}
