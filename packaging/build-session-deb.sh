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
install -Dm644 "$here/README.md" "$root/usr/share/doc/mate-wayland-desktop/README.md"

mkdir -p "$root/DEBIAN"
cat > "$root/DEBIAN/control" <<CONTROL
Package: mate-wayland-desktop
Version: $version
Architecture: all
Maintainer: MATE Wayland Desktop <build@mate-wayland-desktop.invalid>
Section: x11
Priority: optional
Depends: labwc, xwayland, mate-panel (>= 1.29.2), mate-desktop (>= 1.29.1), caja (>= 1.29.1), mate-media (>= 1.29.0), mate-applets (>= 1.28.1), mate-settings-daemon, mate-polkit, mate-notification-daemon, mate-themes, mate-icon-theme, yaru-theme-icon, fonts-noto-core, gsettings-desktop-schemas, swaybg, swayidle, gtklock, grim, slurp, python3-gi, python3-gi-cairo, wlr-randr, gir1.2-gtk-3.0, gir1.2-gtklayershell-0.1, gir1.2-matedesktop-2.0, dbus-user-session
Recommends: network-manager-applet, wdisplays, kanshi, libayatana-appindicator3-1, gir1.2-ayatanaappindicator3-0.1, mate-terminal, mate-control-center
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
