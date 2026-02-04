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
    // FN key detection - requires Karabiner-Elements remapping to F13 (key code 63)
    func isFNKey(_ event: NSEvent) -> Bool {
        return event.keyCode == 63 // F13, remapped from FN key
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
        // Start global key event monitoring
        eventMonitor.startMonitoring { [weak self] event in
            self?.handleEvent(event)
        }
    }

    private func handleEvent(_ event: NSEvent) {
        // FN key (key code 63 = F13, remapped from FN)
        if keyCodeDetector.isFNKey(event) {
            RecordingManager.shared.toggle()
            return
        }

        // Cmd+V (key code 9)
        if keyCodeDetector.isCmdV(event) {
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
