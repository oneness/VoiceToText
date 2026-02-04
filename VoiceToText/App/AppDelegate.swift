import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("VoiceToText app starting...")

        // Step 1: Setup menu bar UI
        StatusItemController.shared.setup()

        // Step 2: Setup global hotkeys (FN key and Cmd+V)
        HotkeyManager.shared.setup()

        // Step 3: Setup recording workflow
        setupRecordingWorkflow()

        print("VoiceToText app started successfully")
    }

    private func setupRecordingWorkflow() {
        // Observe RecordingManager state changes
        RecordingManager.shared.$state
            .dropFirst() // Skip initial value
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        // Set up callback when recording stops
        RecordingManager.shared.onRecordingComplete = { [weak self] audioURL in
            self?.handleRecordingComplete(audioURL)
        }
    }

    private func handleStateChange(_ state: AppState) {
        print("App state changed to: \(state.displayName)")

        // StatusItemController automatically observes RecordingManager state
        // via Combine, so we don't need to manually update it here
    }

    private func handleRecordingComplete(_ audioURL: URL) {
        print("Recording complete, starting transcription...")

        // Update state to transcribing
        RecordingManager.shared.state = .transcribing

        // Run transcription in background
        Task { @MainActor in
            do {
                // Step 1: Transcribe the audio
                let transcribedText = try await GroqTranscriber.shared.transcribe(audioURL)

                print("Transcription successful: \(transcribedText)")

                // Step 2: Paste the text using TextPaster
                TextPaster.shared.paste(transcribedText)

                // Step 3: Save transcription to HotkeyManager for Cmd+V
                HotkeyManager.shared.setLastTranscription(transcribedText)

                // Step 4: Create and store transcription
                let transcription = Transcription(
                    id: UUID(),
                    text: transcribedText,
                    timestamp: Date()
                )

                // Add to history
                TranscriptionHistoryManager.shared.add(transcription)

                // Update StatusItemController with new history
                StatusItemController.shared.updateHistory(
                    TranscriptionHistoryManager.shared.transcriptions
                )

                print("Created transcription: \(transcription.text)")

                // Step 5: Return to idle state
                RecordingManager.shared.state = .idle

            } catch {
                print("Transcription failed: \(error.localizedDescription)")

                // Even on error, return to idle state
                RecordingManager.shared.state = .idle
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        HotkeyManager.shared.stopMonitoring()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
