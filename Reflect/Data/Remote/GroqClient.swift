import Foundation

/// Shared HTTP client for Groq's OpenAI-compatible chat completions endpoint.
///
/// Wraps auth + JSON envelope handling so callers only see typed payloads.
/// Use `completeJSON` when the model is asked for `response_format: json_object`
/// and `completeText` when expecting free-form prose.
actor GroqClient {
    enum Failure: Error, LocalizedError {
        case missingAPIKey
        case http(statusCode: Int, body: String)
        case emptyContent
        case undecodableContent(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Groq API key is missing. Add it to Secrets.plist."
            case .http(let code, let body):
                return "Groq returned HTTP \(code): \(body.prefix(200))"
            case .emptyContent:
                return "Groq returned an empty response."
            case .undecodableContent(let raw):
                return "Could not decode Groq response: \(raw.prefix(200))"
            }
        }
    }

    private let apiKey: String
    private let session: URLSession
    private let endpoint: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        apiKey: String,
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    /// Sends a chat completion expecting JSON content; decodes that content as `T`.
    func completeJSON<T: Decodable>(
        model: String,
        systemPrompt: String? = nil,
        userPrompt: String,
        temperature: Double = 0.1,
        maxTokens: Int? = nil,
        timeout: TimeInterval = 25,
        as type: T.Type = T.self
    ) async throws -> T {
        let content = try await sendCompletion(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: temperature,
            maxTokens: maxTokens,
            jsonObjectMode: true,
            timeout: timeout
        )
        guard let data = content.data(using: .utf8) else {
            throw Failure.undecodableContent(content)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw Failure.undecodableContent(content)
        }
    }

    /// Sends a chat completion and returns the raw text content (trimmed).
    func completeText(
        model: String,
        systemPrompt: String? = nil,
        userPrompt: String,
        temperature: Double = 0.2,
        timeout: TimeInterval = 15
    ) async throws -> String {
        try await sendCompletion(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: temperature,
            maxTokens: nil,
            jsonObjectMode: false,
            timeout: timeout
        )
    }

    private func sendCompletion(
        model: String,
        systemPrompt: String?,
        userPrompt: String,
        temperature: Double,
        maxTokens: Int?,
        jsonObjectMode: Bool,
        timeout: TimeInterval
    ) async throws -> String {
        try guardAPIKey()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [Message] = []
        if let systemPrompt {
            messages.append(Message(role: "system", content: systemPrompt))
        }
        messages.append(Message(role: "user", content: userPrompt))

        let body = RequestBody(
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: maxTokens,
            response_format: jsonObjectMode ? .jsonObject : nil
        )
        request.httpBody = try encoder.encode(body)

        print("🌐 Groq → POST \(endpoint.absoluteString) model=\(model) json=\(jsonObjectMode)")
        let started = Date()
        let (data, response) = try await session.data(for: request)
        let elapsed = String(format: "%.2fs", Date().timeIntervalSince(started))
        guard let http = response as? HTTPURLResponse else {
            print("❌ Groq → no HTTP response after \(elapsed)")
            throw Failure.http(statusCode: -1, body: "no response")
        }
        guard http.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
            print("❌ Groq → HTTP \(http.statusCode) after \(elapsed): \(bodyText.prefix(300))")
            throw Failure.http(statusCode: http.statusCode, body: bodyText)
        }
        print("✅ Groq → HTTP 200 in \(elapsed) (\(data.count) bytes)")
        let envelope = try decoder.decode(ChatCompletionResponse.self, from: data)
        let content = envelope.choices.first?.message.content ?? ""
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw Failure.emptyContent }
        return trimmed
    }

    private func guardAPIKey() throws {
        if apiKey.isEmpty || apiKey == AppConfig.placeholderAPIKey {
            throw Failure.missingAPIKey
        }
    }

    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct ResponseFormat: Encodable {
        let type: String
        static let jsonObject = ResponseFormat(type: "json_object")
    }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int?
        let response_format: ResponseFormat?
    }

    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String }
        let choices: [Choice]
    }
}
