# Install Misete

## Download

Download [Misete.dmg](../dist/Misete.dmg) from this repository.

The DMG is a self-contained Apple Silicon build for macOS 14 or later. It
includes the Misete app, UxPlay, and the Homebrew dynamic libraries required by
UxPlay. Homebrew is not required on the Mac where the DMG is installed.

## Install

1. Open `Misete.dmg`.
2. Drag `Misete.app` to the `Applications` folder shown in the disk image.
3. Eject the Misete disk image.
4. Open Misete from Applications.

The build is ad hoc signed and not notarized. macOS may ask for confirmation in
Privacy & Security the first time the app is opened. Approve Misete there only
if you downloaded it from a source you trust.

## Use

1. Open Misete and select **Start**.
2. On the iPad, open Control Center and choose **Screen Mirroring**.
3. Select **Misete**.

The Mac and iPad must be on the same local network. Misete uses the local
network for AirPlay discovery and the video stream. It does not upload or save
screen contents.

## Build the UserBuild

To create the DMG locally on an Apple Silicon Mac, clone the repository and
run:

```sh
scripts/setup.sh
scripts/setup-receiver.sh
scripts/build-user-app.sh
```

The installer image is written to `dist/Misete.dmg`. The `dist` directory is
ignored by default; the checked-in DMG is intentionally force-added as the
single release artifact.

For a developer-only app bundle that uses Homebrew libraries directly, use
`scripts/build-app.sh` instead. That bundle is not the recommended download
for another Mac.