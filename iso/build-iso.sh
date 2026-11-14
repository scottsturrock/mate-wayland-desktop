#!/bin/sh
# Builds the mate-wayland-desktop live/install ISO from Ubuntu packages.
#
# Usage: sudo iso/build-iso.sh [--fresh]
# Needs: packaging/build/*.deb (run packaging/build-all.sh first),
#        about 15 GB free disk. Normally started by ./build.sh.
# Output: iso/out/mate-wayland-desktop-<release>-amd64.iso
#         (set OUT=/some/dir to write the ISO elsewhere)
#
# Works on a Debian-family Linux host with debootstrap; the build is isolated from the
# host and installs nothing on it (see lib/ubuntu-root.sh). The image is
# packed with Ubuntu's own GRUB, xorriso and mksquashfs from a small Ubuntu
# system in iso/cache/tools.
#
# Quick rebuilds: the installed system in iso/work/chroot is kept. If the
# package lists and our .deb files are unchanged, only our configuration is
# re-applied and the image repacked (about a minute). --fresh forces a full
# rebuild. Downloads are cached in iso/cache/.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
top=$(dirname "$here")
suite=${SUITE:-resolute}
mirror=${MIRROR:-http://archive.ubuntu.com/ubuntu}
cache="$here/cache"
. "$top/lib/ubuntu-root.sh"
isolate "$0" "$@"

fresh=0
for arg in "$@"; do
    case "$arg" in
        --fresh) fresh=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

release=${RELEASE:-26.04}
work="$here/work"
chroot="$work/chroot"
image="$work/image"
tools="$cache/tools"
# Where the finished ISO is written. Only that one file is ever created or
# replaced there; nothing else in the directory is touched.
out=${OUT:-$here/out}
isoname="mate-wayland-desktop-$release-amd64.iso"
iso="$out/$isoname"

# Progress lines: on the terminal, and for ./build.sh to display.
step() {
    echo "== $*"
    if [ -n "${MWD_PROGRESS:-}" ]; then echo "$*" >> "$MWD_PROGRESS"; fi
}

list() { grep -v '^#' "$1" | grep -v '^$' | tr '\n' ' '; }

in_chroot() { in_root "$chroot" "$@"; }

cleanup() {
    unmount_under "$chroot"
    unmount_under "$tools"
}
trap cleanup EXIT

