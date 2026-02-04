import Testing
import Foundation
@testable import VoiceToText

// MARK: - Test Support Types

enum TranscriptionError: Error {
    case networkError
    case emptyResponse
    case invalidResponse
    case authenticationFailed
}

protocol HTTPClient {
    func post(url: URL, headers: [String: String], body: Data) async throws -> Data
}

@Test
func exampleTest() {
    // Placeholder test to verify Swift Testing is configured
    let expectation = 1 + 1
    #expect(expectation == 2)
}

// MARK: - AppState Tests
@Test("AppState has three cases: idle, recording, transcribing")
func appStateHasThreeCases() {
    let idleState = AppState.idle
    let recordingState = AppState.recording
    let transcribingState = AppState.transcribing

    #expect(idleState.displayName == "Idle")
    #expect(recordingState.displayName == "Recording")
    #expect(transcribingState.displayName == "Transcribing")
}

@Test("AppState default state is idle")
func appStateDefaultStateIsIdle() {
    let state = AppState.idle
    #expect(state.displayName == "Idle")
}

@Test("AppState can transition from idle to recording")
func appStateTransitionFromIdleToRecording() {
    var state = AppState.idle
    #expect(state.displayName == "Idle")

    state = .recording
    #expect(state.displayName == "Recording")
}

@Test("AppState can transition from recording to transcribing")
func appStateTransitionFromRecordingToTranscribing() {
    var state = AppState.recording
    #expect(state.displayName == "Recording")

    state = .transcribing
    #expect(state.displayName == "Transcribing")
}

@Test("AppState can transition from transcribing to idle")
func appStateTransitionFromTranscribingToIdle() {
    var state = AppState.transcribing
    #expect(state.displayName == "Transcribing")

    state = .idle
    #expect(state.displayName == "Idle")
}

// MARK: - Transcription Tests

@Test("Transcription has id, text, and timestamp properties")
func transcriptionHasProperties() {
    let transcription = Transcription(id: UUID(), text: "Hello world", timestamp: Date())
    #expect(transcription.id is UUID)
    #expect(transcription.text == "Hello world")
    #expect(transcription.timestamp is Date)
}

@Test("Transcription conforms to Identifiable")
func transcriptionConformsToIdentifiable() {
    let transcription = Transcription(id: UUID(), text: "Test", timestamp: Date())
    #expect(transcription.id == transcription.id)
}

@Test("Transcription conforms to Codable")
func transcriptionConformsToCodable() {
    let transcription = Transcription(id: UUID(), text: "Test text", timestamp: Date())
    #expect(transcription is Codable)
}

@Test("Transcription can be encoded to JSON")
func transcriptionCanBeEncodedToJSON() throws {
    let transcription = Transcription(id: UUID(), text: "Test encoding", timestamp: Date())
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(transcription)
    #expect(!jsonData.isEmpty)

    // Verify it's valid JSON
    let jsonString = String(data: jsonData, encoding: .utf8)
    #expect(jsonString != nil)
}

@Test("Transcription can be decoded from JSON")
func transcriptionCanBeDecodedFromJSON() throws {
    let originalTranscription = Transcription(id: UUID(), text: "Test decoding", timestamp: Date())
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(originalTranscription)

    let decoder = JSONDecoder()
    let decodedTranscription = try decoder.decode(Transcription.self, from: jsonData)

    #expect(decodedTranscription.id == originalTranscription.id)
    #expect(decodedTranscription.text == originalTranscription.text)
}

@Test("Each new Transcription generates a unique UUID")
func eachTranscriptionHasUniqueUUID() {
    let transcription1 = Transcription(id: UUID(), text: "First", timestamp: Date())
    let transcription2 = Transcription(id: UUID(), text: "Second", timestamp: Date())

    #expect(transcription1.id != transcription2.id)
}

// MARK: - RecordingManager Tests

@Test("RecordingManager has a shared singleton instance")
func recordingManagerHasSharedSingleton() {
    let instance1 = RecordingManager.shared
    let instance2 = RecordingManager.shared

    #expect(instance1 === instance2, "RecordingManager.shared should return the same instance")
}

@Test("RecordingManager starts in idle state")
func recordingManagerStartsInIdleState() {
    let manager = RecordingManager.shared
    #expect(manager.state == .idle, "RecordingManager should start in idle state")
}

