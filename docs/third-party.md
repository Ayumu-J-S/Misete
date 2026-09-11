# Third-party components

## UxPlay

Misete builds the AirPlay receiver from the following pinned upstream source:

| Field | Value |
| --- | --- |
| Component | UxPlay |
| Source | https://github.com/FDH2/UxPlay |
| Revision | `9bebe1268671aeb76d0fd0e10621c05b5175505e` |
| License | GPL-3.0-or-later |

The local build applies [uxplay-stdout-flush.patch](../Resources/Patches/uxplay-stdout-flush.patch)
after verifying it against the pinned revision. The patch adds `fflush(stdout)`
after UxPlay writes a log line, so a PIN requested by an AirPlay client reaches
Misete's pipe promptly. The bundled source record identifies both the upstream
revision and this local patch, including its SHA-256; the bundle also contains
the patch under `Contents/Resources/ThirdParty/UxPlay/Patches/`.

Run `scripts/setup-receiver.sh` to clone, verify, and build that exact revision
into `.deps/uxplay`. The script writes a source record and copies UxPlay's
license into `.deps/uxplay/licenses`. `scripts/build-app.sh` preserves both in
`Misete.app/Contents/Resources/ThirdParty/UxPlay/`.

UxPlay is a separately built GPL dependency. The current bundle is for local
development and uses Homebrew dynamic libraries; it is not a self-contained,
redistributable package. Any distribution work needs a separate license and
runtime-dependency review.
