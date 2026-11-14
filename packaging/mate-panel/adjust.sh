# Sourced by build-package.sh inside the mate-panel source directory.
#
# Ubuntu builds the clock, notification area and window applets as separate
# programs, which only works on X11. Build them into the panel instead.
sed -i 's|--enable-gtk-doc|--enable-gtk-doc \\\n\t\t--enable-wayland \\\n\t\t--with-in-process-applets=all|' debian/rules

# In-process applets install as libraries, not as programs in libexec.
sed -i '/usr\/libexec\/mate-panel\//d; /usr\/share\/dbus-1\//d' debian/mate-panel.install
echo 'usr/lib/*/mate-panel/*.so' >> debian/mate-panel.install
sed -i 's|rm -f debian/tmp/usr/lib/\*/\*.la|rm -f debian/tmp/usr/lib/*/*.la debian/tmp/usr/lib/*/mate-panel/*.la|' debian/rules

# Wayland window list and workspace switcher need libxfce4windowing.
apt-get install -y libxfce4windowing-0-dev libgtk-layer-shell-dev