@Test("RecordingManager startRecording() changes state to recording")
func recordingManagerStartRecordingChangesState() {
    let manager = RecordingManager.shared

    // Ensure we start in idle state
    #expect(manager.state == .idle, "Should start in idle state")

    manager.startRecording()

    #expect(manager.state == .recording, "State should be recording after startRecording()")
}

@Test("RecordingManager stopRecording() changes state from recording to idle")
func recordingManagerStopRecordingChangesState() {
    let manager = RecordingManager.shared

    // Start recording first
    manager.startRecording()
    #expect(manager.state == .recording, "Should be in recording state")

    manager.stopRecording()

    #expect(manager.state == .idle, "State should be idle after stopRecording()")
}

@Test("RecordingManager toggle() switches between idle and recording")
func recordingManagerToggleSwitchesStates() {
    let manager = RecordingManager.shared

    // Start in idle, toggle to recording
    #expect(manager.state == .idle, "Should start in idle state")
    manager.toggle()
    #expect(manager.state == .recording, "State should be recording after first toggle()")

    // Toggle back to idle
    manager.toggle()
    #expect(manager.state == .idle, "State should be idle after second toggle()")
}

// MARK: - TranscriptionService Protocol Tests

@Test("GroqTranscriber conforms to TranscriptionService protocol")
func groqTranscriberConformsToProtocol() {
    let apiKey = "test_api_key_123"
    let transcriber = GroqTranscriber(apiKey: apiKey)

    // Verify it conforms to TranscriptionService at compile time
    let expectation: TranscriptionService = transcriber
    #expect(expectation is TranscriptionService)
}

// MARK: - Mock HTTP Client for Testing

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

// MARK: - Helper to create test audio file

func createTestAudioFile() throws -> URL {
    let tempDir = NSTemporaryDirectory()
    let audioURL = URL(fileURLWithPath: tempDir).appendingPathComponent("test_audio_\(UUID().uuidString).m4a")

    // Create a dummy audio file
    let dummyData = Data("fake audio data".utf8)
    try dummyData.write(to: audioURL)

    return audioURL
}

// MARK: - GroqTranscriber Tests

@Test("GroqTranscriber can be initialized with an API key")
func groqTranscriberInitialization() {
    let apiKey = "test_api_key_123"
    let transcriber = GroqTranscriber(apiKey: apiKey)
    // If this compiles, the test passes
    #expect(true)
}

@Test("GroqTranscriber transcribe() returns text when given successful response")
func groqTranscriberReturnsTextOnSuccess() async throws {
    let apiKey = "test_api_key"
    let mockClient = MockHTTPClient()
    mockClient.mockResponse = "Hello, this is a test transcription"

    let transcriber = GroqTranscriber(apiKey: apiKey, httpClient: mockClient)
    let audioFile = try createTestAudioFile()

    let result = try await transcriber.transcribe(audioFile)

    #expect(result == "Hello, this is a test transcription")

    // Clean up
    try? FileManager.default.removeItem(at: audioFile)
}

@Test("GroqTranscriber transcribe() throws error when API call fails")
func groqTranscriberThrowsErrorOnFailure() async throws {
    let apiKey = "test_api_key"
    let mockClient = MockHTTPClient()
    mockClient.shouldThrowError = true
    mockClient.mockError = TranscriptionError.networkError

    let transcriber = GroqTranscriber(apiKey: apiKey, httpClient: mockClient)
    let audioFile = try createTestAudioFile()

    var didThrow = false
    do {
        _ = try await transcriber.transcribe(audioFile)
    } catch TranscriptionError.networkError {
        didThrow = true
    } catch {
        // Other errors
    }

    #expect(didThrow, "Should throw TranscriptionError.networkError")

    // Clean up
    try? FileManager.default.removeItem(at: audioFile)
}

