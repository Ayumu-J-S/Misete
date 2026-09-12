# Misete

I was annoyed that there was no quick way to share an iPad screen to my Mac.
There are apps for it, but I wanted something I could build and run myself,
without relying on an App Store app I did not know. So I made Misete.

It took me about 15 minutes, so here you go. Save yourself the token usage.

## Install

The built app is at `dist/Misete.app`.

Open it directly, or move `Misete.app` to your Applications folder and open it
from there.

## Use

1. Open Misete and select **開始 (Start)**.
2. On your iPad, open Control Center and choose **Screen Mirroring**.
3. Select **Misete**.

The connection-code option is off by default.

## Development

On macOS, run the following once to install the required tools and build the
receiver:

```sh
scripts/setup.sh
scripts/setup-receiver.sh
```

If `scripts/setup-receiver.sh` stops because a dependency is missing, run
`scripts/setup.sh` first. If macOS asks for Xcode Command Line Tools, run
`xcode-select --install`.

To check the project locally:

```sh
scripts/check.sh
scripts/smoke-receiver.py
```

These tests cover image decoding, state management, the local JPEG path, and
starting the receiver. They do not prove real iPad discovery, pairing, or video
display. See [docs/testing.md](docs/testing.md) for the real-device test steps
and recorded results.

### Troubleshooting

- If Misete does not appear on the iPad, make sure both devices are on the same
  LAN. A VPN or guest Wi-Fi may block Bonjour/mDNS.
- If sharing does not start, allow TCP/UDP ports 35000–35002 and UDP port 5353
  through the local firewall.
