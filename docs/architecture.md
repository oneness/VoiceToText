# VoiceToText architecture

## Overview

VoiceToText is a global-hotkey dictation utility that runs as an invisible system tray / menu bar app. It has two independent implementations sharing the same user-facing behaviour:

- **macOS** — Swift + AppKit, built with Xcode
- **Linux** — Rust, targets PipeWire + GNOME Wayland

Both implementations follow the same pipeline: hotkey press → audio capture → Groq Whisper transcription → clipboard → auto-paste → journal append.

---

## The pipeline

```
hotkey press
    │
    ▼
audio capture (AVAudioRecorder / pw-record + ffmpeg)
    │
    ▼
Groq Whisper API  (whisper-large-v3-turbo)
    │
    ▼
clipboard + auto-paste  (CGEvent Cmd+V / XDG RemoteDesktop Ctrl+Y)
    │
    ▼
journal append  (~/Documents/VoiceToText/YYYY-MM-DD.md)
```

Second hotkey press stops recording and triggers the rest of the pipeline. The app never opens a window during normal use.

---

## macOS implementation (Swift)

### Entry point

`VoiceToText/main.swift` creates `NSApplication` and sets `AppDelegate` as delegate.
`VoiceToText/App/VoiceToTextApp.swift` (`AppDelegate`) wires everything up in `applicationDidFinishLaunching`:

1. Creates `StatusItemController` (menu bar icon)
2. Calls `HotkeyManager.shared.setup()`
3. Calls `setupRecordingWorkflow()` — observes `RecordingManager.shared.$state` via Combine and sets `onRecordingComplete` callback

### Key components

| File | Role |
|------|------|
| `UI/StatusItemController.swift` | Menu bar icon — draws a microphone glyph via `NSBezierPath`, shows state badges (red dot = recording, grey pill = transcribing) |
| `Hotkeys/HotkeyManager.swift` | `NSEvent.addGlobalMonitorForEvents(.keyDown)` — detects `Option+Space`, calls `RecordingManager.shared.toggle()` |
| `Managers/RecordingManager.swift` | `AVAudioRecorder` → `.m4a` at 16 kHz mono AAC; fires `onRecordingComplete(url)` after a 500 ms settle delay |
| `Managers/GroqTranscriber.swift` | Multipart POST to Groq API via `URLSession`; 30-second timeout via `withThrowingTaskGroup` |
| `Managers/AutoPaster.swift` | Copies to `NSPasteboard`, then synthesises `Cmd+V` via `CGEvent` on `cghidEventTap` |
| `Managers/TranscriptionJournal.swift` | Appends to `~/Documents/VoiceToText/YYYY-MM-DD.md` with `## HH:MM` headers |
| `Managers/HTTPClient.swift` | `URLSession` wrapper; maps 401 → `authenticationFailed`, other non-200 → `networkError` |
| `Models/AppState.swift` | `enum AppState { idle, recording, transcribing }` |
| `Models/TranscriptionError.swift` | Typed errors: `networkError`, `timeout`, `authenticationFailed`, `fileNotFound`, … |

### Hotkey

Uses `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` — requires Accessibility permission. Intercepts `Option+Space` (keyCode 49 + `.option` modifier). `Cmd+V` is deliberately not intercepted to avoid an infinite loop with the auto-paster.

### Audio recording

`AVAudioRecorder` writes to `/tmp/recording_<timestamp>.m4a`. Settings: `kAudioFormatMPEG4AAC`, 16 kHz, mono, medium quality — tuned to Whisper's native sample rate to minimise upload size.

### Transcription

`GroqTranscriber` builds a `multipart/form-data` POST to `https://api.groq.com/openai/v1/audio/transcriptions` with model `whisper-large-v3-turbo`. The call races against a 30-second `Task.sleep` timeout so the app never hangs in `.transcribing` state.

### Auto-paste

`AutoPaster` copies the transcript to `NSPasteboard`, then synthesises `Cmd+V` using `CGEvent(keyboardEventSource:virtualKey:keyDown:)` posted via `.cghidEventTap`. Requires Accessibility permission.

### Dependency injection

`HotkeyManager` accepts `SystemEventMonitor` and `KeyCodeDetector` protocols; `GroqTranscriber` accepts `HTTPClient`. This allows full unit test coverage without system access.

