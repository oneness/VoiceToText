import Cocoa
import Combine

// MARK: - Protocol Abstractions for Testability

protocol MenuBarItemProtocol {
    var title: String { get set }
    var menu: NSMenu? { get set }
}

extension NSStatusItem: MenuBarItemProtocol {
    var title: String {
        get { return button?.title ?? "" }
        set { button?.title = newValue }
    }
}

protocol StatusItemFactoryProtocol {
    func createStatusItem() -> MenuBarItemProtocol
}

class DefaultStatusItemFactory: StatusItemFactoryProtocol {
    func createStatusItem() -> MenuBarItemProtocol {
        return NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
}

// MARK: - StatusItemController

class StatusItemController: ObservableObject {
    static let shared = StatusItemController()

    private var statusItem: MenuBarItemProtocol
    private let statusItemFactory: StatusItemFactoryProtocol
    private let recordingManager: RecordingManager
    private var cancellables = Set<AnyCancellable>()

    // Test-friendly initializer
    init(
        statusItemFactory: StatusItemFactoryProtocol = DefaultStatusItemFactory(),
        recordingManager: RecordingManager = .shared
    ) {
        self.statusItemFactory = statusItemFactory
        self.recordingManager = recordingManager
        self.statusItem = statusItemFactory.createStatusItem()
        // Don't call setup() here - let the caller call it explicitly
    }

    func setup() {
        // Initial icon
        statusItem.title = "🎤"

        // Setup menu
        let menu = NSMenu()

        // Add section header
        menu.addItem(NSMenuItem.sectionHeader(title: "History"))
        menu.addItem(NSMenuItem.separator())

        // Add quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Observe RecordingManager state changes
        recordingManager.$state
            .sink { [weak self] state in
                self?.setState(state)
            }
            .store(in: &cancellables)
    }

    func setState(_ state: AppState) {
        switch state {
        case .idle:
            statusItem.title = "🎤"
        case .recording:
            statusItem.title = "🔴"
        case .transcribing:
            statusItem.title = "⏳"
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
            item.isEnabled = false // Make text non-clickable
            menu.addItem(item)
        }

        // Add separator and quit item
        menu.addItem(NSMenuItem.separator())

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
