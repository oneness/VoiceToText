# VoiceToText

VoiceToText is a macOS menu bar app that records your voice, transcribes it with Groq Whisper, and auto-pastes the result into the active app.

## Quick Start

### 1. Prerequisites
- macOS 14+
- Xcode 15+
- A Groq API key: https://console.groq.com/keys

### 2. Configure your Groq API key
Use one of these methods.

Option A: environment variable (best when launching from Terminal)
```bash
export GROQ_API_KEY="your-groq-api-key"
```

Option B: config file (works for Finder/Xcode launches too)
```bash
mkdir -p ~/Library/Application\ Support/VoiceToText
cat > ~/Library/Application\ Support/VoiceToText/config.json <<'JSON'
{"groq_api_key":"your-groq-api-key"}
JSON
```

Optional override for custom config location:
```bash
export VOICETOTEXT_CONFIG_PATH="/absolute/path/to/config.json"
```

### 3. Build and run
```bash
make compile
make run
```

Or do a full local validation (clean + build + test + codesign + open Accessibility settings):
```bash
make build
```

## Required macOS Permissions

### Accessibility (required for global hotkey + auto-paste)
1. Open `System Settings`.
2. Go to `Privacy & Security` -> `Accessibility`.
3. Enable `VoiceToText`.
4. If `VoiceToText` is not listed, click `+` and add the built app (`VoiceToText.app`), then enable it.

Shortcut command to open the Accessibility panel directly:
```bash
make access
```

### Microphone (required for recording)
1. Open `System Settings`.
2. Go to `Privacy & Security` -> `Microphone`.
3. Enable `VoiceToText`.

## Usage
- Press `Option + Space` to start recording.
- Press `Option + Space` again to stop recording and transcribe.
- The transcribed text is copied to clipboard and pasted automatically.
- Click the menu bar icon to start/stop recording or quit.

## Common Commands
```bash
make help      # list targets
make compile   # build app
make test      # run tests
make run       # open built app
make access    # open Accessibility settings
```

## Repository Docs
- Current docs: `docs/`
