#!/bin/sh
set -u

GADGET=/sys/kernel/config/usb_gadget/g1
CONFIG="$GADGET/configs/c.1"
FUNCTION="$GADGET/functions/ffs.adb"
FUNCTIONFS=/dev/usb-ffs/adb

mkdir -p "$FUNCTIONFS"

if ! mountpoint -q "$FUNCTIONFS"; then
    mount -t functionfs -o uid=2000,gid=2000 adb "$FUNCTIONFS" || true
fi

while true; do
    if [ -d "$GADGET" ] && [ -d "$CONFIG" ] && [ -d "$FUNCTION" ]; then
        current_udc="$(cat "$GADGET/UDC" 2>/dev/null || true)"

        if [ ! -L "$CONFIG/ffs.adb" ]; then
            if [ -n "$current_udc" ]; then
                printf '\n' > "$GADGET/UDC" 2>/dev/null || true
            fi

            ln -s "$FUNCTION" "$CONFIG/ffs.adb" 2>/dev/null || true

            if [ -n "$current_udc" ]; then
                printf '%s' "$current_udc" > "$GADGET/UDC" 2>/dev/null || true
            fi
        fi

        current_udc="$(cat "$GADGET/UDC" 2>/dev/null || true)"
        if [ -z "$current_udc" ]; then
            available_udc="$(ls -1 /sys/class/udc 2>/dev/null | head -n 1)"
            if [ -n "$available_udc" ]; then
                printf '%s' "$available_udc" > "$GADGET/UDC" 2>/dev/null || true
            fi
        fi
    fi

    sleep 2
done
