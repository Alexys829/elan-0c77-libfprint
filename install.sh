#!/usr/bin/env bash
# Install the prebuilt .debs for the ELAN 04f3:0c77 sensor and pin them
# against updates. Works if your libfprint is 1.95.1+tod1 (Ubuntu 26.04 /
# resolute). Otherwise use build.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! lsusb 2>/dev/null | grep -qi '04f3:0c77'; then
  echo "WARNING: sensor 04f3:0c77 not found in lsusb. Make sure it is enabled in the BIOS." >&2
fi

echo ">> Installing the prebuilt .debs"
sudo dpkg -i "$HERE"/prebuilt/libfprint-2-2_*.deb "$HERE"/prebuilt/libfprint-2-tod1_*.deb

echo ">> Holding the packages (apt won't overwrite the patched libfprint)"
sudo apt-mark hold libfprint-2-2 libfprint-2-tod1

echo ">> Restarting fprintd"
sudo systemctl restart fprintd

echo
echo ">> Done. Next:"
echo "     fprintd-enroll          # register a finger"
echo "     fprintd-verify          # should print: verify-match"
echo "     sudo pam-auth-update    # tick 'Fingerprint authentication' for login/sudo"
