#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must run as root." >&2
    exit 1
fi

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ ! -x /sbin/adbd ]; then
    echo "/sbin/adbd is missing or is not executable." >&2
    exit 1
fi

if [ ! -d /sys/kernel/config/usb_gadget/g1 ]; then
    echo "The expected ConfigFS gadget does not exist." >&2
    exit 1
fi

mkdir -p /data/luna-adb /etc/systemd/system
cp "$REPO_ROOT/device/enable-usb-adb.sh" /data/luna-adb/enable-usb-adb.sh
cp "$REPO_ROOT/device/luna-root-adbd.service" /etc/systemd/system/luna-root-adbd.service
cp "$REPO_ROOT/device/luna-usb-adb.service" /etc/systemd/system/luna-usb-adb.service

chmod 0755 /data/luna-adb/enable-usb-adb.sh
chmod 0644 /etc/systemd/system/luna-root-adbd.service
chmod 0644 /etc/systemd/system/luna-usb-adb.service

systemctl disable --now adbd.service 2>/dev/null || true
systemctl daemon-reload
systemctl enable --now luna-root-adbd.service
systemctl enable --now luna-usb-adb.service

echo "Persistent root ADB installation complete."
echo "Wireless endpoint: 192.168.42.1:5555"
systemctl is-active luna-root-adbd.service luna-usb-adb.service
