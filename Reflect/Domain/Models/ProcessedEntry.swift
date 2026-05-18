import Foundation

/// The output of an `EntryProcessor`: a title, summary and a graph of themes.
///
/// All identifiers are short slugs produced by the processor so edges can
/// reference nodes by `id` regardless of label changes.
struct ProcessedEntry: Sendable, Equatable {
    let title: String
    let summary: String
    let nodes: [ProcessedNode]
    let edges: [ProcessedEdge]
}

struct ProcessedNode: Sendable, Equatable, Identifiable {
    let id: String
    let label: String
    let category: NodeCategory
    let emotion: Emotion
}

struct ProcessedEdge: Sendable, Equatable {
    let sourceId: String
    let targetId: String
    let relationship: String?
}
