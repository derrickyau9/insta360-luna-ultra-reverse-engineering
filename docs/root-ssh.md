# Persistent Root SSH

This document describes the root SSH configuration currently installed on the analyzed Luna Ultra.

If SSH has not been installed yet, first obtain a temporary root shell using the [Wi-Fi bootstrap procedure](wifi-root-shell.md). That temporary shell is the initial installation channel for persistent SSH and ADB.

## Quick login

Connect the computer to the camera Wi-Fi, then run:

```sh
ssh luna
```

The local alias resolves to:

```sshconfig
Host luna luna-ultra
    HostName 192.168.42.1
    User root
    IdentityFile C:/Users/derri/.ssh/luna_ultra_root_ed25519
    IdentitiesOnly yes
    UserKnownHostsFile C:/Users/derri/.ssh/luna_ultra_known_hosts
```

The equivalent command without an alias is:

```sh
ssh -i ~/.ssh/luna_ultra_root_ed25519 root@192.168.42.1
```

Expected result:

```text
uid=0(root) gid=0(root)
hostname: pineapple
```

## Client key

The tested client key is a dedicated Ed25519 key:

```text
Private key: C:\Users\derri\.ssh\luna_ultra_root_ed25519
Public key:  C:\Users\derri\.ssh\luna_ultra_root_ed25519.pub
Fingerprint: SHA256:fTOkjEVB/wfafb4r/w4dMzU4M3fTPdaOLfY8zMUyL5w
```

The private key is intentionally excluded by `.gitignore`. Back it up securely and never publish it.

## Server architecture

The firmware includes `/usr/sbin/sshd`, reported as OpenSSH `10.0`, but the package is incomplete. It is missing the mandatory split executables:

```text
/usr/libexec/sshd-session
/usr/libexec/sshd-auth
```

The bundled OpenSSH listener therefore cannot complete a client connection. The persistent server uses Dropbear `2026.91` with Alpine aarch64 musl libraries instead.

Installed layout:

```text
/data/luna-ssh/
|-- alpine/
|   |-- lib/ld-musl-aarch64.so.1
|   |-- lib/libc.musl-aarch64.so.1
|   |-- usr/lib/libskarnet.so.2.15
|   |-- usr/lib/libutmps.so.0.1
|   |-- usr/lib/libz.so.1
|   |-- usr/bin/dropbearkey
|   `-- usr/sbin/dropbear
|-- dropbear_ed25519_host_key
`-- apks/
```

The packages were sourced from the official Alpine aarch64 `latest-stable/main` repository.

## systemd service

The installed unit is included at [`device/luna-root-ssh.service`](../device/luna-root-ssh.service).

Runtime command:

```text
dropbear -F -E -s -g -p 0.0.0.0:22 -r /data/luna-ssh/dropbear_ed25519_host_key
```

Important flags:

| Flag | Meaning |
| --- | --- |
| `-F` | Remain in the foreground for systemd |
| `-E` | Log to standard error |
| `-s` | Disable password logins |
| `-g` | Disable password logins for root |
| `-p 0.0.0.0:22` | Listen on TCP port 22 |
| `-r` | Use the persistent Ed25519 server host key |

Check the service:

```sh
systemctl is-enabled luna-root-ssh.service
systemctl is-active luna-root-ssh.service
systemctl status luna-root-ssh.service --no-pager
```

The verified state is `enabled` and `active`.

## Remote account layout

```text
User:             root
UID/GID:          0/0
Home:             /data/root
Shell:            /bin/sh
Authorized keys:  /data/root/.ssh/authorized_keys
```

Permissions should be:

```text
/data/root                         0700 root:root
/data/root/.ssh                    0700 root:root
/data/root/.ssh/authorized_keys    0600 root:root
```

## Adding another computer

Generate a new key on that computer:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/luna_ultra_root_ed25519 -C luna-ultra-root
```

Use an existing trusted SSH or root ADB session to append the new public key:

```sh
adb connect 192.168.42.1:5555
adb -s 192.168.42.1:5555 push ~/.ssh/luna_ultra_root_ed25519.pub /tmp/luna_new_key.pub
adb -s 192.168.42.1:5555 shell \
  'cat /tmp/luna_new_key.pub >> /data/root/.ssh/authorized_keys && chmod 600 /data/root/.ssh/authorized_keys'
```

Do not copy a private key through ADB or commit it to Git.

## File transfer

This Dropbear deployment does not expose the SFTP server path expected by current Windows OpenSSH clients. Modern `scp` defaults to SFTP and may fail with a message such as:

```text
/usr/lib/ssh/sftp-server: not found
```

Use legacy SCP mode instead:

```sh
scp -O local-file luna:/data/root/
scp -O luna:/data/root/remote-file .
```

ADB is also suitable for file transfer:

```sh
adb -s 192.168.42.1:5555 push local-file /data/root/
adb -s 192.168.42.1:5555 pull /data/root/remote-file .
```

## Troubleshooting

### Connection refused

Use root ADB to check the service and listener:

```sh
adb connect 192.168.42.1:5555
adb -s 192.168.42.1:5555 shell \
  'systemctl restart luna-root-ssh.service; netstat -lntp | grep :22'
```

### Permission denied

Verify that the intended public key is present and that permissions are strict:

```sh
adb -s 192.168.42.1:5555 shell \
  'ls -ld /data/root /data/root/.ssh; ls -l /data/root/.ssh/authorized_keys'
```

### Host key changed

The dedicated known-hosts file can be reset with:

```sh
ssh-keygen -R 192.168.42.1 -f ~/.ssh/luna_ultra_known_hosts
```

Reconnect only after confirming that the host key change was expected.

### Service logs

```sh
journalctl -u luna-root-ssh.service --no-pager -n 100
```

Some firmware builds do not retain a full systemd journal. In that case, restart the service and inspect `systemctl status` immediately.

## Persistence and recovery

The service unit resides in the writable `/etc` overlay, while the Dropbear installation, host key, home directory, and authorized keys reside under persistent `/data` storage.

The configuration is designed to survive a normal reboot. At the time this document was written, the service was verified as enabled and active, but a deliberate full reboot-cycle test had not been performed.

If SSH fails, persistent root ADB on port `5555` is the preferred recovery channel.
