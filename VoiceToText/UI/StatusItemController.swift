import Cocoa
import Combine
import os.log
import AppKit

class StatusItemController: ObservableObject {
    // REMOVED SINGLETON - causing issues
    // static let shared = StatusItemController()

    private let statusItem: NSStatusItem
    private let recordingManager: RecordingManager
    private var cancellables = Set<AnyCancellable>()
    private let logger = OSLog(subsystem: "com.voicetext.app", category: "StatusItemController")

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

        // Set initial icon - use SF Symbol
        if let button = statusItem.button {
            button.image = icon(named: "mic.circle.fill")

            // Fallback to emoji if SF Symbol not available
            if button.image == nil {
                button.title = "🎤"
            }

            print("DEBUG: Set status item button icon")
            NSLog("DEBUG: Set status item button icon")

            // Make the button clickable to toggle recording
            button.action = #selector(toggleRecording)
            button.target = self
            button.sendAction(on: .leftMouseDown)
        } else {
            print("ERROR: Status item button is nil!")
            NSLog("ERROR: Status item button is nil!")
        }

        // Create menu
        let menu = NSMenu()

        // Add start/stop recording menu item at the top
        // Note: ⌥+Space is handled by HotkeyManager (global hotkey), not menu keyEquivalent
        let toggleItem = NSMenuItem(title: "▶️ Start Recording (⌥ Space)", action: #selector(toggleRecording), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Add journal section
        let openJournalItem = NSMenuItem(title: "📖 Open Journal", action: #selector(openJournal), keyEquivalent: "j")
        openJournalItem.target = self
        menu.addItem(openJournalItem)

        let openJournalFolderItem = NSMenuItem(title: "📁 Open Journal Folder", action: #selector(openJournalFolder), keyEquivalent: "")
        openJournalFolderItem.target = self
        menu.addItem(openJournalFolderItem)

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

    // MARK: - Icon Helpers

    private func icon(named iconName: String) -> NSImage? {
        // Standard menu bar icon height is 22px (fills the menu bar)
        // Use large scale for sharpness on Retina displays
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular, scale: .large)

        guard let image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config) else {
            return nil
        }

        image.isTemplate = true  // Makes it adapt to light/dark mode

        // Create a new image sized to the full menu bar height (22px)
        // This ensures the icon fills the entire available space
        let finalSize = NSSize(width: 22, height: 22)
        let resizedImage = NSImage(size: finalSize)

        resizedImage.lockFocus()
        image.draw(
            in: NSRect(
                origin: .zero,
                size: finalSize
            ),
            from: NSRect(
                origin: .zero,
                size: image.size
            ),
            operation: NSCompositingOperation.copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()

        return resizedImage
    }

    func setState(_ state: AppState) {
        print("DEBUG: setState called with: \(state.displayName)")

        if let button = statusItem.button {
            // Use SF Symbols for cleaner, native macOS look
            switch state {
            case .idle:
                button.image = icon(named: "mic.circle.fill")
            case .recording:
                button.image = icon(named: "record.circle.fill")
            case .transcribing:
                button.image = icon(named: "waveform.circle.fill")
            }

            // Fallback to emojis if SF Symbols not available
            if button.image == nil {
                switch state {
                case .idle:
                    button.title = "🎤"
                case .recording:
                    button.title = "🔴"
                case .transcribing:
                    button.title = "⏳"
                }
            } else {
                button.title = ""  // Clear emoji when using image
            }

            print("DEBUG: Button updated for state: \(state.displayName)")
        }

        // Update menu item text
        guard let menu = statusItem.menu,
              let toggleItem = menu.items.first else { return }

        switch state {
        case .idle:
            toggleItem.title = "▶️ Start Recording (⌥ Space)"
        case .recording:
            toggleItem.title = "⏹ Stop Recording (⌥ Space)"
        case .transcribing:
            toggleItem.title = "⏳ Transcribing..."
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func toggleRecording() {
        os_log("Menu bar icon clicked - toggling recording", log: logger, type: .info)
        RecordingManager.shared.toggle()
    }

    @objc private func openJournal() {
        os_log("Opening today's journal", log: logger, type: .info)
        TranscriptionJournal.shared.openTodayJournal()
    }

    @objc private func openJournalFolder() {
        os_log("Opening journal folder", log: logger, type: .info)
        TranscriptionJournal.shared.openJournalFolder()
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
