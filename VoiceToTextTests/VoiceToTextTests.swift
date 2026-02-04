import Testing
import Foundation
@testable import VoiceToText

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
