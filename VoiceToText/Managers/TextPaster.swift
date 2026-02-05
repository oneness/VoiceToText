import Foundation
import Cocoa
import os.log
import UserNotifications
import ApplicationServices

// MARK: - Protocol Definitions

protocol ScriptExecutor {
    func execute(_ script: String) throws
}

protocol ClipboardManager {
    func copy(_ text: String)
    func getContents() -> String
}

// MARK: - Default Implementations

class DefaultScriptExecutor: ScriptExecutor {
    func execute(_ script: String) throws {
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        _ = appleScript?.executeAndReturnError(&errorDict)

        if let error = errorDict {
            print("AppleScript error: \(error)")
            NSLog("AppleScript error: %@", error)
            throw NSError(domain: "ScriptExecutor", code: 1, userInfo: error as? [String: Any])
        }

        print("AppleScript executed successfully")
        NSLog("AppleScript executed successfully")
    }
}

class DefaultClipboardManager: ClipboardManager {
    private let pasteboard = NSPasteboard.general

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func getContents() -> String {
        return pasteboard.string(forType: .string) ?? ""
    }
}

// MARK: - TextPaster

class TextPaster {
    static let shared = TextPaster()

    private let clipboard: ClipboardManager
    private let scriptExecutor: ScriptExecutor
    private let logger = OSLog(subsystem: "com.voicetext.app", category: "TextPaster")

    init(clipboard: ClipboardManager = DefaultClipboardManager(),
         scriptExecutor: ScriptExecutor = DefaultScriptExecutor()) {
        self.clipboard = clipboard
        self.scriptExecutor = scriptExecutor
    }

    func paste(_ text: String) {
        os_log("paste() called with text length: %d", log: logger, type: .info, text.count)

        // 1. Copy text to clipboard
        clipboard.copy(text)
        os_log("Text copied to clipboard", log: logger, type: .info)

        // 2. Play sound to alert user
        NSSound.beep()
        os_log("Beep played", log: logger, type: .info)

        // 3. Show notification
        showNotification()

        // Note: Auto-pasting via AppleScript/CGEvent requires Automation permission
        // which is difficult to set up programmatically. User presses Cmd+V manually.
    }

    private func showNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                os_log("Notification authorization failed: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "✅ Transcription Complete!"
            content.body = "Text ready! Press ⌘V to paste."
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

            center.add(request) { error in
                if let error = error {
                    os_log("Failed to show notification: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                } else {
                    os_log("Notification shown to user", log: self.logger, type: .info)
                }
            }
        }
    }

    // Legacy method for backward compatibility
    func pasteText(_ text: String) {
        paste(text)
    }

    // Legacy method for backward compatibility
    func copyToClipboard(_ text: String) {
        clipboard.copy(text)
    }
}
