import Foundation

// MARK: - Groq Transcription Service

struct GroqTranscriber: TranscriptionService {
    private let apiKey: String
    private let baseURL = "https://api.groq.com/openai/v1/audio/transcriptions"
    private let httpClient: HTTPClient

    init(apiKey: String, httpClient: HTTPClient = DefaultHTTPClient()) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    func transcribe(_ audioURL: URL) async throws -> String {
        // Check if API is configured
        guard !apiKey.isEmpty else {
            throw TranscriptionError.authenticationFailed
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.fileNotFound
        }

        // Read audio file data
        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw TranscriptionError.invalidAudioFormat
        }

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Create request
        guard let url = URL(string: baseURL) else {
            throw TranscriptionError.invalidResponse
        }

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "multipart/form-data; boundary=\(boundary)"
        ]

        // Make request
        let responseData = try await httpClient.post(url: url, headers: headers, body: body)

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let text = json["text"] as? String,
              !text.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return text
    }
}

// MARK: - Shared Singleton

extension GroqTranscriber {
    static var shared: GroqTranscriber {
        // TODO: Store this in a config file or Keychain instead of hardcoding
        let apiKey = "REDACTED_GROQ_API_KEY"

        if apiKey.isEmpty {
            return GroqTranscriber(apiKey: "")
        }

        return GroqTranscriber(apiKey: apiKey)
    }

    func isConfigured() -> Bool {
        return !apiKey.isEmpty
    }
}

// MARK: - Legacy Support (for backward compatibility)

class LegacyGroqTranscriber {
    private let transcriber: GroqTranscriber

    init() {
        guard let apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] else {
            fatalError("GROQ_API_KEY environment variable not set")
        }
        self.transcriber = GroqTranscriber(apiKey: apiKey)
    }

    func transcribe(audioFileURL: URL) async throws -> Transcription {
        let text = try await transcriber.transcribe(audioFileURL)
        return Transcription(text: text)
    }

    func isConfigured() -> Bool {
        return ProcessInfo.processInfo.environment["GROQ_API_KEY"] != nil
    }
}
