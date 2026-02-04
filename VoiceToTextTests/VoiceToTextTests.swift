import Testing
import Foundation
@testable import VoiceToText

@Test
func exampleTest() {
    // Placeholder test to verify Swift Testing is configured
    let expectation = 1 + 1
    #expect(expectation == 2)
}

@Test
func appStateEnumExists() {
    let state = AppState.idle
    #expect(state.displayName == "Idle")
}

@Test
func transcriptionModelExists() {
    let transcription = Transcription(text: "Test text")
    #expect(transcription.text == "Test text")
    #expect(transcription.id != UUID())
}
