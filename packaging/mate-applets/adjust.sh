# Sourced by build-package.sh inside the mate-applets source directory.
#
# Ubuntu builds these applets as separate programs, which only works on
# X11. Build them into the panel instead.
echo "--- debian/rules before:"; grep -n -A8 'dh_auto_configure' debian/rules
sed -i 's|dh_auto_configure --|dh_auto_configure -- --enable-in-process|' debian/rules
grep -q -- '--enable-in-process' debian/rules