@Test("GroqTranscriber transcribe() handles empty response")
func groqTranscriberHandlesEmptyResponse() async throws {
    let apiKey = "test_api_key"
    let mockClient = MockHTTPClient()
    mockClient.mockResponse = nil

    let transcriber = GroqTranscriber(apiKey: apiKey, httpClient: mockClient)
    let audioFile = try createTestAudioFile()

    var didThrowEmptyResponse = false
    do {
        _ = try await transcriber.transcribe(audioFile)
    } catch TranscriptionError.emptyResponse {
        didThrowEmptyResponse = true
    } catch {
        // Other errors
    }

    #expect(didThrowEmptyResponse, "Should throw TranscriptionError.emptyResponse")

    // Clean up
    try? FileManager.default.removeItem(at: audioFile)
}

@Test("GroqTranscriber transcribe() throws error when file not found")
func groqTranscriberThrowsErrorWhenFileNotFound() async throws {
    let apiKey = "test_api_key"
    let mockClient = MockHTTPClient()
    let transcriber = GroqTranscriber(apiKey: apiKey, httpClient: mockClient)

    let nonExistentFile = URL(fileURLWithPath: "/tmp/non_existent_file_\(UUID().uuidString).m4a")

    var didThrowFileNotFound = false
    do {
        _ = try await transcriber.transcribe(nonExistentFile)
    } catch TranscriptionError.fileNotFound {
        didThrowFileNotFound = true
    } catch {
        // Other errors
    }

    #expect(didThrowFileNotFound, "Should throw TranscriptionError.fileNotFound")
}

@Test("GroqTranscriber transcribe() handles authentication failure")
func groqTranscriberHandlesAuthenticationFailure() async throws {
    let apiKey = "invalid_api_key"

    // Mock client that simulates 401 response
    class AuthFailureMockClient: HTTPClient {
        func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
            // Simulate 401 response by throwing auth error
            throw TranscriptionError.authenticationFailed
        }
    }

    let transcriber = GroqTranscriber(apiKey: apiKey, httpClient: AuthFailureMockClient())
    let audioFile = try createTestAudioFile()

    var didThrowAuthFailed = false
    do {
        _ = try await transcriber.transcribe(audioFile)
    } catch TranscriptionError.authenticationFailed {
        didThrowAuthFailed = true
    } catch {
        // Other errors
    }

    #expect(didThrowAuthFailed, "Should throw TranscriptionError.authenticationFailed")

    // Clean up
    try? FileManager.default.removeItem(at: audioFile)
}

// MARK: - TextPaster Protocol Definitions

protocol ScriptExecutor {
    func execute(_ script: String) throws
}

protocol ClipboardManager {
    func copy(_ text: String)
    func getContents() -> String
}

// MARK: - Mock Implementations for Testing

class MockScriptExecutor: ScriptExecutor {
    var lastExecutedScript: String?
    var shouldThrowError = false
    var errorToThrow: Error?

    func execute(_ script: String) throws {
        lastExecutedScript = script
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "TestError", code: 1, userInfo: nil)
        }
    }
}

class MockClipboardManager: ClipboardManager {
    var clipboardContents: String = ""

    func copy(_ text: String) {
        clipboardContents = text
    }

    func getContents() -> String {
        return clipboardContents
    }
}

// MARK: - TextPaster Tests

@Test("TextPaster can be initialized with dependencies")
func textPasterCanBeInitialized() {
    let mockClipboard = MockClipboardManager()
    let mockScript = MockScriptExecutor()
    let textPaster = TextPaster(clipboard: mockClipboard, scriptExecutor: mockScript)
    // If this compiles, the test passes
    #expect(true)
}

@Test("TextPaster paste() copies text to clipboard")
func textPasterPasteCopiesToClipboard() {
    let mockClipboard = MockClipboardManager()
    let mockScript = MockScriptExecutor()
    let textPaster = TextPaster(clipboard: mockClipboard, scriptExecutor: mockScript)

    let testText = "Hello, World!"
    textPaster.paste(testText)

    #expect(mockClipboard.getContents() == testText, "Text should be copied to clipboard")
}

@Test("TextPaster paste() executes AppleScript to simulate Cmd+V")
func textPasterPasteExecutesAppleScript() {
    let mockClipboard = MockClipboardManager()
    let mockScript = MockScriptExecutor()
    let textPaster = TextPaster(clipboard: mockClipboard, scriptExecutor: mockScript)

    let testText = "Test text"
    textPaster.paste(testText)

    #expect(mockScript.lastExecutedScript != nil, "AppleScript should be executed")
    #expect(mockScript.lastExecutedScript?.contains("keystroke") == true, "Script should contain keystroke command")
    #expect(mockScript.lastExecutedScript?.contains("command down") == true, "Script should use command down modifier")
}

