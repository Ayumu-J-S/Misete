# Architecture

## Goal

AirDroid Cast's AirPlay flow is the reference: start the Mac receiver, select
Misete in iPad Control Center > Screen Mirroring, pair, and see the live screen
inside the app. No companion iPad app is required. The first target is macOS 14+.

## Boundaries

1. UxPlay handles AirPlay negotiation, Bonjour discovery, pairing, decryption,
   and audio/video decoding. Build a pinned upstream source revision locally.
2. GStreamer encodes decoded video into JPEG frames and sends it over a local
   TCP connection to Misete. The endpoint binds only to 127.0.0.1 and its port is
   selected by the operating system. There is no web server or cloud service.
3. A Swift receiver owns the child process, bounded frame decoding, state,
   and cleanup. The macOS app displays frames with their original aspect ratio.

The local listener permits at most four simultaneous pipeline connections;
each parser permits an 8 MiB JPEG and reads at most 64 KiB per receive. A
single-slot mailbox drops superseded frames before delivery to the UI. UxPlay
advertises TCP/UDP ports 35000–35002 with `-n Misete -nh`. `-vsync no` follows
upstream's macOS recommendation; audio uses UxPlay's normal audio renderer.

Per the user's explicit choice on 2026-09-11, the app defaults to passwordless
AirPlay and omits `-pin`, `-pw`, and `-reg`. Devices on the same LAN may connect
without a code. The standard macOS checkbox can opt into pairing while stopped; it is off
on launch. The app uses
`UXPLAYRC=/dev/null` to isolate the helper from unrelated user configuration and
retains only curated diagnostics, never raw protocol output or screen frames.

The JPEG hop trades some CPU and latency for a simple, inspectable boundary
that avoids private macOS window embedding APIs. Measure with real iPad content
before attempting a zero-copy transport. Linux can reuse UxPlay and this framing
protocol; the current macOS UI and Network.framework host are not Linux builds.

## Scope

Same-LAN screen mirroring and system audio are the initial scope. USB-only
casting, remote control, remote-network relay, recording, and DRM video are not
part of this implementation. Do not promise that protected content will mirror.

## Sources

- AirDroid Cast guide: https://www.airdroid.com/guide/cast/
- UxPlay upstream: https://github.com/FDH2/UxPlay
- UxPlay licensing: https://github.com/FDH2/UxPlay/blob/master/LICENSE