---

## Linux implementation (Rust)

The crate at `linux/` is both a binary and a library (`lib.rs` re-exports everything for testability).

### Entry point

`linux/src/main.rs` dispatches four CLI modes:

- `voicetotext <audio-file>` — transcribe an existing file
- `voicetotext record [seconds]` — record for N seconds, then transcribe
- `voicetotext daemon` — start the tray + hotkey daemon (normal use)
- `voicetotext sources` — list PipeWire audio sources

### Module map

| Module | Role |
|--------|------|
| `state.rs` | `enum AppState { Idle, Recording, Transcribing }` |
| `config.rs` | API key resolution (env var → XDG config file); `resolve_config_path()` respects `XDG_CONFIG_HOME` and `VOICETOTEXT_CONFIG_PATH` |
| `groq.rs` | Pure request builder and response parser — no I/O; validates 25 MB upload cap |
| `transport.rs` | `reqwest::blocking` HTTP execution; maps non-2xx to `TransportError` |
| `recorder.rs` | `pw-record` piped into `ffmpeg` → Opus/OGG at 16 kbps; SIGINT to stop; `list_audio_sources()` via `wpctl` |
| `hotkey_daemon.rs` | Core async event loop: XDG GlobalShortcuts portal (+ auto-configured GNOME custom shortcut fallback) → `toggle_recording()` → full pipeline |
| `autopaste.rs` | XDG RemoteDesktop portal → Ctrl+Y keysym injection (GNOME Wayland); restore token persisted to `~/.local/state/voicetotext/` |
| `tray_app.rs` | `ksni` StatusNotifierItem tray; bridges events between tray and daemon via channels |
| `platform.rs` | Clipboard (`wl-copy` / `xclip` / `xsel`), sound (`pw-play`), journal write, icon install |
| `desktop.rs` | `probe_desktop_capabilities()` — checks GlobalShortcuts portal via `gdbus introspect` |
| `journal.rs` | Pure rendering: `render_journal_entry()` produces identical Markdown format to macOS |

### Hotkey

`ashpd` GlobalShortcuts portal (`org.freedesktop.portal.GlobalShortcuts`) — the modern sandboxed approach for GNOME Wayland. Binds `"toggle-recording"` with preferred trigger `Alt+Space`. Requires `xdg-desktop-portal-gnome`.

On GNOME 50, `gnome-control-center-global-shortcuts-provider` segfaults when `bind_shortcuts` tries to show its key-binding dialog without a parent window, so the portal bind reliably fails there. The daemon treats this as non-fatal and falls back to a GNOME custom keyboard shortcut (`<Alt>space` → writes `toggle` to a control FIFO at `/run/user/$UID/voicetotext-control`), which it registers itself via `gsettings` on every startup (`ensure_gnome_custom_shortcut()` in `hotkey_daemon.rs`) — no separate setup script or manual dconf edit required. If GNOME ever fixes the crash, the portal path is used automatically without any code change.

### Audio recording

`PwRecordRecorder` launches two child processes: `pw-record` (raw 16 kHz mono PCM to stdout) piped into `ffmpeg` (encodes to Opus/OGG at 16 kbps, `voip` application profile). Outputs to `/tmp/voicetotext-recording-<nanoseconds>.ogg`. Stop sends SIGINT to `pw-record` via `libc::kill`, then waits for both processes to exit.

### Transcription

Same Groq API and model as macOS. `build_groq_transcription_request()` in `groq.rs` is pure (no I/O) and fully unit-tested. `execute_http_request()` in `transport.rs` uses `reqwest::blocking` inside `tokio::task::spawn_blocking`.

### Auto-paste

`AutoPasteController` probes `XDG_SESSION_TYPE` and `XDG_CURRENT_DESKTOP` at construction time:

- **GNOME Wayland** → XDG RemoteDesktop portal; injects `Ctrl_L` + `Y` keysyms (60 ms settle before injection). A restore token is saved to `~/.local/state/voicetotext/autopaste-restore-token` to skip re-prompting across sessions.
- **Anything else** → graceful no-op; transcript is on the clipboard, auto-paste is skipped.

### Key dependencies

