#!/usr/bin/env swift

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

// MARK: - TextPaster Implementation
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
        clipboard.copy(text)

        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        try? scriptExecutor.execute(script)
    }

    func pasteText(_ text: String) {
        paste(text)
    }

    func copyToClipboard(_ text: String) {
        clipboard.copy(text)
    }
}

// MARK: - Mock Implementations for Testing
class MockClipboard: ClipboardManager {
    var contents = ""
    func copy(_ text: String) { contents = text }
    func getContents() -> String { return contents }
}

class MockScript: ScriptExecutor {
    var executed = false
    var lastScript = ""
    func execute(_ script: String) throws {
        executed = true
        lastScript = script
    }
}

// MARK: - Tests
print("Testing TextPaster Implementation...")
print("=====================================\n")

// Test 1: Verify protocol definitions compile
print("✓ Test 1: Protocol definitions compile successfully")

// Test 2: Verify TextPaster can be instantiated
let mockClip = MockClipboard()
let mockScript = MockScript()
let paster = TextPaster(clipboard: mockClip, scriptExecutor: mockScript)
print("✓ Test 2: TextPaster can be initialized with dependencies")

// Test 3: Verify paste() copies to clipboard
paster.paste("Hello, World!")
if mockClip.getContents() == "Hello, World!" {
    print("✓ Test 3: paste() copies text to clipboard")
} else {
    print("✗ Test 3 FAILED: Text not copied to clipboard")
    exit(1)
}

// Test 4: Verify paste() executes AppleScript
if mockScript.executed && mockScript.lastScript.contains("keystroke") {
    print("✓ Test 4: paste() executes AppleScript with keystroke command")
} else {
    print("✗ Test 4 FAILED: AppleScript not executed correctly")
    exit(1)
}

// Test 5: Verify empty text is handled
paster.paste("")
if mockClip.getContents() == "" {
    print("✓ Test 5: Empty text is handled gracefully")
} else {
    print("✗ Test 5 FAILED: Empty text not handled correctly")
    exit(1)
}

// Test 6: Verify multiline text works
let multiline = "Line 1\nLine 2\nLine 3"
paster.paste(multiline)
if mockClip.getContents() == multiline {
    print("✓ Test 6: Multiline text is handled correctly")
} else {
    print("✗ Test 6 FAILED: Multiline text not handled correctly")
    exit(1)
}

print("\n=====================================")
print("All TextPaster tests passed! ✓")
print("=====================================")
