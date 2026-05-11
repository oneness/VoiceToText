# Linux Setup Guide

## Prerequisites

- Linux with GNOME Shell 49+ and Wayland
- Rust toolchain (for building from source)
- `pw-record` (PipeWire) for audio capture
- `wl-copy` (wl-clipboard) for clipboard support
- `pw-play` (PipeWire) for completion sound
- A Groq API key: https://console.groq.com/keys

## Quick Start

### 1. Build (native)

```bash
cd linux
cargo build --release
```

### 2. Cross-compile for aarch64 (e.g., MNT Pocket Reform)

Requires QEMU aarch64 emulation and Nix with flake support:

```bash
cd linux
nix-build default-cross.nix
```

The resulting binary is at `result/bin/voicetotext-linux-core`. Copy it and the
`assets/` directory to the target machine (e.g., `~/bin/`).

See [default-cross.nix](default-cross.nix) for details on asset bundling and
ELF interpreter patching.

### 3. Configure your Groq API key

```bash
mkdir -p ~/.config/voicetotext
cat > ~/.config/voicetotext/config.json <<'JSON'
{"groq_api_key":"your-groq-api-key"}
JSON
```

Or set the environment variable:
```bash
export GROQ_API_KEY="your-groq-api-key"
```

### 4. Run the daemon

```bash
voicetotext-linux-core daemon
```

This starts:
- A system tray icon (via StatusNotifierItem/KDE sysext)
- A GlobalShortcuts portal session bound to **Alt+Space**

### 5. Autostart

Copy or symlink the `.desktop` file to `~/.config/autostart/`:

```ini
[Desktop Entry]
Type=Application
Name=VoiceToText Daemon
Comment=Start VoiceToText hotkey daemon
Exec=/home/YOU/bin/voicetotext-linux-core daemon
Terminal=false
X-GNOME-Autostart-enabled=true
```

Add a short delay to avoid portal race conditions on login:

```ini
Exec=/bin/bash -c "sleep 10 && /home/YOU/bin/voicetotext-linux-core daemon"
```

## Usage

- Press **Alt+Space** to start recording.
- Press **Alt+Space** again to stop recording and transcribe.
- The transcribed text is copied to clipboard and pasted automatically.
- Click the tray icon to toggle recording or quit.

## Other Commands

```bash
voicetotext-linux-core sources             # list audio sources
voicetotext-linux-core record [seconds]    # record and transcribe (one-shot)
voicetotext-linux-core <audio-file>        # transcribe an existing file
```

## Troubleshooting

### Alt+Space hotkey doesn't work (GNOME 49–50)

**Symptom:** The daemon starts, logs `shortcut bound: id=toggle-recording trigger=Press <Alt>space`,
but pressing Alt+Space does nothing. GNOME Shell doesn't grab the key.

**Root cause:** GNOME's global-shortcuts provider (introduced in
xdg-desktop-portal-gnome 50.0) requires the shortcut binding to be persisted
in dconf. The portal `BindShortcuts` call succeeds at the D-Bus level, but if
the binding is not stored in dconf, GNOME Shell never actually registers the
key grab.

You can check the current state:

```bash
# Should show 'shortcuts': <['<Alt>space']> inside the entry
dconf dump /org/gnome/settings-daemon/global-shortcuts/
```

**If the `shortcuts` key is missing**, set it manually:

```bash
dconf write "/org/gnome/settings-daemon/global-shortcuts/com.voicetotext.VoiceToText/shortcuts" \
  "[('toggle-recording', {'description': <'Start or stop voice recording'>, 'shortcuts': <['<Alt>space']>})]"
```

Also ensure the application is listed:

```bash
dconf write "/org/gnome/settings-daemon/global-shortcuts/applications" \
  "['com.voicetotext.VoiceToText']"
```

After setting these values, restart the daemon.

**Why this doesn't happen on all machines:** On systems with
xdg-desktop-portal-gnome 49.x (e.g., NixOS with GNOME 49.4), the
GlobalShortcuts portal works without requiring the dconf binding to be
pre-populated — the portal provider handles the grab directly. On 50.0+
(Debian unstable), the provider delegates to the settings daemon, which reads
the binding from dconf. If the binding is empty, no grab is registered.

### GlobalShortcuts portal not available

**Symptom:** `error: GlobalShortcuts portal is not available on this desktop`

**Cause:** Either the daemon started before the portal was ready (e.g., during
login), or `xdg-desktop-portal-gnome` is not installed.

**Fix:**
1. Ensure `xdg-desktop-portal-gnome` is installed.
2. Verify the portal is running: `gdbus introspect --session --dest
   org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop |
   grep GlobalShortcuts`
3. If using autostart, add a delay (e.g., `sleep 15`) before launching the daemon.

### Assets not found (missing icon/sound)

**Symptom:** `error: missing icon asset at ...` or `warning: bundled completion
sound is missing`

**Cause:** In release builds, assets are resolved relative to the binary's
directory. The `assets/` folder must be next to the binary.

**Fix:** Ensure the directory structure is correct:
```
~/bin/voicetotext-linux-core
~/bin/assets/
    completion.oga
    icons/hicolor/scalable/status/voicetotext-symbolic.svg
    icons/hicolor/scalable/status/voicetotext-recording-symbolic.svg
    icons/hicolor/scalable/status/voicetotext-transcribing-symbolic.svg
```

### Running via SSH doesn't work

The daemon requires the full GNOME session environment. If you must start it
from SSH, export the required variables:

```bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export WAYLAND_DISPLAY=wayland-0
```

### Mismatched GNOME versions

Some distributions (e.g., Debian unstable) ship GNOME Shell 49.5 with
xdg-desktop-portal-gnome 50.0. This mismatch can cause the GlobalShortcuts
flow to differ from what the code expects. Always verify both versions:

```bash
gnome-shell --version
dpkg -l xdg-desktop-portal-gnome   # Debian
# or on NixOS:
readlink /proc/$(pgrep -f xdg-desktop-portal-gnome)/exe
```

## Key File Locations

| File | Purpose |
|------|---------|
| `~/.config/voicetotext/config.json` | API key configuration |
| `~/.local/share/applications/com.voicetotext.VoiceToText.desktop` | App registration (auto-generated by daemon) |
| `~/.config/autostart/voicetotext.desktop` | Autostart entry |
| `~/bin/voicetotext-linux-core` | Binary |
| `~/bin/assets/` | Bundled assets (icons, sounds) |
| `~/Documents/VoiceToText/` | Transcription journal (Markdown) |

## Architecture

The daemon (`voicetotext-linux-core daemon`) runs two components:

1. **GlobalShortcuts listener** (`hotkey_daemon.rs`): Uses the
   `org.freedesktop.portal.GlobalShortcuts` portal via `ashpd` to register
   Alt+Space as a global hotkey. When activated, it toggles recording.

2. **System tray icon** (`tray_app.rs`): Uses `ksni` (StatusNotifierItem) to
   provide a tray icon with status indication and manual toggle/quit controls.

Both are coordinated via `tokio` async channels.
