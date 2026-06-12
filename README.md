# libfprint support for the ELAN `04f3:0c77` fingerprint sensor

![status: working](https://img.shields.io/badge/status-working-brightgreen)
![license: LGPL-2.1+](https://img.shields.io/badge/license-LGPL--2.1%2B-blue)
![tested: Ubuntu 26.04](https://img.shields.io/badge/tested-Ubuntu%2026.04-orange)
[![latest release](https://img.shields.io/github/v/release/Alexys829/elan-0c77-libfprint)](https://github.com/Alexys829/elan-0c77-libfprint/releases/latest)

Patches that make the **ELAN `04f3:0c77`** fingerprint reader
("ELAN:ARM-M4", Match-on-Chip, firmware `0x312` / 3.18) work on Linux. The reader
ships in some **ASUS ExpertBook** laptops and is **not** supported by stock
libfprint. These patches teach libfprint's `elanmoc` driver to drive it: **enroll,
verify and PAM fingerprint login all work**.

Tested on **Ubuntu 26.04 (resolute), libfprint 1.95.1+tod1**. The patches are small
and re-apply cleanly on other versions — see [Build from source](#build-from-source).

> No proprietary blob is required. There is **no** `libfprint-2-tod1-elan` package
> (it has never existed in the Ubuntu archive); ignore any guide that tells you to
> install one.

## Compatibility

| Item | Value |
|---|---|
| USB ID | `04f3:0c77` |
| Chip | ELAN:ARM-M4, Match-on-Chip |
| Firmware | `0x312` (3.18) |
| Laptop | ASUS ExpertBook (and likely siblings with the same module) |
| Tested on | Ubuntu 26.04, libfprint `1.95.1+tod1` |
| Other versions | Use [Build from source](#build-from-source) — the patches re-apply cleanly |

The prebuilt `.deb`s ([Releases](https://github.com/Alexys829/elan-0c77-libfprint/releases/latest)
or [`prebuilt/`](prebuilt/)) match libfprint **1.95.1+tod1** only; on any other version,
build from source.

---

## Table of contents

- [Quick start](#quick-start)
- [Install (prebuilt .deb)](#install-prebuilt-deb)
- [Build from source](#build-from-source)
- [Hold the packages (important)](#hold-the-packages-important)
- [Enroll a finger and enable fingerprint login](#enroll-a-finger-and-enable-fingerprint-login)
- [Increase the number of retries](#increase-the-number-of-retries)
- [Fingerprint for sudo](#fingerprint-for-sudo)
- [Keyring / password managers](#keyring--password-managers)
- [Dual boot with Windows (important)](#dual-boot-with-windows-important)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Upstreaming](#upstreaming)
- [Credits & license](#credits--license)

---

## Quick start

If you run **Ubuntu 26.04** (libfprint `1.95.1+tod1` — check with `dpkg -l libfprint-2-2`):

```bash
./install.sh            # installs the prebuilt .debs and holds them
fprintd-enroll          # register a finger
fprintd-verify          # should print: verify-match
sudo pam-auth-update    # tick "Fingerprint authentication" for login/sudo
```

On any other libfprint version, use [`./build.sh`](#build-from-source) instead.

## Install (prebuilt .deb)

**From a clone** — `install.sh` installs the two `.deb` files from
[`prebuilt/`](prebuilt/), pins them with `apt-mark hold` so updates can't overwrite
them, and restarts `fprintd`:

```bash
git clone https://github.com/Alexys829/elan-0c77-libfprint.git
cd elan-0c77-libfprint
./install.sh
```

**Without cloning** — grab the two packages from the
[latest release](https://github.com/Alexys829/elan-0c77-libfprint/releases/latest)
and install them directly:

```bash
gh release download -R Alexys829/elan-0c77-libfprint \
  -p 'libfprint-2-2_*.deb' -p 'libfprint-2-tod1_*.deb'
sudo dpkg -i libfprint-2-2_*.deb libfprint-2-tod1_*.deb
sudo apt-mark hold libfprint-2-2 libfprint-2-tod1
sudo systemctl restart fprintd
```

The prebuilt packages only match libfprint **1.95.1+tod1**. If your version differs,
`dpkg` will refuse or the ABI won't match — build from source instead.

## Build from source

Robust on any release: it fetches your distro's libfprint source, re-applies the
patches and rebuilds matching `.deb` files.

```bash
./build.sh                       # produces .debs in ~/elan-0c77-build/
sudo dpkg -i ~/elan-0c77-build/libfprint-2-2_*.deb \
             ~/elan-0c77-build/libfprint-2-tod1_*.deb
sudo apt-mark hold libfprint-2-2 libfprint-2-tod1
sudo systemctl restart fprintd
```

`build.sh` enables `deb-src` sources, installs the build dependencies, applies the
quilt patches from [`patches/`](patches/), and builds with the test suite disabled
(the unrelated `udev-hwdb` test fails and would otherwise abort the build).

Set `DEBEMAIL` / `DEBFULLNAME` first if you want your name in the changelog entry.

## Hold the packages (important)

Without a hold, the next `apt upgrade` reinstalls the stock libfprint and the sensor
**stops working**:

```bash
sudo apt-mark hold libfprint-2-2 libfprint-2-tod1
```

To update libfprint later, `unhold`, upgrade, then rebuild from source and re-hold:

```bash
sudo apt-mark unhold libfprint-2-2 libfprint-2-tod1
```

## Enroll a finger and enable fingerprint login

```bash
fprintd-enroll          # press/lift the finger at each prompt (~10 times)
fprintd-verify          # expect: Verify result: verify-match (done)
sudo pam-auth-update    # tick "Fingerprint authentication" (space), then OK
```

After `pam-auth-update`, the graphical login, the lock screen and `sudo` accept the
fingerprint, falling back to the password if you don't use it.

## Increase the number of retries

By default the PAM profile allows **a single** attempt (`max-tries=1`). To raise it to
5 permanently (survives package updates, because it edits the pam-auth-update template):

```bash
sudo sed -i 's/max-tries=1 timeout=10 # debug/max-tries=5 timeout=15/' /usr/share/pam-configs/fprintd
sudo pam-auth-update --force
grep fprintd /etc/pam.d/common-auth      # verify: max-tries=5 timeout=15
```

`max-tries` = failed scans before falling back to the password; `timeout` = seconds to
wait for a finger per request.

## Fingerprint for sudo

Works automatically once `pam-auth-update` has enabled fingerprint auth: `sudo` includes
`common-auth`, which contains `pam_fprintd`. Test it:

```bash
sudo -k && sudo echo "authenticated by fingerprint"
```

## Keyring / password managers

Unlocking the **login keyring** (KWallet on KDE, GNOME Keyring on GNOME) with the
fingerprint alone is **not possible by design**: the keyring is encrypted with a key
derived from your *password*, and a fingerprint carries no such secret. If you log in
with the finger, the keyring stays locked until you type the password once.

For biometric unlock of a **password manager**, the ones that work on Linux are those
whose desktop app uses system authentication (polkit → PAM → fprintd), e.g.
**Bitwarden** and **1Password** — the browser extension unlocks through the desktop app.
**NordPass** does **not** offer biometric unlock on Linux (only Windows/macOS/mobile),
so there it's master password / PIN only.

## Dual boot with Windows (important)

Every time you use **Windows Hello**, Windows leaves the chip in *VBS WBF mode*
(protected), in which any Linux verify fails with chip code `0xfd "finger not enrolled"`
— even against a template Windows itself matches. The hardware is fine, the mode is
wrong. The patches send `set_mode 0x00` (normal WBF) on every device open, so Linux
self-corrects; if the first verify after Windows misbehaves, **just try again**.

Manual reset (needs the [elanpoc](https://github.com/depau/elanpoc) tool):

```bash
# 40 ff 14 = set-mode, 00 = normal WBF. Expected reply: "40 00".
uv run elanfp raw -e 3 40 ff 14 00
```

## How it works

The chip speaks the `elanmoc` protocol, but firmware `0x312` uses a different opcode
subset from the upstream-supported `0c7d`+ sensors. The protocol was confirmed against
[depau/elanpoc](https://github.com/depau/elanpoc), a userspace PoC that talks to the
chip directly. Key differences handled by the patches:

| Operation | Upstream elanmoc | This chip (`0c77`) |
|---|---|---|
| verify | `40 ff 73` | `40 ff 03` |
| remove-all (clear) | `40 ff 98` | `40 ff 99` |
| re-enroll check | `40 ff 22` | not supported → skipped when empty |
| get-userid after match | `40 ff 73` | not supported → skipped, report match directly |
| sensor mode at open / verify | set-mode `0x03` | set-mode **`0x00`** (normal WBF) |

The two non-obvious fixes:

1. **Normal WBF mode.** Windows leaves the chip in VBS WBF mode where the on-chip
   matcher refuses userspace verifies (`0xfd`). Sending set-mode (`40 ff 14`) value
   `0x00` puts it back into normal mode so enroll/verify match.
2. **No get-userid after match.** After a successful match the stock driver issues a
   get-userid command to learn which finger matched; this FW doesn't implement it, so
   the read times out after 5 s and then crashes
   (`fpi_ssm_mark_failed: assertion 'machine != NULL' failed`). For this device the
   on-chip match is authoritative, so the result is reported directly.

The PID is tagged `driver_data = ELANMOC_PROTO_V2`; every change is gated on that flag,
so other ELAN PIDs are unaffected.

See [`patches/`](patches/) for the six quilt patches (order in
[`patches/series`](patches/series)).

## Troubleshooting

- **`fprintd-verify` seems to hang** — it's waiting for a finger. Press and lift, more
  than once if needed.
- **Always "no-match" with the correct finger** — the chip is probably in VBS mode after
  Windows; see [Dual boot](#dual-boot-with-windows-important). Restart `fprintd` or run
  the manual reset.
- **`Device was already claimed`** — a previous verify process is stuck:
  `sudo systemctl restart fprintd`.
- **Stopped working after `apt upgrade`** — the hold was dropped; reinstall the `.debs`
  and re-run `apt-mark hold`, or rebuild with `build.sh`.
- **Sensor missing from `lsusb`** — enable it in the BIOS/UEFI.

## Uninstall

Revert to the stock Ubuntu libfprint:

```bash
./uninstall.sh
```

This removes the hold and reinstalls the official packages from the archive.

## Upstreaming

These patches hardcode the behaviour behind a single PID flag. Proper upstreaming would
generalise `ELANMOC_PROTO_V2` (mode + opcode subset) and submit it to
[libfprint](https://gitlab.freedesktop.org/libfprint/libfprint). Contributions welcome.

## Credits & license

- Protocol reverse-engineering reference: [depau/elanpoc](https://github.com/depau/elanpoc)
  and the `elanmoc2` work in [depau/libfprint](https://gitlab.freedesktop.org/depau/libfprint).
- libfprint is **LGPL-2.1-or-later**; these patches modify that code and are provided
  under the same license. See [LICENSE](LICENSE).
