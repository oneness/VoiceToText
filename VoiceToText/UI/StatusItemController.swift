import Cocoa
import Combine

class StatusItemController: ObservableObject {
    // REMOVED SINGLETON - causing issues
    // static let shared = StatusItemController()

    private let statusItem: NSStatusItem
    private let recordingManager: RecordingManager
    private var cancellables = Set<AnyCancellable>()

    init(recordingManager: RecordingManager = .shared) {
        print("DEBUG: StatusItemController init() called - THIS PROVES INIT IS RUNNING")
        NSLog("DEBUG: StatusItemController init() called - THIS PROVES INIT IS RUNNING")
        self.recordingManager = recordingManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("DEBUG: Created NSStatusItem")
        NSLog("DEBUG: Created NSStatusItem")
        setup()
        print("DEBUG: setup() completed")
        NSLog("DEBUG: setup() completed")
    }

    private func setup() {
        print("DEBUG: StatusItemController setup() called")
        NSLog("DEBUG: StatusItemController setup() called")

        // Set initial icon - try text first
        if let button = statusItem.button {
            button.title = "VT"
            print("DEBUG: Set status item button title to VT")
            NSLog("DEBUG: Set status item button title to VT")
        } else {
            print("ERROR: Status item button is nil!")
            NSLog("ERROR: Status item button is nil!")
        }

        // Create menu
        let menu = NSMenu()

        // Add section header
        menu.addItem(NSMenuItem.sectionHeader(title: "History"))
        menu.addItem(NSMenuItem.separator())

        // Add quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        print("DEBUG: Menu set up complete")

        // Observe RecordingManager state changes
        recordingManager.$state
            .sink { [weak self] state in
                self?.setState(state)
            }
            .store(in: &cancellables)

        print("DEBUG: State observation set up")
    }

    func setState(_ state: AppState) {
        print("DEBUG: setState called with: \(state.displayName)")

        if let button = statusItem.button {
            switch state {
            case .idle:
                button.title = "VT"
            case .recording:
                button.title = "●"
            case .transcribing:
                button.title = "⏳"
            }
            print("DEBUG: Button title updated to: \(button.title)")
        }
    }

    func updateHistory(_ transcriptions: [Transcription]) {
        guard let menu = statusItem.menu else { return }

        // Remove all existing items
        menu.removeAllItems()

        // Add section header
        menu.addItem(NSMenuItem.sectionHeader(title: "History"))
        menu.addItem(NSMenuItem.separator())

        // Add last 10 transcriptions (most recent first)
        let recentTranscriptions = Array(transcriptions.suffix(10).reversed())

        for transcription in recentTranscriptions {
            let item = NSMenuItem(title: transcription.text, action: nil, keyEquivalent: "")
            menu.addItem(item)
        }

        if !transcriptions.isEmpty {
            menu.addItem(NSMenuItem.separator())
        }

        // Add quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuItem Extension for Section Headers

extension NSMenuItem {
    static func sectionHeader(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
