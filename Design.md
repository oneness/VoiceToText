# VoiceToText - Design Document

## Overview

A macOS menu bar app for ultra-fast voice-to-text transcription using a single hotkey.

**Core Philosophy:** Speed, accuracy, simplicity.

---

## Features

- **Single hotkey recording** (FN key)
- **Instant transcription** via Groq Whisper API (~500ms)
- **Auto-paste** transcribed text to active input field
- **Paste last** transcription anytime with Cmd+V
- **History** of last 10 transcriptions (menu bar dropdown)
- **Silent operation** (no notifications, no sounds)

---

## User Flow

```
1. Press FN          → Start recording (🔴 icon)
2. Speak...
3. Press FN again    → Stop + transcribe + auto-paste
4. Press Cmd+V       → Paste last transcription again
```

---

## Hotkeys

| Hotkey | Action |
|--------|--------|
| `FN` | Toggle recording (start/stop) |
| `Cmd+V` | Paste last transcribed text |

---

## UI States

| Icon | State | Description |
|------|-------|-------------|
| 🎤 | Idle | Ready to record |
| 🔴 | Recording | Capturing audio (pulsing) |
| ⏳ | Transcribing | Processing audio (spinner) |

---

## Architecture

```
Swift + SwiftUI
│
├── Models/
│   ├── AppState.swift           (idle, recording, transcribing)
│   └── Transcription.swift      (text, timestamp)
│
├── Managers/
│   ├── RecordingManager.swift   (audio capture)
│   ├── GroqTranscriber.swift    (API wrapper)
│   └── TextPaster.swift         (clipboard + Cmd+V sim)
│
├── Hotkeys/
│   └── HotkeyManager.swift      (FN + Cmd+V listener)
│
├── UI/
│   └── StatusItemController.swift (menu bar + history dropdown)
│
└── App/
    └── VoiceToTextApp.swift
```

---

## State Machine

```
IDLE ──FN──> RECORDING ──FN──> TRANSCRIBING ──> AUTO-PASTE ──> IDLE
                                              ↑
                                              │
                            Cmd+V ────────────┘
                            (paste last again)
```

---

## Recording Flow

1. User presses `FN`
2. Menu bar icon turns 🔴 (pulsing)
3. Audio recording starts (AVAudioEngine)
4. User speaks...
5. User presses `FN` again
6. Recording stops → Audio saved to temp file
7. Icon shows ⏳ (spinner)
8. Audio uploaded to Groq Whisper API
9. Text returned (~500ms)
10. Text copied to clipboard
11. Cmd+V simulated (auto-paste into active field)
12. Text saved to buffer (for Cmd+V reuse)
13. Icon returns to 🎤 (idle)

---

## Paste-Last Flow (Cmd+V)

1. User presses `Cmd+V`
2. App checks if transcription buffer has text
3. **Yes:** Paste transcription (override system Cmd+V)
4. **No:** Forward to system Cmd+V (normal paste)

---

## Transcription Service

**Groq Whisper API** (whisper-large-v3)

- **Speed:** ~500ms (fastest available)
- **Accuracy:** State-of-the-art
- **Cost:** ~$0.006/minute
- **Requirement:** Internet connection

### API Endpoint

```
POST https://api.groq.com/openai/v1/audio/transcriptions
```

---

## Text Injection Method

**Clipboard + AppleScript Cmd+V simulation**

```applescript
tell application "System Events"
    keystroke "v" using command down
end tell
```

**Why this approach:**
- Works in every app (including Electron apps)
- Bypasses special character escaping issues
- Instant and reliable

---

## User Setup Instructions

### First-Time Setup

1. **Enable FN key capture:**
   - System Settings → Keyboard
   - Enable "Use F1, F2, etc. as standard function keys"
   - **OR** use Karabiner-Elements to remap FN → F13

2. **Set Groq API Key:**
   ```bash
   export GROQ_API_KEY="your-api-key-here"
   ```

3. **Grant Permissions:**
   - Accessibility (for global hotkeys)
   - Microphone (for audio recording)

---

## File Structure

```
VoiceToText/
├── App/
│   ├── VoiceToTextApp.swift           # Main entry
│   └── AppDelegate.swift              # Lifecycle
├── Models/
│   ├── AppState.swift                 # Recording state enum
│   └── Transcription.swift            # Data model
├── Managers/
│   ├── RecordingManager.swift         # Audio capture logic
│   ├── GroqTranscriber.swift          # API wrapper
│   └── TextPaster.swift               # Paste logic
├── Hotkeys/
│   └── HotkeyManager.swift            # Global hotkey listener
├── UI/
│   ├── StatusItemController.swift     # Menu bar UI
│   └── HistoryMenu.swift              # History dropdown
└── Resources/
    └── WelcomeScreen.swift            # First-time setup guide
```

---

## Core Components

### RecordingManager

```swift
class RecordingManager {
    static let shared = RecordingManager()
    @Published var state: AppState = .idle

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?

    func toggle() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopAndTranscribe()
        default:
            break
        }
    }
}
```

### GroqTranscriber

```swift
class GroqTranscriber {
    static let shared = GroqTranscriber()
    private let apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"]!

    func transcribe(_ audioURL: URL) async throws -> String {
        // Upload to Groq API
        // Return transcribed text
    }
}
```

### TextPaster

```swift
class TextPaster {
    static let shared = TextPaster()

    func paste(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        // Execute AppleScript
    }
}
```

### HotkeyManager

```swift
class HotkeyManager {
    private var lastTranscription: String = ""

    func setup() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // FN key
            if self?.isFNKey(event) == true {
                RecordingManager.shared.toggle()
            }

            // Cmd+V
            if event.keyCode == 9 && event.modifierFlags.contains(.command) {
                if let text = self?.lastTranscription, !text.isEmpty {
                    TextPaster.shared.paste(text)
                    return // Block system Cmd+V
                }
            }
        }
    }
}
```

---

## Data Models

### AppState

```swift
enum AppState {
    case idle
    case recording
    case transcribing
}
```

### Transcription

```swift
struct Transcription: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
}
```

---

## History Storage

- **Storage:** SwiftData (Core Data wrapper)
- **Retention:** Last 10 transcriptions
- **Location:** Menu bar dropdown (click icon)
- **Persistence:** Across app restarts

---

## Technical Requirements

- **Platform:** macOS 14.0+
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Audio:** AVFoundation
- **Data:** SwiftData
- **Permissions:**
  - Accessibility (global hotkeys)
  - Microphone (audio recording)

---

## Dependencies

- **Groq API** (REST API call)
- **No external Swift packages** (keep it native)

---

## Future Enhancements (Post-MVP)

- [ ] iOS version with custom keyboard extension
- [ ] Offline mode (local Whisper via CoreML)
- [ ] Multiple languages
- [ ] Punctuation enhancement
- [ ] Export options
- [ ] Sync via iCloud

---

## Design Principles

1. **Speed first** - Groq API for fastest transcription
2. **Simplicity** - Single hotkey, no settings panel
3. **Invisible** - No notifications, no sounds, no dock icon
4. **Reliable** - Works in every app, native text injection

---

## Success Criteria

- Recording latency: < 50ms
- Transcription speed: < 1s (Groq)
- End-to-end latency: < 2s (press to paste)
- Accuracy: > 95% (Whisper large-v3)
- Memory footprint: < 50MB (menu bar app)

---

## Notes

- FN key requires user setup (function keys mode or Karabiner)
- Cmd+V is overridden only when there's a recent transcription
- App runs as menu bar accessory (no dock icon)
- All history stored locally (no cloud sync yet)
