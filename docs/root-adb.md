# Persistent Root ADB

The analyzed camera runs a custom persistent root ADB service over both TCP and USB FunctionFS.

## Wireless access

```sh
adb connect 192.168.42.1:5555
adb -s 192.168.42.1:5555 shell
```

Verified identity:

```text
uid=0(root) gid=0(root)
context=system_u:system_r:unconfined_t:s0-s15:c0.c1023
```

Verified properties:

```text
ro.adb.secure=0
ro.debuggable=1
service.adb.root=1
service.adb.tcp.port=5555
persist.adb.tcp.port=5555
```

## Why the vendor service fails

The vendor `adbd.service` starts `/sbin/launch_adbd`. That script waits for `/dev/shm/ins_bbd_adb_shm.ins_shm` and only launches ADB when the shared-memory status is exactly `activate`. If the flag is unavailable or reports another state, the service exits and can hit the systemd start limit.

The custom `luna-root-adbd.service` bypasses that gate and starts `/sbin/adbd` directly after setting the root and TCP properties.

## Persistent services

```text
luna-root-adbd.service
luna-usb-adb.service
```

Check them with:

```sh
systemctl is-enabled luna-root-adbd.service luna-usb-adb.service
systemctl is-active luna-root-adbd.service luna-usb-adb.service
```

The tested state is `enabled` and `active` for both services.

## USB gadget behavior

The camera uses ConfigFS at:

```text
/sys/kernel/config/usb_gadget/g1
```

The original configuration contains the mass-storage function. The custom watcher adds:

```text
configs/c.1/ffs.adb -> functions/ffs.adb
```

It preserves mass storage, keeps FunctionFS mounted at `/dev/usb-ffs/adb`, and binds the gadget when a controller appears under `/sys/class/udc`.

When the camera is not in USB Device role, `/sys/class/udc` can be empty. The watcher remains active and binds ADB automatically when the UDC becomes available.

## Installation

From a root shell on the camera:

```sh
chmod +x scripts/*.sh device/enable-usb-adb.sh
./scripts/install.sh
```

## Status

```sh
./scripts/status.sh
```

## Uninstall

```sh
./scripts/uninstall.sh
```

## Security model

The custom service deliberately disables ADB authentication. Any host with network access to TCP port `5555` receives a root shell. Keep the camera Wi-Fi password private and do not bridge the camera AP to an untrusted LAN or the public Internet.
