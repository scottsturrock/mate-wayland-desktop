#!/bin/sh
# Installs the mate-wayland-desktop session on Debian/Ubuntu.
# Usage: sudo ./install.sh [--packages-only]
set -eu

here=$(cd "$(dirname "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo ./install.sh" >&2
    exit 1
fi

# Desktop components (MATE) + compositor (labwc) + Wayland replacements for
# the MATE tools that only work on X11.
apt-get update
apt-get install -y \
    labwc xwayland \
    mate-panel mate-applets mate-indicator-applet \
    caja mate-terminal mate-control-center mate-settings-daemon \
    mate-notification-daemon mate-polkit network-manager-applet \
    mate-themes mate-icon-theme yaru-theme-icon \
    gtklock swayidle swaybg python3-gi gir1.2-gtk-3.0 dbus-daemon \
    wdisplays kanshi \
    grim slurp wl-clipboard

# Newer MATE components than Ubuntu ships, needed for Wayland support
# (panel applets, desktop icons). Built by packaging/build-all.sh.
debs=$(ls "$here"/packaging/build/*.deb 2>/dev/null | grep -v -E -- '-(dev|doc)_' || true)
if [ -n "$debs" ]; then
    # shellcheck disable=SC2086
    apt-get install -y $debs
else
    echo "WARNING: no rebuilt MATE packages found in packaging/build/." >&2
    echo "Ubuntu's own versions lack Wayland support for several panel" >&2
    echo "applets and desktop icons. Run packaging/build-all.sh first." >&2
fi

[ "${1:-}" = "--packages-only" ] && exit 0

install -Dm755 "$here/session/mate-wayland-desktop-session" /usr/local/bin/mate-wayland-desktop-session
install -Dm755 "$here/session/mate-wayland-desktop-logout" /usr/local/bin/mate-wayland-desktop-logout
install -Dm644 "$here/session/mate-wayland-desktop.desktop" /usr/share/wayland-sessions/mate-wayland-desktop.desktop

# Panel layout, and make it the default for accounts that have no panel
# settings yet.
install -Dm644 "$here/panel/mate-wayland-desktop.layout" /usr/share/mate-panel/layouts/mate-wayland-desktop.layout
install -Dm644 "$here/panel/90_mate-wayland-desktop.gschema.override" /usr/share/glib-2.0/schemas/90_mate-wayland-desktop.gschema.override
glib-compile-schemas /usr/share/glib-2.0/schemas

install -d /etc/xdg/mate-wayland-desktop
for f in rc.xml environment menu.xml; do
    install -m644 "$here/labwc/$f" "/etc/xdg/mate-wayland-desktop/$f"
done
install -m755 "$here/labwc/autostart" /etc/xdg/mate-wayland-desktop/autostart

echo
echo "Installed. Log out and choose \"MATE Wayland Desktop\" from the gear menu on the login screen."
