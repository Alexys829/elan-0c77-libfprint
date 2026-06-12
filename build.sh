#!/usr/bin/env bash
# Rebuild libfprint with the ELAN 04f3:0c77 patches.
# Use this when the prebuilt .debs in prebuilt/ don't match your libfprint
# version (e.g. after a new Ubuntu release).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${1:-$HOME/elan-0c77-build}"

echo ">> Enabling source repos (deb-src) and installing build tools"
if ! grep -rq '^Types:.*deb-src' /etc/apt/sources.list.d/ 2>/dev/null; then
  sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
fi
sudo apt update
sudo apt build-dep -y libfprint-2-2
sudo apt install -y devscripts quilt dpkg-dev fakeroot meson ninja-build

echo ">> Fetching the libfprint source into $WORK"
mkdir -p "$WORK"; cd "$WORK"
apt source libfprint
SRCDIR="$(find . -maxdepth 1 -type d -name 'libfprint-*' | head -1)"
cd "$SRCDIR"

echo ">> Applying the patches"
mkdir -p debian/patches
cp "$HERE"/patches/elanmoc-*.patch debian/patches/
# append our patches to the existing series (if any), without duplicates
for p in $(cat "$HERE"/patches/series); do
  grep -qxF "$p" debian/patches/series 2>/dev/null || echo "$p" >> debian/patches/series
done
QUILT_PATCHES=debian/patches quilt push -a

echo ">> Bumping version and building (the udev-hwdb test fails and is skipped)"
DEBEMAIL="${DEBEMAIL:-you@example.com}" DEBFULLNAME="${DEBFULLNAME:-Local Build}" \
  dch --local "+elan0c77" --distribution "$(lsb_release -cs)" \
  "Local rebuild with ELAN 04f3:0c77 elanmoc patches."
DEB_BUILD_OPTIONS=nocheck debuild -us -uc -b

echo
echo ">> Done. The .debs are in: $WORK"
ls -1 "$WORK"/libfprint-2-2_*.deb "$WORK"/libfprint-2-tod1_*.deb
echo ">> Install with: sudo dpkg -i <the two .debs above> && sudo apt-mark hold libfprint-2-2 libfprint-2-tod1"
