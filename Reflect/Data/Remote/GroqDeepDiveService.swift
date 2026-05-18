import Foundation

/// Direct-to-Groq implementation of `DeepDiveService`.
///
/// Uses a fast small model since the prose output is short and the user is
/// waiting on the node-detail sheet.
final actor GroqDeepDiveService: DeepDiveService {
    private let client: GroqClient
    private let model: String

    init(client: GroqClient, model: String = "llama-3.1-8b-instant") {
        self.client = client
        self.model = model
    }

    func expand(themeLabel: String, transcript: String) async throws -> String {
        let system = "You are helping a user reflect deeply on a specific theme from their journal entry."
        let user = """
        The user journaled: \(transcript)
        Theme to explore: \(themeLabel)

        Write a 2-3 paragraph reflection on this theme. Include:
        1. Quote 1-2 relevant sentences from their entry using exact words.
        2. Expand on the emotional weight of this theme based on what they shared.
        3. End with one specific, contextual reflection question that helps them go deeper.
        """
        return try await client.completeText(
            model: model,
            systemPrompt: system,
            userPrompt: user,
            temperature: 0.2,
            timeout: 20
        )
    }
}
