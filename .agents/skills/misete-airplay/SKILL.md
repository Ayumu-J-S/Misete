---
name: misete-airplay
description: Implement or diagnose Misete AirPlay discovery, pairing, in-app video transport, and real-iPad validation on macOS.
---

Read `docs/architecture.md` before changing the receiver boundary, and
`docs/testing.md` for the current validation procedure.

Misete must appear in iPad Control Center > Screen Mirroring using real UxPlay
DNS-SD advertising. Advertising a name alone does not implement AirPlay. The
video must render inside Misete; a separate GStreamer player window is not
acceptance. Use the local JPEG transport to keep the UI separate from UxPlay.

Keep the frame endpoint loopback-only, reject excessive frame buffers, launch
UxPlay without a shell, and stop child processes when the app quits. Keep PINs
out of saved diagnostics. Test chunk fragmentation, process errors, stop/restart,
and invalid settings before exercising a real iPad.

Use synthetic GStreamer video to isolate rendering problems. Separately verify
DNS-SD registration, then ask the user to choose Misete on their iPad when ready.
Record discovery, pairing, first moving frame, rotation, disconnect, and reconnect
as separate observations. Do not label an unobserved step as passed.

Update existing docs with meaningful findings. Do not duplicate transient logs,
screen contents, personal device identifiers, or credentials into the repository.