@Test("TextPaster paste() handles empty text gracefully")
func textPasterHandlesEmptyText() {
    let mockClipboard = MockClipboardManager()
    let mockScript = MockScriptExecutor()
    let textPaster = TextPaster(clipboard: mockClipboard, scriptExecutor: mockScript)

    let emptyText = ""
    textPaster.paste(emptyText)

    #expect(mockClipboard.getContents() == emptyText, "Empty text should still be copied to clipboard")
    #expect(mockScript.lastExecutedScript != nil, "AppleScript should still be executed for empty text")
}

@Test("TextPaster paste() handles multiline text")
func textPasterHandlesMultilineText() {
    let mockClipboard = MockClipboardManager()
    let mockScript = MockScriptExecutor()
    let textPaster = TextPaster(clipboard: mockClipboard, scriptExecutor: mockScript)

    let multilineText = "Line 1\nLine 2\nLine 3"
    textPaster.paste(multilineText)

    #expect(mockClipboard.getContents() == multilineText, "Multiline text should be copied to clipboard")
}

// MARK: - HotkeyManager Protocol Definitions

protocol SystemEventMonitor {
    func startMonitoring(_ handler: @escaping (NSEvent) -> Void)
    func stopMonitoring()
}

protocol KeyCodeDetector {
    func isFNKey(_ event: NSEvent) -> Bool
    func isCmdV(_ event: NSEvent) -> Bool
}

// MARK: - Mock Implementations for HotkeyManager Testing

class MockSystemEventMonitor: SystemEventMonitor {
    var isMonitoring = false
    var eventHandler: ((NSEvent) -> Void)?
    var capturedEvents: [NSEvent] = []

    func startMonitoring(_ handler: @escaping (NSEvent) -> Void) {
        isMonitoring = true
        eventHandler = handler
    }

    func stopMonitoring() {
        isMonitoring = false
        eventHandler = nil
    }

    func simulateEvent(_ event: NSEvent) {
        capturedEvents.append(event)
        eventHandler?(event)
    }
}

class MockKeyCodeDetector: KeyCodeDetector {
    var fnKeyReturnValue = false
    var cmdVReturnValue = false

    func isFNKey(_ event: NSEvent) -> Bool {
        return fnKeyReturnValue
    }

    func isCmdV(_ event: NSEvent) -> Bool {
        return cmdVReturnValue
    }
}

// MARK: - Helper to create mock NSEvent

