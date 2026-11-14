# Sourced by build-package.sh inside the mate-media source directory.
#
# The volume control applet only works on Wayland when built into the panel.
sed -i 's|--disable-static|--disable-static \\\n\t\t--enable-wayland \\\n\t\t--enable-in-process|' debian/rules

# The in-process applet has no D-Bus service file.
sed -i '/usr\/share\/dbus-1\//d' debian/*.install

apt-get install -y libgtk-layer-shell-dev
