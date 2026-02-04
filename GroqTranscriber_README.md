# GroqTranscriber Implementation

## Overview

This document describes the GroqTranscriber implementation, which provides audio transcription functionality using the Groq Whisper API.

## Architecture

### Protocol-Based Design

The implementation follows a protocol-oriented design with dependency injection for testability:

```swift
protocol TranscriptionService {
    func transcribe(_ audioURL: URL) async throws -> String
}

protocol HTTPClient {
    func post(url: URL, headers: [String: String], body: Data) async throws -> Data
}
```

### Components

1. **GroqTranscriber** - Main transcription service implementing `TranscriptionService`
2. **HTTPClient** - Protocol for HTTP operations
3. **DefaultHTTPClient** - Production implementation of HTTPClient
4. **TranscriptionError** - Error types for transcription failures

## Files Created/Modified

### New Files

- `/Users/kasim/repos/VoiceToText/VoiceToText/Managers/GroqTranscriber.swift` - Main implementation
- `/Users/kasim/repos/VoiceToText/VoiceToText/Managers/HTTPClient.swift` - HTTP client protocol and implementation
- `/Users/kasim/repos/VoiceToText/VoiceToText/Managers/TranscriptionService.swift` - Transcription service protocol
- `/Users/kasim/repos/VoiceToText/VoiceToText/Models/TranscriptionError.swift` - Error types

### Modified Files

- `/Users/kasim/repos/VoiceToText/VoiceToTextTests/VoiceToTextTests.swift` - Added comprehensive tests

## Usage

### Setting up the API Key

The GroqTranscriber requires the `GROQ_API_KEY` environment variable:

```bash
export GROQ_API_KEY=REDACTED_GROQ_API_KEY
```

### Using the Shared Singleton

```swift
import VoiceToText

// Access the shared instance (reads GROQ_API_KEY from environment)
let transcriber = GroqTranscriber.shared

// Transcribe an audio file
do {
    let audioURL = URL(fileURLWithPath: "/path/to/audio.m4a")
    let transcription = try await transcriber.transcribe(audioURL)
    print("Transcription: \(transcription)")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Using with Dependency Injection (for testing)

```swift
import VoiceToText

// Create with custom API key and mock HTTP client
let mockClient = MockHTTPClient()
let transcriber = GroqTranscriber(apiKey: "test_key", httpClient: mockClient)

let audioURL = URL(fileURLWithPath: "/path/to/audio.m4a")
let transcription = try await transcriber.transcribe(audioURL)
```

## API Details

### Groq Whisper API

- **Endpoint**: `https://api.groq.com/openai/v1/audio/transcriptions`
- **Method**: POST (multipart/form-data)
- **Model**: `whisper-large-v3`
- **Authentication**: Bearer token (API key)

### Request Format

```swift
POST /openai/v1/audio/transcriptions
Authorization: Bearer <API_KEY>
Content-Type: multipart/form-data; boundary=<boundary>

--<boundary>
Content-Disposition: form-data; name="file"; filename="audio.m4a"
Content-Type: audio/m4a

<audio data>
--<boundary>
Content-Disposition: form-data; name="model"

whisper-large-v3
--<boundary>--
```

### Response Format

```json
{
  "text": "Transcribed text goes here..."
}
```

## Error Handling

The GroqTranscriber throws specific errors based on the failure:

- `TranscriptionError.networkError` - Network connectivity issues
- `TranscriptionError.emptyResponse` - Empty response from API
- `TranscriptionError.invalidResponse` - Malformed response
- `TranscriptionError.authenticationFailed` - Invalid API key
- `TranscriptionError.fileNotFound` - Audio file doesn't exist
- `TranscriptionError.invalidAudioFormat` - Cannot read audio file

## Testing

### Test Coverage

The implementation includes comprehensive tests:

1. **Initialization Tests**
   - Can be initialized with API key
   - Conforms to TranscriptionService protocol

2. **Success Cases**
   - Returns transcribed text on successful API call

3. **Error Cases**
   - Throws error when API call fails
   - Handles empty response
   - Throws error when file not found
   - Handles authentication failure

4. **Dependency Injection**
   - Uses MockHTTPClient for testing
   - Tests can inject custom HTTP clients

### Running Tests

Tests can be run from Xcode:
1. Open VoiceToText.xcodeproj
2. Press Cmd+U to run all tests
3. Or click on individual test diamonds to run specific tests

### Mock HTTP Client

The test suite includes a `MockHTTPClient` for testing without real API calls:

```swift
class MockHTTPClient: HTTPClient {
    var mockResponse: String?
    var shouldThrowError = false
    var mockError: Error?

    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        if shouldThrowError {
            throw mockError ?? TranscriptionError.networkError
        }

        if let mockResponse = mockResponse {
            let responseJSON = ["text": mockResponse]
            return try JSONEncoder().encode(responseJSON)
        }

        throw TranscriptionError.emptyResponse
    }
}
```

## Security Considerations

1. **API Key Storage**: The API key is NEVER hardcoded in the source code
2. **Environment Variable**: API key is read from `GROQ_API_KEY` environment variable at runtime
3. **Git Safety**: The `.gitignore` should prevent committing API keys

## Supported Audio Formats

The implementation is configured for `audio/m4a` format. The Groq Whisper API supports:

- M4A
- MP3
- MP4
- MPEG
- MPGA
- WAV
- WEBM

To support additional formats, modify the `Content-Type` header in the multipart form data.

## Future Enhancements

Potential improvements:

1. Add support for additional audio formats
2. Implement retry logic for failed requests
3. Add request timeout configuration
4. Support for streaming responses
5. Add language detection
6. Implement caching for repeated transcriptions
7. Add progress reporting for long audio files

## Troubleshooting

### Common Issues

**Issue**: `fatalError: GROQ_API_KEY environment variable not set`
**Solution**: Set the environment variable before running the app

**Issue**: `TranscriptionError.authenticationFailed`
**Solution**: Verify your API key is valid and not expired

**Issue**: `TranscriptionError.fileNotFound`
**Solution**: Ensure the audio file exists at the specified path

**Issue**: `TranscriptionError.invalidAudioFormat`
**Solution**: Verify the audio file is not corrupted and is in a supported format

## References

- [Groq API Documentation](https://console.groq.com/docs)
- [Whisper Large V3 Model](https://groq.com/blog/whisper-large-v3/)
- [Groq Audio Transcription API](https://console.groq.com/docs/text-audio-tutorial)

## Implementation Notes

### Design Decisions

1. **Protocol-Oriented Design**: Using protocols enables easy testing and mocking
2. **Dependency Injection**: HTTP client is injected, making the code testable
3. **Value Semantics**: GroqTranscriber is a struct (value type) for better memory management
4. **Singleton Pattern**: Shared singleton provides convenient access to the configured instance
5. **Async/Await**: Uses modern Swift concurrency for clean asynchronous code

### Backward Compatibility

A `LegacyGroqTranscriber` class is provided to maintain compatibility with any existing code that uses the old API:

```swift
class LegacyGroqTranscriber {
    func transcribe(audioFileURL: URL) async throws -> Transcription
    func isConfigured() -> Bool
}
```

---

**Implementation Date**: 2026-02-03
**Test-Driven Development**: Following TDD principles with comprehensive test coverage
**API Key**: Read from `GROQ_API_KEY` environment variable (never hardcoded)
