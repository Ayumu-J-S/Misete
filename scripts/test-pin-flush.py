#!/usr/bin/env python3
"""Regression test: UxPlay must promptly flush the AirPlay PIN marker to stdout."""

from __future__ import annotations

import os
import re
import select
import signal
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UXPLAY = ROOT / ".deps" / "uxplay" / "bin" / "uxplay"
SERVICE_PORT = 35011
PORT_RANGE = "35010"
PIN_MARKER = re.compile(rb'CLIENT MUST NOW ENTER PIN = "[0-9]{4}" AS AIRPLAY PASSWORD')
MAX_OUTPUT_BYTES = 64 * 1024


def drain(fd: int, limit: int) -> bytes:
    chunks: list[bytes] = []
    remaining = limit
    while remaining and select.select([fd], [], [], 0)[0]:
        chunk = os.read(fd, min(4096, remaining))
        if not chunk:
            break
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def confirm_isolated_port_range_is_available() -> None:
    sockets: list[socket.socket] = []
    try:
        for port in range(35010, 35013):
            for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
                candidate = socket.socket(socket.AF_INET, kind)
                candidate.bind(("127.0.0.1", port))
                sockets.append(candidate)
    except OSError as error:
        raise RuntimeError("isolated AirPlay test port range 35010-35012 is already in use") from error
    finally:
        for candidate in sockets:
            candidate.close()


def post_pair_pin_start() -> None:
    request = b"POST /pair-pin-start RTSP/1.0\r\nCSeq: 1\r\nContent-Length: 0\r\n\r\n"
    deadline = time.monotonic() + 5
    while True:
        try:
            with socket.create_connection(("127.0.0.1", SERVICE_PORT), timeout=0.5) as connection:
                connection.sendall(request)
                connection.recv(1024)
                return
        except OSError:
            if time.monotonic() >= deadline:
                raise RuntimeError("UxPlay did not open the isolated AirPlay service port")
            time.sleep(0.05)


def main() -> int:
    if not UXPLAY.is_file() or not os.access(UXPLAY, os.X_OK):
        raise RuntimeError("pinned UxPlay is missing; run scripts/setup-receiver.sh")
    confirm_isolated_port_range_is_available()

    with tempfile.TemporaryDirectory(prefix="misete-pin-flush-") as temporary:
        command = [
            str(UXPLAY), "-n", "Misete-Pin-Flush", "-nh", "-p", PORT_RANGE,
            "-pin", "-d", "1", "-vs", "0", "-reg", str(Path(temporary) / "register"),
        ]
        child = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env={**os.environ, "UXPLAYRC": "/dev/null"},
            start_new_session=True,
        )
        assert child.stdout is not None
        try:
            post_pair_pin_start()
            deadline = time.monotonic() + 1
            output = bytearray()
            while time.monotonic() < deadline:
                output.extend(drain(child.stdout.fileno(), MAX_OUTPUT_BYTES - len(output)))
                if PIN_MARKER.search(output):
                    print("PIN marker reached the stdout pipe promptly.")
                    return 0
                if len(output) == MAX_OUTPUT_BYTES:
                    raise RuntimeError("UxPlay exceeded the bounded stdout capture")
                time.sleep(0.02)
            raise RuntimeError("PIN marker did not reach stdout within one second")
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
            try:
                child.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.communicate(timeout=5)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"PIN flush regression failed: {error}", file=sys.stderr)
        raise SystemExit(1)
