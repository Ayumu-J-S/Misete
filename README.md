# Misete

I was annoyed that there was no quick way to share my iPad screen to my Mac.
You either have to use QuickTime Player or install an app you do not know (
maybe there are other ways), but it was literally easier for me to make an app for
it. It took me like 15 minutes, so here you go. Save yourself the token usage.

## Install

Install Misete from [dist/Misete.dmg](dist/Misete.dmg). See
[docs/install.md](docs/install.md) for the full installation and build details.

## Use

1. Open Misete and select **Start**.
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
