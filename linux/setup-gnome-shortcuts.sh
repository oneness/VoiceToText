#!/usr/bin/env bash
# Setup script for VoiceToText Linux daemon on GNOME Wayland.
# Run this once after deploying the binary to configure the hotkey.
#
# This registers Alt+Space as a GNOME custom keyboard shortcut that writes
# "toggle" to the daemon's control FIFO when pressed.  This path is reliable
# on GNOME 50+ where the GlobalShortcuts portal backend (gnome-control-center)
# crashes on bind_shortcuts calls from windowless apps.
#
# Usage: bash setup-gnome-shortcuts.sh

set -euo pipefail

BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voicetotext/"
FIFO_PATH="/run/user/$(id -u)/voicetotext-control"

echo "Configuring GNOME custom keyboard shortcut for VoiceToText..."

# Add our path to the list of custom keybindings, preserving existing entries.
python3 - "$BINDING_PATH" <<'EOF'
import subprocess, sys, ast

path = sys.argv[1]
raw = subprocess.check_output(
    ["gsettings", "get",
     "org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings"],
    text=True
).strip()

# gsettings returns GVariant; parse the list of strings.
# Handle both "@as []" (empty) and "['...', '...']" forms.
if raw.startswith("@as"):
    current = []
else:
    current = ast.literal_eval(raw)

if path not in current:
    current.append(path)
    value = "[" + ", ".join(f"'{p}'" for p in current) + "]"
    subprocess.check_call(
        ["gsettings", "set",
         "org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings", value]
    )
    print(f"  added {path} to custom-keybindings list")
else:
    print("  shortcut path already in custom-keybindings list")
EOF

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDING_PATH" \
    name "VoiceToText Toggle"

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDING_PATH" \
    binding "<Alt>space"

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDING_PATH" \
    command "bash -c 'echo toggle > ${FIFO_PATH}'"

echo "Done."
echo ""
echo "Alt+Space is now bound via GNOME custom shortcuts."
echo "The daemon's control FIFO at ${FIFO_PATH} will receive toggle commands."
echo ""
echo "Verify:"
echo "  gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings"
echo "  gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${BINDING_PATH} binding"
echo ""
echo "Then start the daemon:"
echo "  voicetotext-linux-core daemon"
