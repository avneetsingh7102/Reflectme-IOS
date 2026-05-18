import Foundation

/// High-level category assigned to a node by the entry processor.
///
/// The LLM is prompted to produce one of the four primary cases; anything else
/// is captured as `.other` so we never lose data.
enum NodeCategory: Sendable, Hashable {
    case `self`
    case relationships
    case growth
    case authenticity
    case other(String)

    init(apiString: String?) {
        let raw = apiString?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch raw {
        case "self":          self = .self
        case "relationships": self = .relationships
        case "growth":        self = .growth
        case "authenticity":  self = .authenticity
        case "":              self = .other("uncategorized")
        default:              self = .other(raw)
        }
    }

    var storageKey: String {
        switch self {
        case .self:                 return "self"
        case .relationships:        return "relationships"
        case .growth:               return "growth"
        case .authenticity:         return "authenticity"
        case .other(let raw):       return raw
        }
    }

    var label: String {
        switch self {
        case .self:           return "Self"
        case .relationships:  return "Relationships"
        case .growth:         return "Growth"
        case .authenticity:   return "Authenticity"
        case .other(let raw): return raw.capitalized
        }
    }
}
