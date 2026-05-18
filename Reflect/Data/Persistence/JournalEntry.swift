import Foundation
@preconcurrency import SwiftData

/// A single journal session. The raw transcript is persisted immediately when
/// the user stops recording; the LLM-derived fields (`aiGeneratedTitle`,
/// `oneLineSummary`, `mapNodes`, `mapLinks`) populate asynchronously.
///
/// `retryPending == true` means processing hasn't completed yet — the
/// `NeuralMapView` watches this flag to kick off the pipeline.
@Model
final class JournalEntry {
    @Attribute(.unique) var id: String
    var date: Date
    var rawTranscript: String
    var polishedTranscript: String
    var aiGeneratedTitle: String
    var oneLineSummary: String
    var retryPending: Bool
    var processingFailed: Bool?
    /// Reserved for future visual-style tagging (e.g. associating an entry
    /// with an art movement for cover-art generation). Optional so existing
    /// rows migrate cleanly.
    var artMovement: String?

    @Relationship(deleteRule: .cascade)
    var mapNodes: [SDNode]

    @Relationship(deleteRule: .cascade)
    var mapLinks: [SDLink]

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        rawTranscript: String = "",
        polishedTranscript: String = "",
        aiGeneratedTitle: String = "New Reflection",
        oneLineSummary: String = "",
        retryPending: Bool = false,
        processingFailed: Bool? = false,
        artMovement: String? = nil,
        mapNodes: [SDNode] = [],
        mapLinks: [SDLink] = []
    ) {
        self.id = id
        self.date = date
        self.rawTranscript = rawTranscript
        self.polishedTranscript = polishedTranscript
        self.aiGeneratedTitle = aiGeneratedTitle
        self.oneLineSummary = oneLineSummary
        self.retryPending = retryPending
        self.processingFailed = processingFailed
        self.artMovement = artMovement
        self.mapNodes = mapNodes
        self.mapLinks = mapLinks
    }
}
