#!/bin/sh
# Packages this project's own files (session, config, panel layout, Log Out
# helper) as mate-wayland-desktop_<version>_all.deb in packaging/build/.
# The ISO installs this package.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
version=${1:-0.1}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

install -Dm755 "$here/session/mate-wayland-desktop-session" "$root/usr/bin/mate-wayland-desktop-session"
install -Dm755 "$here/session/mate-wayland-desktop-logout" "$root/usr/bin/mate-wayland-desktop-logout"
install -Dm644 "$here/wallpapers/mate-wayland-desktop.svg" "$root/usr/share/backgrounds/mate-wayland-desktop/mate-wayland-desktop.svg"
install -Dm644 "$here/wallpapers/mate-wayland-desktop.xml" "$root/usr/share/mate-background-properties/mate-wayland-desktop.xml"
install -Dm644 "$here/session/lightdm-gtk-greeter.conf" "$root/etc/lightdm/lightdm-gtk-greeter.conf.d/50-mate-wayland-desktop.conf"
install -Dm755 "$here/session/mate-wayland-desktop-icons" "$root/usr/bin/mate-wayland-desktop-icons"
# The logo, under the names the menu button and "about" dialogs ask for.
for name in places/start-here places/start-here-symbolic places/distributor-logo apps/mate-wayland-desktop; do
    install -Dm644 "$here/artwork/logo.svg" "$root/usr/share/icons/mate-wayland-desktop/scalable/$name.svg"
