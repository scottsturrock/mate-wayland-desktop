# Sourced by build-package.sh inside the mate-media source directory.
#
# The volume control applet only works on Wayland when built into the panel.
sed -i 's|--disable-static|--disable-static \\\n\t\t--enable-wayland \\\n\t\t--enable-in-process|' debian/rules

# The in-process applet has no D-Bus service file.
sed -i '/usr\/share\/dbus-1\//d' debian/*.install

# 1.29 adds settings for the volume applet (org.mate.volume-control), which
# Ubuntu's file lists for the older version do not include. Without the
# schema the applet has no settings and shows its media player controls with
# no way to turn them off.
echo 'usr/share/glib-2.0/schemas/' >> debian/mate-media-common.install

apt-get install -y libgtk-layer-shell-dev
