import Foundation

/// Structured output of a `DeepDiveService.expand` call.
///
/// Splitting the body from the Socratic question lets the UI render them in
/// the right places: the long-form `insight` goes in the Insight tab, while
/// the short `question` lives in the "REFLECT ASKS" prompt block that the
/// user can tap to record a response to.
struct DeepDive: Sendable, Equatable {
    /// 2-3 paragraph reflection. Quotes 1-2 phrases from the transcript and
    /// expands on the emotional weight of the theme.
    let insight: String

    /// A single, specific Socratic question contextualised to *this* node and
    /// transcript — never a generic "what does this feel like" template.
    let question: String
}
