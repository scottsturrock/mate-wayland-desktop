#!/bin/sh
# Runs the mate-wayland-desktop desktop in a window inside your current Wayland
# session, using the configuration in this directory. Nothing is installed.
# Close the window (or right-click the desktop > Log Out) to stop.
set -eu

here=$(cd "$(dirname "$0")" && pwd)

command -v labwc >/dev/null || {
    echo "labwc is not installed. Run: sudo ./install.sh --packages-only" >&2
    exit 1
}

export MATE_WAYLAND_DESKTOP_NESTED=1
export MATE_WAYLAND_DESKTOP_DIR="$here"
export XDG_CURRENT_DESKTOP=MATE
export XDG_MENU_PREFIX=mate-

# A private D-Bus session keeps this test desktop separate from your real
# one: Log Out inside the window only closes the window.
exec dbus-run-session -- labwc -C "$here/labwc"
