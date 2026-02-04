import Foundation
import AppKit

// MARK: - Protocol Definitions

protocol SystemEventMonitor {
    func startMonitoring(_ handler: @escaping (NSEvent) -> Void)
    func stopMonitoring()
}

protocol KeyCodeDetector {
    func isFNKey(_ event: NSEvent) -> Bool
    func isCmdV(_ event: NSEvent) -> Bool
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

    func setup() {
        print("DEBUG: HotkeyManager.setup() called - starting global monitoring")
        NSLog("DEBUG: HotkeyManager.setup() called - starting global monitoring")

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

        // FN key (support F13-F20 key codes)
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
