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
            throw NSError(domain: "ScriptExecutor", code: 1, userInfo: error as? [String: Any])
        }
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

        // 4. Try automatic paste (will likely fail without proper code signing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.attemptAutoPaste()
        }
    }

    private func attemptAutoPaste() {
        os_log("Attempting auto-paste via System Events", log: logger, type: .info)

        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """

        do {
            try scriptExecutor.execute(script)
            os_log("Auto-paste successful!", log: logger, type: .info)
        } catch {
            os_log("Auto-paste failed (expected without code signing): %{public}@", log: logger, type: .error, error.localizedDescription)
            // User needs to press Cmd+V manually
        }
    }

    private func showNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                os_log("Notification authorization failed: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Transcription Ready"
            content.body = "Press Cmd+V to paste your transcribed text"
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
