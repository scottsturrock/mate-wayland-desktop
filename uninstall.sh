#!/bin/sh
# Removes the files installed by install.sh. Packages are left in place.
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo ./uninstall.sh" >&2
    exit 1
fi

rm -f /usr/local/bin/mate-wayland-desktop-session /usr/local/bin/mate-wayland-desktop-logout
rm -f /usr/share/wayland-sessions/mate-wayland-desktop.desktop
rm -f /etc/xdg/mate-wayland-desktop/rc.xml /etc/xdg/mate-wayland-desktop/environment \
      /etc/xdg/mate-wayland-desktop/menu.xml /etc/xdg/mate-wayland-desktop/autostart
rmdir /etc/xdg/mate-wayland-desktop 2>/dev/null || true
rm -f /usr/share/mate-panel/layouts/mate-wayland-desktop.layout
rm -f /usr/share/glib-2.0/schemas/90_mate-wayland-desktop.gschema.override
glib-compile-schemas /usr/share/glib-2.0/schemas

echo "Removed. Per-user settings in ~/.config/mate-wayland-desktop were not touched."
