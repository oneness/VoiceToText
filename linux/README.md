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
- A GNOME custom keyboard shortcut for **Alt+Space** (registered automatically
  via `gsettings` on every startup — this is the reliable hotkey path on
  GNOME 50; see [Alt+Space hotkey doesn't work](#altspace-hotkey-doesnt-work-gnome-50) below)

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

### Alt+Space hotkey doesn't work (GNOME 50)

**Symptom:** The daemon logs `warning: portal shortcut binding failed (Portal
request didn't succeed: Other)`.

**Root cause:** On GNOME 50, `gnome-control-center-global-shortcuts-provider`
segfaults every time `bind_shortcuts` is called from a windowless app (it
tries to show a key-binding dialog with no parent window). The portal
responds with error code 2 ("Other") after the crash. This is a GNOME 50 bug,
not something fixable from the app side. You can confirm it in the journal:

```bash
journalctl --user | grep -i "global-shortcuts-provider\|core-dump"
# ...cc_global_shortcut_dialog_present ... assertion 'GDK_IS_SURFACE (surface)' failed
# ...Main process exited, code=dumped, status=11/SEGV
```

**This is expected and handled automatically** — the daemon logs the warning
and keeps running. On every startup it registers Alt+Space as a **GNOME
custom keyboard shortcut** (via `gsettings`, see `ensure_gnome_custom_shortcut()`
in `hotkey_daemon.rs`) that writes `toggle` to the daemon's control FIFO at
`/run/user/$UID/voicetotext-control`. No separate setup script, dconf edit, or
Python dependency is needed — this happens purely in the Rust binary.

If Alt+Space still doesn't work, verify the shortcut was registered:

```bash
gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings
# should list .../custom-keybindings/voicetotext/

gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voicetotext/ binding
# should be '<Alt>space'
```

and that the FIFO exists and the daemon is running:

```bash
ls -la /run/user/$(id -u)/voicetotext-control   # should be a named pipe (prw-...)
pgrep -a voicetotext-linux-core
```

If GNOME ever fixes the segfault, the portal path will bind directly and this
fallback becomes unnecessary — no code change required.

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

1. **Hotkey listener** (`hotkey_daemon.rs`): Attempts to register Alt+Space via
   the `org.freedesktop.portal.GlobalShortcuts` portal (`ashpd`). On GNOME 50
   this reliably fails (see Troubleshooting), so on every startup the daemon
   also registers Alt+Space as a GNOME custom keyboard shortcut via
   `gsettings`, which writes to a control FIFO the daemon listens on. Either
   path toggles recording when triggered.

2. **System tray icon** (`tray_app.rs`): Uses `ksni` (StatusNotifierItem) to
   provide a tray icon with status indication and manual toggle/quit controls.

Both are coordinated via `tokio` async channels.
