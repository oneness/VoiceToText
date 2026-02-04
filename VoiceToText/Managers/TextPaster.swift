import Foundation
import Cocoa

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

    init(clipboard: ClipboardManager = DefaultClipboardManager(),
         scriptExecutor: ScriptExecutor = DefaultScriptExecutor()) {
        self.clipboard = clipboard
        self.scriptExecutor = scriptExecutor
    }

    func paste(_ text: String) {
        // 1. Copy text to clipboard
        clipboard.copy(text)

        // 2. Execute AppleScript to simulate Cmd+V
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        try? scriptExecutor.execute(script)
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
