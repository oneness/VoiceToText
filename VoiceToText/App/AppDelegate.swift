import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItemController: StatusItemController?
    var hotkeyManager: HotkeyManager?
    var recordingManager: RecordingManager?
    var groqTranscriber: GroqTranscriber?
    var textPaster: TextPaster?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize managers
        statusItemController = StatusItemController()
        hotkeyManager = HotkeyManager()
        recordingManager = RecordingManager()
        groqTranscriber = GroqTranscriber()
        textPaster = TextPaster()

        // Setup UI
        statusItemController?.setupMenu()

        print("VoiceToText app started successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
