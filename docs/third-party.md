# Third-party components

## UxPlay

Misete builds the AirPlay receiver from the following pinned upstream source:

| Field | Value |
| --- | --- |
| Component | UxPlay |
| Source | https://github.com/FDH2/UxPlay |
| Revision | `9bebe1268671aeb76d0fd0e10621c05b5175505e` |
| License | GPL-3.0-or-later |

Run `scripts/setup-receiver.sh` to clone, verify, and build that exact revision
into `.deps/uxplay`. The script writes a source record and copies UxPlay's
license into `.deps/uxplay/licenses`. `scripts/build-app.sh` preserves both in
`Misete.app/Contents/Resources/ThirdParty/UxPlay/`.

UxPlay is a separately built GPL dependency. The current bundle is for local
development and uses Homebrew dynamic libraries; it is not a self-contained,
redistributable package. Any distribution work needs a separate license and
runtime-dependency review.
