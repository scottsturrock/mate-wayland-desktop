# Sourced by build-package.sh inside the mate-control-center source directory.
#
# 1.29 needs libraries that Ubuntu's packaging for 1.26 does not list.
apt-get install -y libudisks2-dev libayatana-appindicator3-dev

# 1.29 no longer ships libmate-slab and libmate-window-settings as separate
# libraries. Drop their packages and every reference to them.
awk 'BEGIN { RS = ""; ORS = "\n\n" } !/^Package: libmate-(slab|window-settings)/' debian/control > debian/control.new
mv debian/control.new debian/control
sed -i '/libmate-slab\|libmate-window-settings/d' debian/control
rm -f debian/libmate-slab* debian/libmate-window-settings*

# The Keyboard, Mouse and Keyboard Shortcuts dialogs still crash as native
# Wayland clients; start them through XWayland from the menus.
for cmd in mate-keyboard-properties mate-mouse-properties mate-keybinding-properties; do
    grep -rl --include='*.desktop.in*' "^Exec=$cmd" . | while read -r f; do
        sed -i "s|^Exec=$cmd|Exec=env GDK_BACKEND=x11 $cmd|" "$f"
    done
done
grep -rh --include='*.desktop.in*' '^Exec=env GDK_BACKEND=x11' . | sort -u

# MATE's Displays dialog configures screens through X11 and shows an error
# on Wayland. Its menu entry (same name, icon and place) opens wdisplays,
# the Wayland tool for the same job.
grep -rl --include='*.desktop.in*' '^Exec=mate-display-properties' . | while read -r f; do
    sed -i 's|^Exec=mate-display-properties|Exec=wdisplays|' "$f"
done
grep -rh --include='*.desktop.in*' '^Exec=wdisplays' . | sort -u
