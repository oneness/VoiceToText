# Linux GlobalShortcuts Hotkey Debugging Guide

## The Problem

VoiceToText uses the `org.freedesktop.portal.GlobalShortcuts` D-Bus portal
(via the `ashpd` Rust crate) to register **Alt+Space** as a global hotkey.
The portal bind call succeeds without error, but GNOME Shell may or may not
actually grab the key depending on the portal backend version.

## How It Works

```
VoiceToText binary
  └─ ashpd::GlobalShortcuts::create_session()
  └─ ashpd::GlobalShortcuts::bind_shortcuts(["Alt+space"])
  └─ D-Bus → org.freedesktop.portal.Desktop
       └─ xdg-desktop-portal forwards to backend
            └─ xdg-desktop-portal-gnome (the backend)
                 └─ gnome-settings-daemon global-shortcuts provider
                      └─ GNOME Shell grabs the key
```

## Version-Dependent Behavior

### xdg-desktop-portal-gnome 49.x (e.g., NixOS with GNOME 49.4)

- The portal backend handles the grab directly when `BindShortcuts` is called.
- The `ashpd` call succeeds → key is immediately active.
- No dconf pre-configuration needed.
- `gnome-control-center-global-shortcuts-provider` does NOT activate.

### xdg-desktop-portal-gnome 50.x (e.g., Debian unstable, GNOME 49.5)

- The portal backend delegates to the settings daemon.
- `gnome-control-center-global-shortcuts-provider` activates on D-Bus.
- The provider reads shortcut bindings from dconf:
  `/org/gnome/settings-daemon/global-shortcuts/`
- If the `shortcuts` key in dconf is empty/missing, GNOME Shell does NOT grab
  the key, even though `BindShortcuts` returns success.
- **The binding must be pre-populated in dconf.**

## Diagnosing the Issue

### 1. Check the daemon log

```bash
# If running via autostart:
journalctl --user --since "1 hour ago" | grep voicetotext

# If running manually:
/tmp/vtt.log
```

Look for:
```
shortcut bound: id=toggle-recording trigger=Press <Alt>space   ← bind succeeded
state: idle                                                       ← daemon is waiting
```

If you see this but the key doesn't work, the issue is in dconf.

### 2. Check dconf binding

```bash
dconf dump /org/gnome/settings-daemon/global-shortcuts/
```

**Working (has `shortcuts` key):**
```
[/]
applications=['com.voicetotext.VoiceToText']

[com.voicetotext.VoiceToText]
shortcuts=[('toggle-recording', {'description': <'Start or stop voice recording'>, 'shortcuts': <['<Alt>space']>})]
```

**Broken (missing `shortcuts` key):**
```
[/]
applications=['com.voicetotext.VoiceToText']

[com.voicetotext.VoiceToText]
shortcuts=[('toggle-recording', {'description': <'Start or stop voice recording'>})]
```

### 3. Check portal backend version

```bash
# Debian/Ubuntu:
dpkg -l xdg-desktop-portal-gnome

# NixOS:
readlink /proc/$(pgrep -f xdg-desktop-portal-gnome)/exe
```

### 4. Check if provider is running

```bash
ps aux | grep gnome-control-center-global-shortcuts
```

If this process is running, you're on the 50.x flow that requires dconf
pre-configuration.

## The Fix

### Set the dconf binding manually

```bash
dconf write "/org/gnome/settings-daemon/global-shortcuts/com.voicetotext.VoiceToText/shortcuts" \
  "[('toggle-recording', {'description': <'Start or stop voice recording'>, 'shortcuts': <['<Alt>space']>})]"
```

### Ensure the app is listed

```bash
dconf write "/org/gnome/settings-daemon/global-shortcuts/applications" \
  "['com.voicetotext.VoiceToText']"
```

### Restart the daemon

```bash
pkill voicetotext-linux-core
# Start via autostart or manually
```

## Verifying It Works

After applying the fix, check:

```bash
# 1. Daemon is running
pgrep -a voicetotext

# 2. dconf has the binding
dconf dump /org/gnome/settings-daemon/global-shortcuts/ | grep shortcuts

# 3. Provider is active (on 50.x)
ps aux | grep gnome-control-center-global-shortcuts
```

Then press **Alt+Space** — you should see recording start.

## Why This Isn't Automated

The `ashpd` crate's `BindShortcuts` call returns the preferred trigger
description in its response, which the code logs as `trigger=Press <Alt>space`.
However, `ashpd` 0.12.3 does not write to dconf. The portal spec doesn't
require the backend to persist the binding either. On 49.x, the backend grabs
the key directly. On 50.x, the backend expects dconf to already have the
binding — a behavioral change that isn't clearly documented upstream.

A future improvement would be to have the daemon check the dconf value after
binding and write it if missing, or to detect the portal backend version and
warn the user.
