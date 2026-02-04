import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private let setupChecker = SetupChecker()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("VoiceToText app starting...")
        NSLog("VoiceToText app starting...")

        // Skip welcome screen for now - always initialize
        print("Initializing app...")
        NSLog("Initializing app...")
        initializeApp()

        print("VoiceToText app started successfully")
        NSLog("VoiceToText app started successfully")
    }

    private func showWelcomeScreen() {
        print("First launch detected - showing welcome screen")
        NSLog("First launch detected - showing welcome screen")

        let welcomeVC = WelcomeViewController(setupChecker: setupChecker)

        // Create a window to host the welcome screen
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 750),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to VoiceToText"
        window.contentViewController = welcomeVC
        window.makeKeyAndOrderFront(nil)

        // Set up a notification observer to detect when setup is complete
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            if self?.setupChecker.hasCompletedSetup() == true {
                print("Setup completed - initializing app")
                NSLog("Setup completed - initializing app")
                self?.initializeApp()
            }
        }
    }

    private func initializeApp() {
        print("initializeApp() called")
        NSLog("initializeApp() called")

        // Step 1: Setup menu bar UI - create instance directly
        print("Creating StatusItemController instance...")
        NSLog("Creating StatusItemController instance...")
        statusItemController = StatusItemController()
        print("StatusItemController instance created")
        NSLog("StatusItemController instance created")

        // Step 2: Setup global hotkeys (FN key and Cmd+V)
        print("About to call HotkeyManager.shared.setup()")
        NSLog("About to call HotkeyManager.shared.setup()")
        HotkeyManager.shared.setup()
        print("HotkeyManager setup complete")
        NSLog("HotkeyManager setup complete")

        // Step 3: Setup recording workflow
        print("About to setup recording workflow")
        NSLog("About to setup recording workflow")
        setupRecordingWorkflow()
        print("Recording workflow setup complete")
        NSLog("Recording workflow setup complete")
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
        NSLog("App state changed to: \(state.displayName)")

        // StatusItemController automatically observes RecordingManager state
        // via Combine, so we don't need to manually update it here
    }

    private func handleRecordingComplete(_ audioURL: URL) {
        print("Recording complete, starting transcription...")
        NSLog("Recording complete, starting transcription...")

        // Update state to transcribing
        RecordingManager.shared.state = .transcribing

        // Run transcription in background
        Task { @MainActor in
            do {
                // Step 1: Transcribe the audio
                let transcribedText = try await GroqTranscriber.shared.transcribe(audioURL)

                print("Transcription successful: \(transcribedText)")
                NSLog("Transcription successful: \(transcribedText)")

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
                statusItemController?.updateHistory(
                    TranscriptionHistoryManager.shared.transcriptions
                )

                print("Created transcription: \(transcription.text)")
                NSLog("Created transcription: \(transcription.text)")

                // Step 5: Return to idle state
                RecordingManager.shared.state = .idle

            } catch {
                print("Transcription failed: \(error.localizedDescription)")
                NSLog("Transcription failed: \(error.localizedDescription)")

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
