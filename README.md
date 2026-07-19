# VoiceToText

Press a hotkey, speak, and the text appears where you're typing. Works on macOS and Linux. No window, no clicks.

## Quick links

- **[Overview](https://www.birkey.co/VoiceToText/)** — what it is and how it works (space-bar to navigate)
- **[Architecture](docs/architecture.md)** — internals for both platforms

## Quick Start

### 1. Prerequisites
- macOS 14+
- Xcode 15+
- A Groq API key: https://console.groq.com/keys

### 2. Configure your Groq API key
Use one of these methods.

Option A (recommended): interactive setup (works for Finder/Xcode/Terminal launches)
```bash
make setup
```

Option B: environment variable (best when launching from Terminal)
```bash
export GROQ_API_KEY="your-groq-api-key"
```

Option C: config file (works for Finder/Xcode launches too)
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
make setup     # prompt for API key and save config
make compile   # build app
make test      # run tests
make run       # open built app
make access    # open Accessibility settings
```

## Linux

See [linux/README.md](linux/README.md) for the full Linux setup guide.

## Linux Config Path

The Linux implementation uses XDG config resolution.

- Default config file: `~/.config/voicetotext/config.json`
- Override: `VOICETOTEXT_CONFIG_PATH=/absolute/path/to/config.json`

On Linux, no config file is needed: local on-device transcription (via
transcribe.cpp) is the default, and the model downloads automatically on
first run — see [linux/README.md](linux/README.md).

To use the Groq cloud backend instead:

```bash
mkdir -p ~/.config/voicetotext
cat > ~/.config/voicetotext/config.json <<'JSON'
{"backend":"groq","groq_api_key":"your-groq-api-key"}
JSON
```

## Contributing

This project is personal software that I maintain for my own use. I do not accept pull requests.

If it's useful to you: fork it, copy the code, adapt it freely. The only ask is that you keep the copyright notice intact (MIT license).

## License

MIT — see [LICENSE](LICENSE).