| Crate | Purpose |
|-------|---------|
| `ashpd 0.12` | XDG portal bindings (GlobalShortcuts + RemoteDesktop) |
| `ksni 0.3` | StatusNotifierItem system tray |
| `reqwest 0.12` (blocking + rustls-tls) | HTTP client for Groq API |
| `tokio 1` | Async runtime for daemon event loop |
| `serde_json 1.0` | Config and API response parsing |
| `chrono 0.4` | Timestamps for journal entries |
| `libc 0.2` | SIGINT to `pw-record` child process |

---

## Configuration

Both platforms use the same JSON schema:

```json
{"groq_api_key": "your-key-here"}
```

API key resolution priority (identical on both platforms):

1. `GROQ_API_KEY` environment variable
2. Platform config file:
   - macOS: `~/Library/Application Support/VoiceToText/config.json`
   - Linux: `~/.config/voicetotext/config.json` (respects `XDG_CONFIG_HOME`)
3. `VOICETOTEXT_CONFIG_PATH` env var overrides the config file path

---

## Journal format

Both platforms write identical Markdown:

```markdown
# Transcriptions - May 31, 2026

## 2:34 PM
The transcript text goes here.

---
```

Journal directory:

- macOS: `~/Documents/VoiceToText/`
- Linux: `~/Documents/VoiceToText/` (respects `XDG_DOCUMENTS_DIR`)

---

## Design decisions

**Zero UI.** The app is an invisible background utility. No window ever opens during normal use. The tray/menu bar icon and its badge state are the entire UI.

**Groq `whisper-large-v3-turbo`.** ~8× faster inference vs. `whisper-large-v3` with minimal accuracy loss. Audio is captured at 16 kHz mono (Whisper's native rate) to minimise upload size and latency.

**Audio format differs by platform.** macOS uses AAC/M4A (native AVFoundation, no external tools). Linux uses Opus/OGG via `pw-record | ffmpeg` (smaller files, but requires PipeWire and ffmpeg at runtime).

**Auto-paste approach is platform-constrained.** macOS can synthesise any keystroke via CoreGraphics with Accessibility permission. Linux Wayland's security model requires going through the XDG RemoteDesktop portal, which only works reliably on GNOME; other desktops fall back gracefully.

**Library split on Linux.** The Rust crate is both binary and library so all logic can be unit-tested without running the daemon. `groq.rs` and `journal.rs` are fully pure — no I/O, just data transformation — and are comprehensively tested.

---

## Source layout

```
VoiceToText/                      macOS Swift app (Xcode)
  main.swift                      NSApplication entry point
  App/
    VoiceToTextApp.swift          AppDelegate — wires everything up
  UI/
    StatusItemController.swift    Menu bar icon and state badges
  Hotkeys/
    HotkeyManager.swift           Global Option+Space listener
  Managers/
    RecordingManager.swift        AVAudioRecorder wrapper
    GroqTranscriber.swift         Groq Whisper API client
    AutoPaster.swift              CGEvent Cmd+V synthesiser
    TranscriptionJournal.swift    Daily markdown journal
    HTTPClient.swift              URLSession wrapper protocol
    TranscriptionHistoryManager.swift  In-memory transcription history
  Models/
    AppState.swift                idle / recording / transcribing
    Transcription.swift           Codable transcript model
    TranscriptionError.swift      Typed error enum
  Resources/
    SetupChecker.swift            First-launch setup state
    WelcomeViewController.swift   Onboarding UI (scaffolded)

linux/                            Linux Rust crate
  src/
    main.rs                       CLI dispatcher (file/record/daemon/sources)
    lib.rs                        Public API re-exports
    state.rs                      AppState enum
    config.rs                     API key resolution, XDG paths
    groq.rs                       Pure Groq request builder + response parser
    transport.rs                  reqwest HTTP execution
    recorder.rs                   pw-record | ffmpeg pipeline
    hotkey_daemon.rs              Async event loop, toggle logic, pipeline
    autopaste.rs                  XDG RemoteDesktop portal, restore token
    tray_app.rs                   ksni tray, event bridging
    platform.rs                   Clipboard, sound, journal, icons
    desktop.rs                    Portal capability probing
    journal.rs                    Pure journal entry renderer

docs/
  index.html                      Executive presentation (GitHub Pages, space-bar to navigate)
  architecture.md                 This file
```
