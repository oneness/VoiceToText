# VoiceToText

A macOS menu bar application for voice-to-text transcription using Groq API.

## Project Structure

```
VoiceToText/
├── VoiceToText/
│   ├── App/
│   │   ├── VoiceToTextApp.swift      # Main entry point
│   │   └── AppDelegate.swift          # NSApplicationDelegate
│   ├── Models/
│   │   ├── AppState.swift             # App state enum (idle, recording, transcribing)
│   │   └── Transcription.swift        # Transcription data model
│   ├── Managers/
│   │   ├── RecordingManager.swift     # Audio recording manager
│   │   ├── GroqTranscriber.swift      # Groq API integration
│   │   └── TextPaster.swift           # Text pasting functionality
│   ├── Hotkeys/
│   │   └── HotkeyManager.swift        # Global hotkey handling
│   ├── UI/
│   │   └── StatusItemController.swift # Menu bar UI controller
│   ├── Resources/
│   │   └── Info.plist                 # App metadata and permissions
│   └── VoiceToText.entitlements       # App sandbox entitlements
├── VoiceToTextTests/
│   └── VoiceToTextTests.swift         # Swift Testing tests
└── VoiceToText.xcodeproj/             # Xcode project
```

## Building the Project

### Prerequisites
- macOS 14.0+
- Xcode 15.0+

### Build from Command Line
```bash
cd ~/repos/VoiceToText
xcodebuild -project VoiceToText.xcodeproj -scheme VoiceToText -configuration Debug build
```

### Build and Run Tests
```bash
xcodebuild test -project VoiceToText.xcodeproj -scheme VoiceToText -destination 'platform=macOS'
```

### Open in Xcode
```bash
open ~/repos/VoiceToText/VoiceToText.xcodeproj
```

Then press Cmd+R to build and run.

## Permissions

The app requires the following permissions:
- **Microphone**: For recording audio
- **Accessibility**: For global hotkeys and text pasting
- **Network Client**: For communicating with Groq API

These permissions are requested when the app first runs.

## Configuration

You can provide your Groq API key in either of these ways:

1. Environment variable (good for Terminal launches):
```bash
export GROQ_API_KEY="your-api-key-here"
```

2. Config file (works for Finder launches):
```bash
mkdir -p ~/Library/Application\ Support/VoiceToText
cat > ~/Library/Application\ Support/VoiceToText/config.json <<'JSON'
{"groq_api_key":"your-api-key-here"}
JSON
```

Optional: set `VOICETOTEXT_CONFIG_PATH` to point to a custom config file path.

## Current Status

This is the initial project setup with placeholder implementations. Core features are stubbed out and ready for implementation.

### TODO
- [ ] Implement audio recording in RecordingManager
- [ ] Implement Groq API transcription in GroqTranscriber
- [ ] Implement global hotkey registration in HotkeyManager
- [ ] Implement text pasting in TextPaster
- [ ] Wire up all components in AppDelegate
- [ ] Add comprehensive tests
- [ ] Create settings UI
- [ ] Add error handling and user feedback

## License

MIT License - See LICENSE file for details