# The MATE components built by packaging/build-all.sh. Our own session
# package is rebuilt from the working tree on every run (section 3), so a
# change to the session or its configuration needs only a quick rebuild.
debs=$(ls "$top"/packaging/build/*.deb 2>/dev/null |
    grep -v -E -- '-(dev|doc)_' | grep -v '/mate-wayland-desktop_' || true)
[ -n "$debs" ] || die "No packages in packaging/build/. Run packaging/build-all.sh first."

mkdir -p "$work" "$out" "$cache/apt-archives" "$cache/debootstrap" "$cache/keyring"

find_keyring

# Changes to the package lists or to our packages need a full rebuild;
# anything else only needs our configuration re-applied.
stamp=$( { echo "$suite $mirror"; cat "$here"/packages-*.txt "$here"/firefox/mozilla.*; sha256sum $debs; } | sha256sum | cut -d' ' -f1)
if [ "$fresh" -eq 0 ] && [ "$(cat "$work/packages.stamp" 2>/dev/null)" = "$stamp" ]; then
    step "Quick rebuild: packages unchanged, reusing the installed system (about 1 minute)"
    reuse=1
else
    step "Full rebuild: package lists or our packages changed (about 8 minutes)"
    reuse=0
fi

if [ "$reuse" -eq 0 ]; then
    # ------------------------------------------------------------ 1. base
    step "1/5 Base Ubuntu system"
    safe_rm "$chroot"
    rm -f "$work/packages.stamp"
    mkdir -p "$chroot"
    bootstrap "$chroot"
    echo "mate-wayland-desktop" > "$chroot/etc/hostname"
    mount_system "$chroot"

    # -------------------------------------------------------- 2. packages
    step "2/5 Installing packages"
    in_chroot apt-get update
    in_chroot apt-get -y dist-upgrade
    # shellcheck disable=SC2046
    in_chroot apt-get -y install $(list "$here/packages-base.txt")

    # Firefox comes from Mozilla's repository (see iso/firefox/). Added after
    # the base packages, which bring the certificates apt needs for https.
    install -Dm644 "$here/firefox/packages.mozilla.org.asc" "$chroot/etc/apt/keyrings/packages.mozilla.org.asc"
    install -Dm644 "$here/firefox/mozilla.sources" "$chroot/etc/apt/sources.list.d/mozilla.sources"
    install -Dm644 "$here/firefox/mozilla.pref" "$chroot/etc/apt/preferences.d/mozilla"
    in_chroot apt-get update

    # Our MATE builds and session package first, so apt prefers them over
    # Ubuntu's older versions when resolving the desktop packages.
    mkdir -p "$chroot/tmp/debs"
    # shellcheck disable=SC2086
    cp $debs "$chroot/tmp/debs/"
    "$top/packaging/build-session-deb.sh" >/dev/null
    cp "$top"/packaging/build/mate-wayland-desktop_*_all.deb "$chroot/tmp/debs/"
    in_chroot sh -c 'apt-get -y install --no-install-recommends /tmp/debs/*.deb'
    # shellcheck disable=SC2046
    in_chroot apt-get -y install --no-install-recommends \
        $(list "$here/packages-desktop.txt") $(list "$here/packages-live.txt")
    rm -rf "$chroot/tmp/debs"

    # Keep our MATE builds from being replaced by Ubuntu's packages.
    for deb in $debs; do
        in_chroot apt-mark hold "$(dpkg-deb -f "$deb" Package)" >/dev/null 2>&1 || true
    done

    in_chroot apt-get -y autoremove --purge
    echo "$stamp" > "$work/packages.stamp"
else
    block_services "$chroot"
    mount_system "$chroot"
fi

# Tools: a small separate Ubuntu system with Ubuntu's own GRUB, xorriso and
# mksquashfs for packing the image, and rsvg-convert for rendering the logo,
# so the result does not depend on what the build host has.
if [ ! -f "$tools/.ready-2" ]; then
    safe_rm "$tools"
    mkdir -p "$tools"
    bootstrap "$tools"
    mount_system "$tools"
    in_root "$tools" apt-get update
    in_root "$tools" apt-get -y install --no-install-recommends \
        squashfs-tools xorriso mtools grub-pc-bin grub-efi-amd64-bin grub-common \
        librsvg2-bin
    unmount_under "$tools"
    touch "$tools/.ready-2"
fi

# render_logo <png file> <size>: the project's logo as a PNG.
render_logo() {
    in_root "$tools" rsvg-convert -w "$2" -h "$2" < "$top/artwork/logo.svg" > "$1"
}

# ------------------------------------------------------- 3. configuration
# Everything in this section can be applied again over an earlier run.
step "3/5 Applying our session and configuration"

# Our session package, from the working tree as it is now.
"$top/packaging/build-session-deb.sh" >/dev/null
mkdir -p "$chroot/tmp/debs"
cp "$top"/packaging/build/mate-wayland-desktop_*_all.deb "$chroot/tmp/debs/"
in_chroot sh -c 'dpkg -i /tmp/debs/mate-wayland-desktop_*_all.deb'
rm -rf "$chroot/tmp/debs"
install -Dm644 "$here/live/50-mate-wayland-desktop.conf" \
    "$chroot/etc/lightdm/lightdm.conf.d/50-mate-wayland-desktop.conf"
install -Dm644 "$here/live/casper.conf" "$chroot/etc/casper.conf"
# The system's name as people see it (see iso/branding/README). The files
# belong to base-files; the diversions keep its updates from undoing this.
for f in /usr/lib/os-release /etc/lsb-release /etc/issue /etc/issue.net /etc/legal; do
    in_chroot dpkg-divert --quiet --rename --divert "$f.ubuntu" "$f"
    install -Dm644 "$here/branding/$(basename "$f")" "$chroot$f"
done
# Ubuntu's help links and news in the text-mode welcome message.
chmod -x "$chroot/etc/update-motd.d/10-help-text" "$chroot/etc/update-motd.d/50-motd-news" 2>/dev/null || true
# The text-mode boot splash shows the system's name.
if [ -f "$chroot/usr/share/plymouth/themes/ubuntu-text/ubuntu-text.plymouth" ]; then
    sed -i 's/^title=.*/title=MATE Wayland Desktop 26.04/' \
        "$chroot/usr/share/plymouth/themes/ubuntu-text/ubuntu-text.plymouth"
fi

# Boot splash: our own theme, made from Ubuntu's spinner theme (its spinner
# and password-prompt images) with our logo and colours. Ubuntu's themes
# carry an Ubuntu logo.
splash="$chroot/usr/share/plymouth/themes/mate-wayland-desktop"
rm -rf "$splash"
mkdir -p "$splash"
cp "$chroot"/usr/share/plymouth/themes/spinner/*.png "$splash/"
rm -f "$splash/watermark.png" "$splash/bgrt-fallback.png"
install -Dm644 "$here/plymouth/mate-wayland-desktop.plymouth" "$splash/mate-wayland-desktop.plymouth"
render_logo "$splash/watermark.png" 160
in_chroot update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
    /usr/share/plymouth/themes/mate-wayland-desktop/mate-wayland-desktop.plymouth 200 >/dev/null

# The startup image holds its own copies of casper.conf and the boot splash,
# so it is rebuilt whenever either changes (and always after a full rebuild,
# where it was made before they were installed).
initrd_stamp=$(cat "$here/live/casper.conf" "$here"/plymouth/* "$here"/branding/* "$top/artwork/logo.svg" | sha256sum | cut -d' ' -f1)
if [ "$reuse" -eq 0 ] || [ "$(cat "$work/initrd.stamp" 2>/dev/null)" != "$initrd_stamp" ]; then
    in_chroot update-initramfs -u
    echo "$initrd_stamp" > "$work/initrd.stamp"
fi

# Firefox: uBlock Origin preinstalled through Firefox's policy file, and
# Firefox as the default browser.
install -Dm644 "$here/firefox/policies.json" "$chroot/etc/firefox/policies/policies.json"
install -Dm644 "$here/firefox/mimeapps.list" "$chroot/etc/xdg/mimeapps.list"

# The labwc package ships a bare "labwc" session; keep it off the login
# screen's session list (a diversion survives package upgrades).
in_chroot dpkg-divert --quiet --rename --divert /usr/share/wayland-sessions/labwc.desktop.hidden \
    /usr/share/wayland-sessions/labwc.desktop

# wdisplays is opened from MATE's own "Displays" menu entry (see
# packaging/mate-control-center/adjust.sh); hide its second entry of the
# same name.
in_chroot dpkg-divert --quiet --rename --divert /usr/share/applications/network.cycles.wdisplays.desktop.hidden \
    /usr/share/applications/network.cycles.wdisplays.desktop

# NetworkManager manages all network devices.
mkdir -p "$chroot/etc/netplan"
printf 'network:\n  version: 2\n  renderer: NetworkManager\n' \
    > "$chroot/etc/netplan/01-network-manager-all.yaml"
chmod 600 "$chroot/etc/netplan/01-network-manager-all.yaml"

in_chroot locale-gen en_US.UTF-8
in_chroot update-locale LANG=en_US.UTF-8

# Installer: configuration, launcher, and an icon on the live desktop.
mkdir -p "$chroot/etc/calamares"
rm -rf "$chroot/etc/calamares/modules" "$chroot/etc/calamares/branding"
cp -r "$here/calamares/modules" "$here/calamares/branding" "$chroot/etc/calamares/"
render_logo "$chroot/etc/calamares/branding/mate-wayland-desktop/logo.png" 256
if [ -x "$chroot/usr/sbin/update-initramfs" ]; then
    initramfs_modules='initramfscfg\n  - initramfs'
else
    initramfs_modules='dracutlukscfg\n  - dracut'
fi
sed "s/@INITRAMFS_MODULES@/$initramfs_modules/" "$here/calamares/settings.conf" \
    > "$chroot/etc/calamares/settings.conf"
install -Dm755 "$here/live/mate-wayland-desktop-install" "$chroot/usr/bin/mate-wayland-desktop-install"
install -Dm644 "$here/live/mate-wayland-desktop-install.desktop" \
    "$chroot/usr/share/applications/mate-wayland-desktop-install.desktop"
install -Dm755 "$here/live/mate-wayland-desktop-install.desktop" \
    "$chroot/etc/skel/Desktop/mate-wayland-desktop-install.desktop"

# ------------------------------------------------------------- 4. cleanup
mkdir -p "$image/casper" "$image/boot/grub" "$image/.disk"
in_chroot dpkg-query -W --showformat='${Package} ${Version}\n' > "$image/casper/filesystem.manifest"
unmount_under "$chroot"
rm -f "$chroot/usr/sbin/policy-rc.d"
rm -f "$chroot/etc/resolv.conf"
ln -s ../run/systemd/resolve/stub-resolv.conf "$chroot/etc/resolv.conf"
rm -rf "$chroot/var/lib/apt/lists/"* "$chroot/tmp/"* "$chroot/var/tmp/"*
# Downloaded packages are kept in iso/cache/, not in the image.
rm -f "$chroot"/var/cache/apt/archives/*.deb "$chroot"/var/cache/apt/*.bin
: > "$chroot/etc/machine-id"

# --------------------------------------------------------------- 5. image
kernel=$(ls "$chroot"/boot/vmlinuz-* | sort -V | tail -1)
initrd=$(ls "$chroot"/boot/initrd.img-* | sort -V | tail -1)
cp "$kernel" "$image/casper/vmlinuz"
cp "$initrd" "$image/casper/initrd"
du -sx --block-size=1 "$chroot" | cut -f1 > "$image/casper/filesystem.size"
echo "MATE Wayland Desktop $release - amd64 ($(date +%Y%m%d))" > "$image/.disk/info"

cat > "$image/boot/grub/grub.cfg" <<GRUB
set default=0
set timeout=5

menuentry "Try or Install MATE Wayland Desktop" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}
menuentry "MATE Wayland Desktop (safe graphics)" {
    linux /casper/vmlinuz boot=casper nomodeset ---
    initrd /casper/initrd
}
GRUB

mkdir -p "$tools/mnt/work" "$tools/mnt/out"
mount -t proc proc "$tools/proc"
mount --bind "$work" "$tools/mnt/work"
mount --bind "$out" "$tools/mnt/out"

step "4/5 Compressing the system image"
in_root "$tools" mksquashfs /mnt/work/chroot /mnt/work/image/casper/filesystem.squashfs \
    -noappend -comp zstd -Xcompression-level 15 -e boot/efi

step "5/5 Writing the ISO"
# Hybrid image: boots from USB stick or DVD, on BIOS and UEFI machines.
# Not signed for Secure Boot.
in_root "$tools" grub-mkrescue -o "/mnt/out/$isoname" /mnt/work/image \
    -- -volid "MWD_$(echo "$release" | tr . _)"
unmount_under "$tools"

# The ISO belongs to the person who ran sudo, not to root.
if [ -n "${SUDO_UID:-}" ]; then
    chown "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$iso"
fi

ls -lh "$iso"
step "Done: $iso"
