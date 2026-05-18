import Foundation

/// Direct-to-Groq implementation of `EntryProcessor`.
///
/// Runs offline (no backend required). Bundles title, summary and the theme
/// graph into a single LLM call to minimise latency on the recording-to-map
/// transition.
final actor GroqEntryProcessor: EntryProcessor {
    private let client: GroqClient
    private let model: String

    init(client: GroqClient, model: String = "llama-3.3-70b-versatile") {
        self.client = client
        self.model = model
    }

    func process(transcript: String) async throws -> ProcessedEntry {
        let payload: Payload = try await client.completeJSON(
            model: model,
            systemPrompt: nil,
            userPrompt: prompt(for: transcript),
            temperature: 0.1,
            maxTokens: 700,
            timeout: 30
        )
        return payload.toDomain()
    }

    private func prompt(for transcript: String) -> String {
        """
        Analyze this voice journal entry and return ONE JSON object only.
        No markdown, no backticks, raw JSON only.

        Schema:
        {
          "title": "4-7 word poetic title capturing the emotional core",
          "summary": "One sentence (max 15 words) capturing the key insight",
          "nodes": [
            {"id": "slug", "label": "Theme Name", "type": "self|relationships|growth|authenticity", "emotion": "Joy|Sadness|Anger|Fear|Curiosity|Gratitude|Regret|Neutral"}
          ],
          "edges": [
            {"sourceId": "slug1", "targetId": "slug2", "relationship": "one word"}
          ]
        }

        Rules: 3-5 nodes, at most 5 edges, every edge must reference node ids that exist in `nodes`.
        The title should read like a journal chapter name.

        Entry: \(transcript)
        """
    }

    private struct Payload: Decodable {
        let title: String
        let summary: String
        let nodes: [Node]
        let edges: [Edge]

        struct Node: Decodable {
            let id: String
            let label: String
            let type: String?
            let emotion: String?
        }

        struct Edge: Decodable {
            let sourceId: String
            let targetId: String
            let relationship: String?
        }

        func toDomain() -> ProcessedEntry {
            let nodeIds = Set(nodes.map(\.id))
            let validEdges = edges.filter { nodeIds.contains($0.sourceId) && nodeIds.contains($0.targetId) }
            return ProcessedEntry(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                nodes: nodes.map {
                    ProcessedNode(
                        id: $0.id,
                        label: $0.label,
                        category: NodeCategory(apiString: $0.type),
                        emotion: Emotion(apiString: $0.emotion)
                    )
                },
                edges: validEdges.map {
                    ProcessedEdge(
                        sourceId: $0.sourceId,
                        targetId: $0.targetId,
                        relationship: $0.relationship
                    )
                }
            )
        }
    }
}
