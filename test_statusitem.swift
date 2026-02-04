import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: 60)

        // Try to set title
        if let button = statusItem?.button {
            button.title = "TEST"
            print("Status item button created successfully")
        } else {
            print("Status item button is nil")
        }

        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu

        print("App started, status item should be visible")
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
