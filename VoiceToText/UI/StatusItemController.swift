import Cocoa

class StatusItemController {
    private var statusItem: NSStatusItem?
    private var statusBarMenu: NSMenu?

    func setupMenu() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "🎤"
            button.toolTip = "VoiceToText"
        }

        setupMenuItems()
    }

    private func setupMenuItems() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusBarMenu = menu
    }

    @objc private func startRecording() {
        print("Start recording menu item clicked")
        // TODO: Trigger recording start
    }

    @objc private func stopRecording() {
        print("Stop recording menu item clicked")
        // TODO: Trigger recording stop
    }

    @objc private func openSettings() {
        print("Open settings menu item clicked")
        // TODO: Open settings window
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func updateStatus(_ state: AppState) {
        DispatchQueue.main.async {
            if let button = self.statusItem?.button {
                switch state {
                case .idle:
                    button.title = "🎤"
                case .recording:
                    button.title = "🔴"
                case .transcribing:
                    button.title = "⏳"
                }
            }
        }
    }
}
