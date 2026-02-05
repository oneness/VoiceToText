import Foundation
import AppKit
import ApplicationServices

// MARK: - Protocol Definitions

protocol SystemEventMonitor {
    func startMonitoring(_ handler: @escaping (NSEvent) -> Void)
    func stopMonitoring()
}

protocol KeyCodeDetector {
    func isFNKey(_ event: NSEvent) -> Bool
    func isCmdV(_ event: NSEvent) -> Bool
    func isOptionSpace(_ event: NSEvent) -> Bool
}

// MARK: - Default Implementations

class DefaultKeyCodeDetector: KeyCodeDetector {
    // FN key detection - supports multiple key codes
    func isFNKey(_ event: NSEvent) -> Bool {
        // Try common key codes for FN/F13-F19
        return event.keyCode == 63  // F13
            || event.keyCode == 64  // F14
            || event.keyCode == 65  // F15
            || event.keyCode == 96  // F16
            || event.keyCode == 97  // F17
            || event.keyCode == 98  // F18
            || event.keyCode == 99  // F19
            || event.keyCode == 100 // F20
    }

    // Cmd+V detection (key code 9 with Command modifier)
    func isCmdV(_ event: NSEvent) -> Bool {
        return event.keyCode == 9 && event.modifierFlags.contains(.command)
    }

    // Option+Space detection (key code 49 with Option modifier)
    func isOptionSpace(_ event: NSEvent) -> Bool {
        return event.keyCode == 49 && event.modifierFlags.contains(.option)
    }
}

class NSEventMonitor: SystemEventMonitor {
    private var monitor: AnyObject?

    func startMonitoring(_ handler: @escaping (NSEvent) -> Void) {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler) as AnyObject
    }

    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - HotkeyManager

class HotkeyManager {
    static let shared = HotkeyManager()

    private var lastTranscription: String = ""
    private var eventMonitor: SystemEventMonitor
    private let keyCodeDetector: KeyCodeDetector

    // For testing - allows dependency injection
    init(eventMonitor: SystemEventMonitor = NSEventMonitor(),
         keyCodeDetector: KeyCodeDetector = DefaultKeyCodeDetector()) {
        self.eventMonitor = eventMonitor
        self.keyCodeDetector = keyCodeDetector
    }

    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        print("=== Accessibility Permission Check: \(accessEnabled ? "GRANTED" : "DENIED") ===")
        NSLog("=== Accessibility Permission Check: %@ ===", accessEnabled ? "GRANTED" : "DENIED")

        if !accessEnabled {
            print("WARNING: Accessibility permission not granted")
            NSLog("WARNING: Accessibility permission not granted")

            // Show alert to user
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = "VoiceToText needs accessibility access to respond to global hotkeys (Option+Space).\n\nPlease grant permission in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            print("Accessibility permission granted")
            NSLog("Accessibility permission granted")
        }

        return accessEnabled
    }

    func setup() {
        print("DEBUG: HotkeyManager.setup() called - checking accessibility permission")
        NSLog("DEBUG: HotkeyManager.setup() called - checking accessibility permission")

        // Check accessibility permission first
        guard checkAccessibilityPermission() else {
            print("WARNING: Cannot start hotkey monitoring without accessibility permission")
            NSLog("WARNING: Cannot start hotkey monitoring without accessibility permission")
            return
        }

        print("DEBUG: Starting global key event monitoring")
        NSLog("DEBUG: Starting global key event monitoring")

        // Start global key event monitoring
        eventMonitor.startMonitoring { [weak self] event in
            print("DEBUG: Event received! keyCode: \(event.keyCode)")
            NSLog("DEBUG: Event received! keyCode: %d", event.keyCode)
            self?.handleEvent(event)
        }

        print("DEBUG: Global monitoring started")
        NSLog("DEBUG: Global monitoring started")
    }

    private func handleEvent(_ event: NSEvent) {
        // Debug: log all key events to find FN key code
        print("DEBUG: Key pressed - keyCode: \(event.keyCode), modifiers: \(event.modifierFlags.rawValue)")
        NSLog("DEBUG: Key pressed - keyCode: %d, modifiers: %lu", event.keyCode, event.modifierFlags.rawValue)

        // Option+Space (primary hotkey)
        if keyCodeDetector.isOptionSpace(event) {
            print("DEBUG: Option+Space detected! Toggling recording")
            NSLog("DEBUG: Option+Space detected! Toggling recording")
            RecordingManager.shared.toggle()
            return
        }

        // FN key (support F13-F20 key codes) - for keyboards with dedicated F-keys
        if keyCodeDetector.isFNKey(event) {
            print("DEBUG: FN/F-key detected! Toggling recording")
            NSLog("DEBUG: FN/F-key detected! Toggling recording")
            RecordingManager.shared.toggle()
            return
        }

        // Cmd+V (key code 9)
        if keyCodeDetector.isCmdV(event) {
            print("DEBUG: Cmd+V detected, pasting last transcription")
            NSLog("DEBUG: Cmd+V detected, pasting last transcription")
            if !lastTranscription.isEmpty {
                TextPaster.shared.paste(lastTranscription)
                return // Block system Cmd+V
            }
            // Otherwise let system Cmd+V through
        }
    }

    func setLastTranscription(_ text: String) {
        lastTranscription = text
    }

    func stopMonitoring() {
        eventMonitor.stopMonitoring()
    }
}
