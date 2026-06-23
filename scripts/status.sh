#!/bin/sh
set -u

echo "Service state"
systemctl is-enabled luna-root-adbd.service luna-usb-adb.service 2>/dev/null || true
systemctl is-active luna-root-adbd.service luna-usb-adb.service 2>/dev/null || true

echo
echo "ADB properties"
for property in \
    ro.adb.secure \
    ro.debuggable \
    service.adb.root \
    service.adb.tcp.port \
    persist.adb.tcp.port
do
    printf '%s=%s\n' "$property" "$(getprop "$property")"
done

echo
echo "TCP listener"
netstat -lntp 2>/dev/null | grep ':5555' || true

echo
echo "USB gadget functions"
ls -la /sys/kernel/config/usb_gadget/g1/configs/c.1 2>/dev/null || true
printf 'UDC=%s\n' "$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null || true)"
