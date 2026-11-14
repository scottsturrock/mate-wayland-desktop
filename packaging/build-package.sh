#!/bin/sh
# Builds one newer upstream MATE release as Ubuntu packages, reusing
# Ubuntu's own packaging for that component.
#
# Runs inside the Ubuntu build system that packaging/build-all.sh sets up;
# do not run it on the host.
#
# Usage: build-package.sh <name> <version>
#   e.g. build-package.sh mate-panel 1.29.2
# Output: .deb files in packaging/build/
set -eu

name=$1
version=$2
here=$(cd "$(dirname "$0")" && pwd)
build="$here/build"
revision=$(cat "$here/revision")
tarball="$name-$version.tar.xz"
url="https://github.com/mate-desktop/$name/releases/download/v$version/$tarball"

# uupdate stops for a keypress unless it knows who the packager is.
export DEBEMAIL=build@mate-wayland-desktop.invalid
export DEBFULLNAME="mate-wayland-desktop build"

mkdir -p "$build"
cd "$build"
rm -rf "$name"-*/

apt-get build-dep -y "$name"

# Ubuntu's packaging, then swap in the newer upstream source.
apt-get source "$name"
[ -f "$tarball" ] || curl -fL -o "$tarball" "$url"
old=$(ls -d "$name"-*/ | head -1)
(cd "$old" && uupdate --no-symlink -v "$version" "../$tarball" </dev/null)
cd "$name-$version"

# Our builds carry our own version suffix, so they are never mistaken for
# Ubuntu's packages: <upstream>-0mwd<revision>.
sed -i "1s/($version-[^)]*)/($version-0mwd$revision)/" debian/changelog
head -1 debian/changelog | grep -q "($version-0mwd$revision)"

# Ubuntu's patches were written for the old version.
rm -rf debian/patches

# Newer releases add files and library symbols the old packaging does not
# list; do not fail the build over them.
sed -i 's/dh_missing --fail-missing/dh_missing --list-missing/' debian/rules
rm -f debian/*.symbols

# Per-component build options and file lists.
if [ -f "$here/$name/adjust.sh" ]; then
    . "$here/$name/adjust.sh"
fi

# Our code patches (to be offered upstream).
for p in "$here/$name"/patches/*.patch; do
    [ -f "$p" ] || continue
    echo "Applying $(basename "$p")"
    patch -p1 < "$p"
done

DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -b -uc -us
echo "Packages are in $build"
