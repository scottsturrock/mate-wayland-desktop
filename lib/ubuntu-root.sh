# Shared by iso/build-iso.sh and packaging/build-all.sh (sourced, not run).
#
# Everything that needs Ubuntu (building packages, installing the system
# for the ISO, packing the image) happens inside Ubuntu system directories
# under iso/cache/ and iso/work/, so the build host can be any Linux with
# debootstrap. The host is protected as follows:
#   - Nothing is installed on the host.
#   - The build runs in private mount, process, hostname and IPC
#     namespaces. Its mounts are invisible to the host and vanish when it
#     ends; package scripts cannot see or signal host processes.
#   - The host's /dev and /sys are never made available inside, so no
#     package script can reach the host's disks or EFI variables.
#   - Nothing is deleted while anything is still mounted beneath it.
#
# Callers set: suite, mirror, cache.

die() { echo "$*" >&2; exit 1; }

# Re-run the calling script inside private namespaces: isolate "$0" "$@"
isolate() {
    [ "$(id -u)" -eq 0 ] || die "Run with sudo."
    for tool in debootstrap unshare chroot findmnt sha256sum; do
        command -v "$tool" >/dev/null || die "Missing on this machine: $tool"
    done
    if [ "${MWD_ISOLATED:-}" != 1 ]; then
        exec env MWD_ISOLATED=1 unshare --mount --propagation private \
            --pid --fork --kill-child --mount-proc --uts --ipc -- "$@"
    fi
}

in_root() { root=$1; shift; chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C "$@"; }

# Unmount everything mounted beneath a directory, deepest first.
unmount_under() {
    findmnt -rno TARGET | grep "^$1/" | sort -r | while read -r m; do
        umount -l "$m"
    done
}

# Delete a build directory, but never while something is mounted in it and
# never across a filesystem boundary.
safe_rm() {
    [ -e "$1" ] || return 0
    unmount_under "$1"
    if findmnt -rno TARGET | grep -q "^$1/"; then
        die "Refusing to delete $1: something is still mounted inside it."
    fi
    rm -rf --one-file-system "$1"
}

# Private /proc, terminals, /run and the download cache for a system
# directory. Deliberately no host /dev and no /sys.
mount_system() {
    mkdir -p "$cache/apt-archives"
    mount -t proc proc "$1/proc"
    mount -t devpts -o newinstance,ptmxmode=0666,mode=0620,gid=5 devpts "$1/dev/pts"
    mount -t tmpfs tmpfs "$1/dev/shm"
    mount -t tmpfs tmpfs "$1/run"
    mount --bind "$cache/apt-archives" "$1/var/cache/apt/archives"
}

# write_sources <root> [types]   (types: "deb" or "deb deb-src")
write_sources() {
    cat > "$1/etc/apt/sources.list.d/ubuntu.sources" <<SOURCES
Types: ${2:-deb}
URIs: $mirror
Suites: $suite $suite-updates $suite-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: ${2:-deb}
URIs: http://security.ubuntu.com/ubuntu/
Suites: $suite-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES
    rm -f "$1/etc/apt/sources.list"
}

# Do not start services while installing packages.
block_services() {
    printf '#!/bin/sh\nexit 101\n' > "$1/usr/sbin/policy-rc.d"
    chmod +x "$1/usr/sbin/policy-rc.d"
}

# The key that verifies Ubuntu's package archive. Ubuntu hosts have it
# installed; elsewhere it is unpacked from the distribution's
# ubuntu-keyring package into the cache, without installing anything.
find_keyring() {
    keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg
    [ -f "$keyring" ] && return 0
    keyring="$cache/keyring/ubuntu-archive-keyring.gpg"
    [ -f "$keyring" ] && return 0
    mkdir -p "$cache/keyring"
    tmp=$(mktemp -d)
    (cd "$tmp" && apt-get download ubuntu-keyring >/dev/null 2>&1 &&
        dpkg-deb --fsys-tarfile ubuntu-keyring_*.deb |
        tar -x ./usr/share/keyrings/ubuntu-archive-keyring.gpg) ||
        die "Cannot get the Ubuntu archive key. Put ubuntu-archive-keyring.gpg in $cache/keyring/."
    cp "$tmp/usr/share/keyrings/ubuntu-archive-keyring.gpg" "$keyring"
    rm -rf "$tmp"
}

# A minimal Ubuntu system in a directory.
bootstrap() {
    mkdir -p "$cache/debootstrap"
    debootstrap --arch=amd64 --variant=minbase --keyring="$keyring" \
        --cache-dir="$cache/debootstrap" \
        --components=main,restricted,universe,multiverse \
        "$suite" "$1" "$mirror"
    write_sources "$1"
    block_services "$1"
    rm -f "$1/etc/resolv.conf"
    cp /etc/resolv.conf "$1/etc/resolv.conf"
}
