import Cocoa

@main
struct SimpleMenuBarApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("DEBUG: App did finish launching")

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        print("DEBUG: Status item created: \(statusItem != nil)")

        // Set title
        if let button = statusItem?.button {
            button.title = "🎤"
            print("DEBUG: Button title set to 🎤")
        } else {
            print("ERROR: Button is nil!")
        }

        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Test", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu

        print("DEBUG: Setup complete")
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
