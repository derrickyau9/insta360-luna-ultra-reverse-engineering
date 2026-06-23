# Insta360 Luna Ultra Reverse Engineering

Reverse-engineering notes, device configuration, persistent root SSH, and persistent root ADB services for the Insta360 Luna Ultra (`z03`) developer environment.

Tested on firmware `1.0.47` with the Qualcomm QCS8625 Linux platform.
<img width="1702" height="1276" alt="demo" src="https://github.com/user-attachments/assets/a308b71c-76bf-41bd-99d6-3e63c8c1b3d6" />

## Quick access

Connect the computer to the camera Wi-Fi first. The tested camera address is `192.168.42.1`.

Initial temporary root shell over Wi-Fi, before SSH or ADB is installed:

```sh
python scripts/wifi-root-shell.py
```

Root SSH, using the local alias installed during setup:

```sh
ssh luna
```

Root wireless ADB:

```sh
adb connect 192.168.42.1:5555
adb -s 192.168.42.1:5555 shell
```

Both methods have been verified to return `uid=0(root)`.

## Documentation

- [Device configuration](docs/device-configuration.md): SoC, CPU, memory, storage, camera hardware, display, battery, firmware layout, services, and ports.
- [Wi-Fi bootstrap root shell](docs/wifi-root-shell.md): the port `23456` INSGUI protocol, exact command format, automatic helper, and manual procedure.
- [Root SSH access](docs/root-ssh.md): login commands, key layout, Dropbear architecture, persistence, recovery, and troubleshooting.
- [Persistent root ADB](docs/root-adb.md): wireless and USB ADB design, verification, service behavior, and security implications.

## Features

- Starts `adbd` as root on every boot.
- Enables wireless ADB on TCP port `5555`.
- Keeps the USB FunctionFS ADB function in the active USB gadget configuration.
- Preserves the existing USB mass-storage function.
- Automatically binds the USB gadget when a UDC becomes available.
- Documents the persistent key-only root SSH installation on TCP port `22`.
- Includes a dependency-free Wi-Fi bootstrap helper for obtaining the initial temporary root shell through developer mode.
- Includes install, uninstall, status, and Windows connection helpers for ADB and SSH.

## Security warning

Wireless ADB authentication is disabled and exposes a root shell to every client that can reach TCP port `5555`. SSH is safer because password authentication is disabled and a dedicated Ed25519 key is required. Only use these services on a trusted camera Wi-Fi network.

Never commit a private SSH key to this repository.

## Device requirements

- Insta360 Luna Ultra / project `z03`.
- Existing root shell access.
- `/sbin/adbd`, `systemd`, ConfigFS, and `/sys/kernel/config/usb_gadget/g1`.
- Writable persistent overlays for `/etc` and `/data`.

## Install

Copy this repository to the camera, enter a root shell, then run:

```sh
chmod +x scripts/*.sh device/enable-usb-adb.sh
./scripts/install.sh
```

The installer enables:

```text
luna-root-adbd.service
luna-usb-adb.service
```

## Wireless ADB

From a computer connected to the camera Wi-Fi:

```sh
adb connect 192.168.42.1:5555
adb -s 192.168.42.1:5555 shell
```

Expected identity:

```text
uid=0(root) gid=0(root)
```

On Windows, the helper can be used instead:

```powershell
.\scripts\connect.ps1
```

## USB ADB

The USB watcher adds `ffs.adb` to the existing ConfigFS gadget and binds it whenever a USB Device Controller appears. The existing mass-storage function is retained.

Windows may require a WinUSB-compatible ADB driver for the new interface.

## Root SSH

The camera runs Dropbear `2026.91` as a persistent, key-only root SSH server:

```sh
ssh luna
```

Without the local alias:

```sh
ssh -i ~/.ssh/luna_ultra_root_ed25519 root@192.168.42.1
```

See [Root SSH access](docs/root-ssh.md) for the complete configuration and recovery procedure.

## Repository layout

```text
device/   Device-side scripts and systemd units
docs/     Hardware, firmware, SSH, and ADB documentation
scripts/  Installation, status, uninstall, and connection helpers
```

## Status

```sh
./scripts/status.sh
```

## Uninstall

```sh
./scripts/uninstall.sh
```

The uninstall script stops and removes both custom services, removes the ADB gadget link, and re-enables the vendor `adbd.service` without starting it.

## Tested state

```text
Wireless endpoint: 192.168.42.1:5555
ADB identity:       uid=0(root)
SELinux domain:     unconfined_t
Root ADB service:   enabled, active
USB ADB watcher:    enabled, active
Root SSH service:   enabled, active
```

## Author

Derrick Yao
