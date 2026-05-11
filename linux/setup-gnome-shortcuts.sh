#!/usr/bin/env bash
# Setup script for VoiceToText Linux daemon on GNOME Wayland.
# Run this once after deploying the binary to configure the GlobalShortcuts
# dconf binding required by xdg-desktop-portal-gnome 50.x+.
#
# Usage: bash setup-gnome-shortcuts.sh

set -euo pipefail

APP_ID="com.voicetotext.VoiceToText"
SHORTCUT_ID="toggle-recording"
SHORTCUT_DESCRIPTION="Start or stop voice recording"
KEY_BINDING="<Alt>space"

echo "Configuring GNOME GlobalShortcuts for ${APP_ID}..."

# Register the application
dconf write "/org/gnome/settings-daemon/global-shortcuts/applications" \
  "['${APP_ID}']"

# Set the shortcut binding
dconf write "/org/gnome/settings-daemon/global-shortcuts/${APP_ID}/shortcuts" \
  "[('${SHORTCUT_ID}', {'description': <'${SHORTCUT_DESCRIPTION}'>, 'shortcuts': <['${KEY_BINDING}']>})]"

echo "Done. Shortcut ${KEY_BINDING} registered for ${APP_ID}."
echo ""
echo "Verify:"
echo "  dconf dump /org/gnome/settings-daemon/global-shortcuts/"
echo ""
echo "Then start the daemon:"
echo "  voicetotext-linux-core daemon"