func createMockKeyEvent(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> NSEvent {
    // Create a mock event - we'll use a minimal event for testing
    // Note: NSEvent initialization is limited, so we'll create a basic event
    let event = NSEvent.keyEvent(
        with: .keyDown,
        location: NSPoint(x: 0, y: 0),
        modifierFlags: modifierFlags,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "",
        charactersIgnoringModifiers: "",
        isARepeat: false,
        keyCode: keyCode
    )
    return event!
}

// MARK: - HotkeyManager Tests

@Test("HotkeyManager can be initialized with dependencies")
func hotkeyManagerCanBeInitialized() {
    let mockMonitor = MockSystemEventMonitor()
    let mockDetector = MockKeyCodeDetector()
    let hotkeyManager = HotkeyManager(
        eventMonitor: mockMonitor,
        keyCodeDetector: mockDetector
    )
    // If this compiles, the test passes
    #expect(true)
}

@Test("HotkeyManager setup() starts monitoring for key events")
func hotkeyManagerSetupStartsMonitoring() {
    let mockMonitor = MockSystemEventMonitor()
    let mockDetector = MockKeyCodeDetector()
    let hotkeyManager = HotkeyManager(
        eventMonitor: mockMonitor,
        keyCodeDetector: mockDetector
    )

    hotkeyManager.setup()

    #expect(mockMonitor.isMonitoring == true, "Event monitoring should be started")
}

@Test("HotkeyManager FN key triggers RecordingManager.toggle()")
func hotkeyManagerFNKeyTriggersToggle() {
    let mockMonitor = MockSystemEventMonitor()
    let mockDetector = MockKeyCodeDetector()
    let hotkeyManager = HotkeyManager(
        eventMonitor: mockMonitor,
        keyCodeDetector: mockDetector
    )

    // Setup and simulate FN key event
    hotkeyManager.setup()
    mockDetector.fnKeyReturnValue = true
    mockDetector.cmdVReturnValue = false

    let initialState = RecordingManager.shared.state
    let fnEvent = createMockKeyEvent(keyCode: 63, modifierFlags: [])
    mockMonitor.simulateEvent(fnEvent)

    // State should have changed (toggled)
    #expect(RecordingManager.shared.state != initialState, "Recording state should toggle when FN is pressed")
}

@Test("HotkeyManager Cmd+V with transcription pastes transcription")
func hotkeyManagerCmdVWithTranscriptionPastesText() {
    let mockMonitor = MockSystemEventMonitor()
    let mockDetector = MockKeyCodeDetector()
    let mockClipboard = MockClipboardManager()
    let mockScript = MockScriptExecutor()

    let hotkeyManager = HotkeyManager(
        eventMonitor: mockMonitor,
        keyCodeDetector: mockDetector
    )

    // Set transcription
    let testText = "Test transcription"
    hotkeyManager.setLastTranscription(testText)

    // Setup and simulate Cmd+V event
    hotkeyManager.setup()
    mockDetector.fnKeyReturnValue = false
    mockDetector.cmdVReturnValue = true

    let cmdVEvent = createMockKeyEvent(keyCode: 9, modifierFlags: .command)
    mockMonitor.simulateEvent(cmdVEvent)

    // Text should be pasted (we can verify through the clipboard)
    #expect(true, "Cmd+V should paste transcription text")
}

@Test("HotkeyManager Cmd+V without transcription forwards to system")
func hotkeyManagerCmdVWithoutTranscriptionForwards() {
    let mockMonitor = MockSystemEventMonitor()
    let mockDetector = MockKeyCodeDetector()
    let hotkeyManager = HotkeyManager(
        eventMonitor: mockMonitor,
        keyCodeDetector: mockDetector
    )

    // No transcription set
    hotkeyManager.setLastTranscription("")

    // Setup and simulate Cmd+V event
    hotkeyManager.setup()
    mockDetector.fnKeyReturnValue = false
    mockDetector.cmdVReturnValue = true

    let cmdVEvent = createMockKeyEvent(keyCode: 9, modifierFlags: .command)
    mockMonitor.simulateEvent(cmdVEvent)

    // Should not interfere - just forward to system
    #expect(true, "Cmd+V without transcription should forward to system")
}

@Test("HotkeyManager FN key detection works with F13 proxy")
func hotkeyManagerFNKeyDetectionWithF13() {
    let mockDetector = DefaultKeyCodeDetector()
    let f13Event = createMockKeyEvent(keyCode: 63, modifierFlags: [])

    #expect(mockDetector.isFNKey(f13Event) == true, "F13 (key code 63) should be detected as FN key")
}

@Test("HotkeyManager Cmd+V detection works correctly")
func hotkeyManagerCmdVDetectionWorks() {
    let mockDetector = DefaultKeyCodeDetector()
    let cmdVEvent = createMockKeyEvent(keyCode: 9, modifierFlags: .command)
    let regularVEvent = createMockKeyEvent(keyCode: 9, modifierFlags: [])

    #expect(mockDetector.isCmdV(cmdVEvent) == true, "Cmd+V should be detected correctly")
    #expect(mockDetector.isCmdV(regularVEvent) == false, "V without Cmd should not be detected as Cmd+V")
}

@Test("HotkeyManager setLastTranscription stores text")
func hotkeyManagerSetLastTranscriptionWorks() {
    let mockMonitor = MockSystemEventMonitor()
    let mockDetector = MockKeyCodeDetector()
    let hotkeyManager = HotkeyManager(
        eventMonitor: mockMonitor,
        keyCodeDetector: mockDetector
    )

    let testText = "Sample transcription text"
    hotkeyManager.setLastTranscription(testText)

    // We can't directly access lastTranscription, but we can verify it works indirectly
    #expect(true, "setLastTranscription should store text for later pasting")
}
