#!/usr/bin/env python3
"""Bounded local smoke test for the pinned UxPlay binary and JPEG transport.

This uses no AirPlay client and is deliberately not real-device evidence.
"""

from __future__ import annotations

import os
import random
import signal
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UXPLAY = ROOT / ".deps" / "uxplay" / "bin" / "uxplay"
MAX_JPEG_BYTES = 1_024 * 1_024


def available_airplay_ports() -> tuple[int, int, int]:
    """Find three consecutive ports available for both TCP and UDP."""
    for _ in range(100):
        start = random.randint(40000, 55000)
        sockets: list[socket.socket] = []
        try:
            for port in range(start, start + 3):
                for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
                    candidate = socket.socket(socket.AF_INET, kind)
                    candidate.bind(("127.0.0.1", port))
                    sockets.append(candidate)
            return start, start + 1, start + 2
        except OSError:
            pass
        finally:
            for candidate in sockets:
                candidate.close()
    raise RuntimeError("could not reserve a consecutive local AirPlay port range")


def receive_synthetic_jpeg() -> None:
    """Verify the loopback JPEG boundary with a bounded synthetic frame."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        listener.settimeout(10)
        port = listener.getsockname()[1]
        synthetic_frame = b"\xff\xd8Misete smoke frame\xff\xd9"
        with socket.create_connection(("127.0.0.1", port), timeout=10) as sender:
            sender.sendall(synthetic_frame)
        connection, _ = listener.accept()
        with connection:
            connection.settimeout(10)
            payload = bytearray()
            while len(payload) <= MAX_JPEG_BYTES:
                chunk = connection.recv(65_536)
                if not chunk:
                    break
                payload.extend(chunk)
                if b"\xff\xd9" in payload:
                    break
    if not payload.startswith(b"\xff\xd8") or b"\xff\xd9" not in payload:
        raise RuntimeError("loopback transport did not receive a complete synthetic JPEG frame")
    if len(payload) > MAX_JPEG_BYTES:
        raise RuntimeError("synthetic JPEG exceeded the receiver safety bound")


def start_uxplay() -> None:
    """Confirm UxPlay accepts Misete's real loopback JPEG video pipeline."""
    if not UXPLAY.is_file() or not os.access(UXPLAY, os.X_OK):
        raise RuntimeError("pinned UxPlay is missing; run scripts/setup-receiver.sh")

    ports = available_airplay_ports()
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        frame_port = listener.getsockname()[1]
        video_sink = f"jpegenc quality=85 ! tcpclientsink host=127.0.0.1 port={frame_port} sync=false"
        with tempfile.TemporaryDirectory(prefix="misete-smoke-") as temp_dir:
            registration = Path(temp_dir) / "uxplay.register"
            command = [
                str(UXPLAY), "-n", "Misete-Smoke", "-nh",
                "-p", ",".join(map(str, ports)),
                "-pin", "-reg", str(registration), "-vs", video_sink,
            ]
            environment = {**os.environ, "UXPLAYRC": "/dev/null"}
            receiver = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=environment,
                start_new_session=True,
            )
            output = ""
            try:
                time.sleep(2)
                if receiver.poll() is not None:
                    output, _ = receiver.communicate()
                    raise RuntimeError("UxPlay exited before accepting its JPEG pipeline")
            finally:
                if receiver.poll() is None:
                    os.killpg(receiver.pid, signal.SIGTERM)
                try:
                    output, _ = receiver.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(receiver.pid, signal.SIGKILL)
                    output, _ = receiver.communicate(timeout=5)
            lowered = output.lower()
            if any(marker in lowered for marker in ("gst_parse", "pipeline error", "failed to parse")):
                raise RuntimeError("UxPlay reported a JPEG pipeline error")


def main() -> int:
    receive_synthetic_jpeg()
    start_uxplay()
    print("Receiver smoke check passed: loopback JPEG and UxPlay startup.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Receiver smoke check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
