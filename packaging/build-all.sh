#!/bin/sh
# Builds every package this project ships into packaging/build/:
# the MATE components listed in packaging/packages.conf, and our own
# mate-wayland-desktop package.
#
# Usage: sudo packaging/build-all.sh [--fresh]
#
# Works on any Linux host with debootstrap. The builds run inside an Ubuntu
# system kept in iso/cache/builder, isolated from the host (see
# lib/ubuntu-root.sh); nothing is installed on the host. --fresh recreates
# that build system first.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
top=$(dirname "$here")
suite=${SUITE:-resolute}
mirror=${MIRROR:-http://archive.ubuntu.com/ubuntu}
cache="$top/iso/cache"
builder="$cache/builder"
. "$top/lib/ubuntu-root.sh"
isolate "$0" "$@"

fresh=0
for arg in "$@"; do
    case "$arg" in
        --fresh) fresh=1 ;;
        *) die "Unknown option: $arg" ;;
    esac
done

trap 'unmount_under "$builder"' EXIT
find_keyring

if [ "$fresh" -eq 1 ] || [ ! -f "$builder/.ready-$suite" ]; then
    safe_rm "$builder"
    mkdir -p "$builder"
    bootstrap "$builder"
    write_sources "$builder" "deb deb-src"
    mount_system "$builder"
    in_root "$builder" apt-get update
    in_root "$builder" apt-get -y install --no-install-recommends \
        build-essential dpkg-dev devscripts fakeroot curl ca-certificates patch
    unmount_under "$builder"
    touch "$builder/.ready-$suite"
fi

mount_system "$builder"
mkdir -p "$builder/src"
mount --bind "$top" "$builder/src"
in_root "$builder" apt-get update

mkdir -p "$here/build"
revision=$(cat "$here/revision")
if [ "$fresh" -eq 1 ]; then
    find "$here/build" -mindepth 1 -maxdepth 1 ! -name '*.tar.xz' -exec rm -rf {} +
fi

# build/<name>.built records which version of a component was built and the
# .deb files it produced. A component is rebuilt only when its version, our
# revision, or anything in packaging/<name>/ has changed.
grep -v '^#' "$here/packages.conf" | grep -v '^$' | while read -r name version; do
    want="$name $version-0mwd$revision $(cat "$here/$name"/adjust.sh "$here/$name"/patches/*.patch 2>/dev/null | sha256sum | cut -c1-16)"
    stamp="$here/build/$name.built"
    if [ "$(head -n 1 "$stamp" 2>/dev/null)" = "$want" ]; then
        echo "== $name $version is already built"
    else
        echo "== Building $name $version"
        # Remove what an earlier build of this component produced, so an
        # ISO never picks up packages from two versions.
        if [ -f "$stamp" ]; then
            sed 1d "$stamp" | while read -r f; do rm -f "$here/build/$f"; done
            rm -f "$stamp"
        fi
        in_root "$builder" /src/packaging/build-package.sh "$name" "$version" </dev/null
        { echo "$want"
          sed -n '/^Files:/,$p' "$here/build/${name}_$version-0mwd${revision}_amd64.changes" |
              awk '{print $5}' | grep '\.deb$'
        } > "$stamp"
    fi
    # Later components are built against this one.
    debs=$(sed 1d "$stamp" | sed 's|^|/src/packaging/build/|' | tr '\n' ' ')
    in_root "$builder" sh -c "apt-get -y install $debs" </dev/null
done

in_root "$builder" /src/packaging/build-session-deb.sh </dev/null

# The results belong to the person who ran sudo, not to root.
if [ -n "${SUDO_UID:-}" ]; then
    chown -R "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$here/build"
fi
ls "$here"/build/*.deb
