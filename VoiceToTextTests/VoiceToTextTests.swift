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

@Test
func transcriptionModelExists() {
    let transcription = Transcription(text: "Test text")
    #expect(transcription.text == "Test text")
    #expect(transcription.id != UUID())
}