done
install -Dm644 "$here/icons/index.theme" "$root/usr/share/icons/mate-wayland-desktop/index.theme"
install -Dm644 "$here/icons/aliases.conf" "$root/usr/share/mate-wayland-desktop/icon-aliases.conf"
for icon in "$here"/icons/status/*.svg; do
    install -Dm644 "$icon" "$root/usr/share/mate-wayland-desktop/icons-status/$(basename "$icon")"
done
install -Dm755 "$here/session/mate-wayland-desktop-panel-refresh" "$root/usr/bin/mate-wayland-desktop-panel-refresh"
install -Dm644 "$here/session/gtklock/config.ini" "$root/etc/xdg/gtklock/config.ini"
install -Dm644 "$here/session/gtklock/style.css" "$root/etc/xdg/gtklock/style.css"
install -Dm755 "$here/session/mate-wayland-desktop-wallpaper" "$root/usr/bin/mate-wayland-desktop-wallpaper"
install -Dm755 "$here/session/mate-wayland-desktop-settings" "$root/usr/bin/mate-wayland-desktop-settings"
install -Dm755 "$here/session/mate-wayland-desktop-displays" "$root/usr/bin/mate-wayland-desktop-displays"
install -Dm755 "$here/session/mate-wayland-desktop-vm-display" "$root/usr/bin/mate-wayland-desktop-vm-display"
install -Dm644 "$here/session/mate-wayland-desktop-vbox-display.service" "$root/usr/lib/systemd/system/mate-wayland-desktop-vbox-display.service"
mkdir -p "$root/etc/systemd/system/multi-user.target.wants"
ln -s /usr/lib/systemd/system/mate-wayland-desktop-vbox-display.service "$root/etc/systemd/system/multi-user.target.wants/mate-wayland-desktop-vbox-display.service"
install -Dm644 "$here/session/mate-wayland-desktop.desktop" "$root/usr/share/wayland-sessions/mate-wayland-desktop.desktop"
for f in rc.xml environment menu.xml; do
    install -Dm644 "$here/labwc/$f" "$root/etc/xdg/mate-wayland-desktop/$f"
done
install -Dm755 "$here/labwc/autostart" "$root/etc/xdg/mate-wayland-desktop/autostart"
install -Dm644 "$here/panel/mate-wayland-desktop.layout" "$root/usr/share/mate-panel/layouts/mate-wayland-desktop.layout"
install -Dm644 "$here/panel/90_mate-wayland-desktop.gschema.override" "$root/usr/share/glib-2.0/schemas/90_mate-wayland-desktop.gschema.override"
install -Dm755 "$here/session/mate-wayland-desktop-keys" "$root/usr/bin/mate-wayland-desktop-keys"
install -Dm755 "$here/session/mate-wayland-desktop-screenshot" "$root/usr/bin/mate-wayland-desktop-screenshot"
install -Dm644 "$here/session/swaync/config.json" "$root/etc/xdg/mate-wayland-desktop/swaync/config.json"
install -Dm644 "$here/session/swaync/style.css" "$root/etc/xdg/mate-wayland-desktop/swaync/style.css"
install -Dm644 "$here/README.md" "$root/usr/share/doc/mate-wayland-desktop/README.md"

# HiDPI launcher: runs an X11 program in its own high-resolution Xwayland
# window so it is sharp on a scaled screen. Three scripts, a menu entry, the
# picker's settings, and a small library preloaded into that Xwayland so the
# window carries the program's own name and icon. The library is compiled
# here: amd64 only, like satty below.
for f in hidpi-run hidpi-menu hidpi-desktop; do
    install -Dm755 "$here/session/hidpi/$f" "$root/usr/bin/$f"
done
install -Dm644 "$here/session/hidpi/hidpi-launcher.desktop" "$root/usr/share/applications/hidpi-launcher.desktop"
install -Dm644 "$here/session/hidpi/hidpi-menu.ini" "$root/etc/xdg/mate-wayland-desktop/hidpi-menu.ini"
command -v cc >/dev/null || { echo "build-session-deb: a C compiler (cc) is needed for the HiDPI launcher." >&2; exit 1; }
mkdir -p "$root/usr/lib/mate-wayland-desktop"
cc -shared -fPIC -O2 -Wall -o "$root/usr/lib/mate-wayland-desktop/hidpi-xwl-shim.so" \
    "$here/session/hidpi/hidpi-xwl-shim.c" -ldl
chmod 644 "$root/usr/lib/mate-wayland-desktop/hidpi-xwl-shim.so"

# satty: the Wayland screenshot annotator the Print key opens (blur, pixelate,
# highlight, arrows, numbered steps). Not packaged by Ubuntu, so fetch the
# pinned upstream release and verify its checksum before adding the binary.
# amd64 only. MPL-2.0; source: https://github.com/Satty-org/Satty
satty_ver=0.22.0
satty_sha=eb7a028c4a5ce331c2f355add8e2b807a7d697fe4495f7e1965786a4f6bcd5b8
satty_tgz=$(mktemp)
curl -fsSL "https://github.com/Satty-org/Satty/releases/download/v${satty_ver}/satty-x86_64-unknown-linux-gnu.tar.gz" -o "$satty_tgz"
echo "$satty_sha  $satty_tgz" | sha256sum -c - >/dev/null
satty_dir=$(mktemp -d)
tar -xzf "$satty_tgz" -C "$satty_dir"
install -Dm755 "$(find "$satty_dir" -type f -name satty | head -1)" "$root/usr/bin/satty"
rm -rf "$satty_tgz" "$satty_dir"

mkdir -p "$root/DEBIAN"
cat > "$root/DEBIAN/control" <<CONTROL
Package: mate-wayland-desktop
Version: $version
Architecture: all
Maintainer: MATE Wayland Desktop <build@mate-wayland-desktop.invalid>
Section: x11
Priority: optional
Depends: labwc, xwayland, mate-panel (>= 1.29.2), mate-desktop (>= 1.29.1), caja (>= 1.29.1), mate-media (>= 1.29.0), mate-applets (>= 1.28.1), mate-settings-daemon, mate-polkit, sway-notification-center, libnotify-bin, mate-themes, mate-icon-theme, yaru-theme-icon, fonts-noto-core, gsettings-desktop-schemas, swaybg, swayidle, gtklock, grim, slurp, wl-clipboard, libgtk-4-1, libadwaita-1-0, xdotool, xclip, x11-utils, fuzzel, libdecor-0-0, wireplumber, python3-gi, python3-gi-cairo, wlr-randr, gir1.2-gtk-3.0, gir1.2-gtklayershell-0.1, gir1.2-matedesktop-2.0, dbus-user-session
Recommends: zenity, libdecor-0-plugin-1-gtk, playerctl, network-manager-applet, wdisplays, kanshi, libayatana-appindicator3-1, gir1.2-ayatanaappindicator3-0.1, mate-terminal, mate-control-center
Description: MATE desktop on Wayland, using the labwc compositor
 Session entry, labwc configuration, panel layout and a Log Out helper that
 together run the MATE desktop as a Wayland session.
CONTROL
cat > "$root/DEBIAN/conffiles" <<CONF
/etc/xdg/mate-wayland-desktop/rc.xml
/etc/xdg/mate-wayland-desktop/environment
/etc/xdg/mate-wayland-desktop/menu.xml
/etc/xdg/mate-wayland-desktop/autostart
CONF
cat > "$root/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
glib-compile-schemas /usr/share/glib-2.0/schemas || true
# Panel icons of our icon theme, generated from the installed Yaru theme.
mate-wayland-desktop-icons || true
POSTINST
cat > "$root/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
glib-compile-schemas /usr/share/glib-2.0/schemas || true
if [ "$1" = remove ] || [ "$1" = purge ]; then
    rm -rf /usr/share/icons/mate-wayland-desktop/scalable \
        /usr/share/icons/mate-wayland-desktop/icon-theme.cache
fi
POSTRM
chmod 755 "$root/DEBIAN/postinst" "$root/DEBIAN/postrm"

mkdir -p "$here/packaging/build"
dpkg-deb --root-owner-group --build "$root" "$here/packaging/build/mate-wayland-desktop_${version}_all.deb"
