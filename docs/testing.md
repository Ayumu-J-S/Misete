# Testing and validation

## Verified on 2026-09-11

Environment: Apple Silicon Mac, macOS 26.6.2, Xcode toolchain, UxPlay 1.74
at the pinned source revision, Homebrew GStreamer 1.28.7.

| Check | Observed result |
| --- | --- |
| `scripts/check.sh` | 28 tests passed; Core line coverage 97.91%, Receiver 91.01% |
| Warnings-as-errors Swift build | Passed |
| Pinned UxPlay build and repeated setup | Passed |
| `scripts/smoke-receiver.py` | Passed; synthetic JPEG transport and real UxPlay pipeline startup |
| Packaged app signature and resources | Passed; helper, icon, license, and source record present |
| Native app interaction | Opened Misete, started the display test, observed changing frames inside its window |
| Stop and process cleanup | Display cleared; GStreamer process and loopback listener closed |
| AirPlay startup | App reached waiting state; `dns-sd -L Misete _airplay._tcp local.` resolved with feature metadata |
| Actual iPad | User connected without a code; Computer Use observed the live iPad screen inside Misete |

The local test screenshot is in the ignored `artifacts/demo-screen.jpg`.
Screenshots of real user content and pairing codes are not saved to the repo.
The current app is a local developer bundle with Homebrew runtime dependencies.

## Automated checks

Run the complete local check with:

```sh
scripts/check.sh
```

The script runs `swift test --enable-code-coverage`, then uses `llvm-cov` data
to require at least 80% line coverage for `Sources/MiseteCore`. It reports
`Sources/MiseteReceiver` coverage separately. UI interaction evidence is
independent of either percentage.

Synthetic tests exercise framing, invalid input, process lifecycle, and state
transformations without an AirPlay client. They can identify a local transport
or rendering integration issue, but are not evidence that an iPad can discover
or mirror to Misete.

`scripts/smoke-receiver.py` also starts the pinned UxPlay executable with the
same JPEG GStreamer pipeline used by Misete, using a safe argument array and a
temporary registration file. It confirms that the process remains alive briefly
and separately sends one bounded synthetic JPEG through a loopback TCP receiver.
It does not log a pairing PIN or client identifier. Run it after
`scripts/setup-receiver.sh`:

```sh
scripts/smoke-receiver.py
```

## Real-iPad validation procedure

Before recording a result, build UxPlay and the app with `scripts/setup-receiver.sh`
and `scripts/build-app.sh`. Use an iPad and Mac on the same LAN, launch Misete,
then select **Misete** in iPad Control Center > Screen Mirroring.

Record each observation separately, without screen contents, credentials, or
device identifiers:

| Observation | Status |
| --- | --- |
| Misete appears in the iPad picker | User connected successfully |
| Passwordless connection (new default) | Passed with the user's iPad |
| First iPad frame appears inside Misete | Observed with Computer Use |
| Rotation maintains correct aspect ratio | Pending real-device validation |
| Disconnect cleans up the session | Pending real-device validation |
| Reconnect starts a new session | Pending real-device validation |

Do not treat a synthetic GStreamer source, a successful UxPlay build, or an app
launch as a pass for any item in this table.

## Simplified interface and passwordless default

The native window now contains a compact controls row and the video area, with
no marketing copy, branding panel, cards, or forced appearance. Computer Use
confirmed that `接続コード` is off on launch and that starting reaches `接続待ち`.
Inspection of the running helper confirmed no `-pin`, `-pw`, or `-reg` arguments.
The user was asked to cancel the previous iPad password prompt and select Misete
again. This does not yet establish a successful real-device stream.

## Optional PIN delivery regression

The previous missing code was reproduced with the real UxPlay helper: a local
`POST /pair-pin-start` request returned successfully, but the PIN event remained
in stdout's buffer. The one-line stdout flush patch fixes delivery without
changing authentication. `scripts/test-pin-flush.py` failed before the patch
and passes afterward, without printing or persisting the generated PIN.

Computer Use then enabled `接続コード` in the packaged app; a local RTSP request
caused the four-digit code to appear immediately in the native window. Stopping
cleared it. The checkbox was turned off again, and display-test video was also
verified in the simplified UI (`artifacts/simple-demo-screen.jpg`). This local
protocol check is separate from a successful real-iPad pairing or stream.

## Automatic window sizing

The real iPad stream was visible with empty space at its sides before this
change. Window fitting now uses the received image ratio and the measured
video viewport, including actual titlebar and control heights. It fits the
first frame, refits when the ratio changes, and snaps to the video ratio after
manual resizing. It stays within the current screen's usable bounds and avoids
changing fullscreen geometry. Narrow windows use compact settings controls.

Six geometry tests cover landscape, portrait, ultrawide, screen clamping,
minimum width, and invalid inputs. The packaged app's synthetic 4:3 video was
observed filling the window horizontally, and manual resizing preserved this
fit. Real-iPad rotation after this build remains to be verified on reconnection.
