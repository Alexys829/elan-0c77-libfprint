#!/usr/bin/env bash
# Revert to the stock Ubuntu libfprint: drop the hold and reinstall the
# official packages from the archive.
set -euo pipefail

echo ">> Removing the package hold"
sudo apt-mark unhold libfprint-2-2 libfprint-2-tod1 || true

echo ">> Reinstalling the stock libfprint from the archive"
sudo apt update
sudo apt install --reinstall --allow-downgrades -y libfprint-2-2 libfprint-2-tod1

echo ">> Restarting fprintd"
sudo systemctl restart fprintd

echo
echo ">> Done. The sensor will no longer work until you reinstall the patched build."
