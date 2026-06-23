#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "This uninstaller must run as root." >&2
    exit 1
fi

systemctl disable --now luna-usb-adb.service 2>/dev/null || true
systemctl disable --now luna-root-adbd.service 2>/dev/null || true

GADGET=/sys/kernel/config/usb_gadget/g1
CONFIG="$GADGET/configs/c.1"
old_udc="$(cat "$GADGET/UDC" 2>/dev/null || true)"

if [ -n "$old_udc" ]; then
    printf '\n' > "$GADGET/UDC" 2>/dev/null || true
fi

rm -f "$CONFIG/ffs.adb"

if [ -n "$old_udc" ]; then
    printf '%s' "$old_udc" > "$GADGET/UDC" 2>/dev/null || true
fi

rm -f /etc/systemd/system/luna-root-adbd.service
rm -f /etc/systemd/system/luna-usb-adb.service
rm -rf /data/luna-adb

systemctl daemon-reload
systemctl enable adbd.service 2>/dev/null || true

echo "Persistent root ADB services removed."
