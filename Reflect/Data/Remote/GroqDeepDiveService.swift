import Foundation

/// Direct-to-Groq implementation of `DeepDiveService`.
///
/// Uses `response_format: json_object` so we get back a structured
/// `{ "insight": "...", "question": "..." }` payload. The prompt instructs
/// the model to write the question in second person, reference something
/// concrete from the transcript, and avoid generic templates ("what does X
/// feel like at its best?" is explicitly banned).
final actor GroqDeepDiveService: DeepDiveService {
    private let client: GroqClient
    private let model: String

    init(client: GroqClient, model: String = "llama-3.1-8b-instant") {
        self.client = client
        self.model = model
    }

    func expand(themeLabel: String, transcript: String) async throws -> DeepDive {
        let system = """
        You are a thoughtful journaling assistant helping the user reflect on a
        specific theme that emerged from their own voice journal. Write warmly
        and quote them in their own words. Never invent details or facts not
        present in the transcript.
        """
        let user = """
        Theme to explore: "\(themeLabel)"

        The user journaled:
        \"\"\"
        \(transcript)
        \"\"\"

        Return ONE JSON object with exactly these two fields:

        - "insight": 2 paragraphs (4-6 sentences total). Quote 1-2 short
          phrases from the user's own words (use straight quotes), describe
          the emotional weight of this theme as it shows up in their entry,
          and connect it to one other detail they mentioned.

        - "question": ONE Socratic follow-up question (10-22 words, ending in
          a question mark) that references something CONCRETE from the
          transcript above and invites them to go deeper. Address them as
          "you". Do NOT use generic phrasings like "what does X feel like at
          its best", "what does X mean to you", or "how do you feel about X".
          Anchor the question to a specific moment, person, place, or feeling
          they mentioned.

        Return ONLY the JSON object, no markdown, no commentary.
        """

        let payload: Payload = try await client.completeJSON(
            model: model,
            systemPrompt: system,
            userPrompt: user,
            temperature: 0.3,
            maxTokens: 500,
            timeout: 25
        )
        return payload.toDomain()
    }

    // MARK: - Wire type

    private struct Payload: Decodable {
        let insight: String
        let question: String

        func toDomain() -> DeepDive {
            DeepDive(
                insight: insight.trimmingCharacters(in: .whitespacesAndNewlines),
                question: question.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}
