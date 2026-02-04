import Foundation
import Cocoa

class TextPaster {

    func pasteText(_ text: String) {
        // TODO: Implement text pasting at cursor position
        print("Pasting text: \(text)")
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
