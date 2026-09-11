# Testing and validation

## Automated checks

Run the complete local check with:

```sh
scripts/check.sh
```

The script runs `swift test --enable-code-coverage`, then uses `llvm-cov` data
to require at least 80% line coverage for `Sources/MiseteCore`. This threshold
is limited to the pure core target; receiver integration coverage and macOS UI
evidence are reported separately.

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
| Misete appears in the iPad picker | Pending real-device validation |
| Pairing completes with the displayed PIN | Pending real-device validation |
| First moving frame appears inside Misete | Pending real-device validation |
| Rotation maintains correct aspect ratio | Pending real-device validation |
| Disconnect cleans up the session | Pending real-device validation |
| Reconnect starts a new session | Pending real-device validation |

Do not treat a synthetic GStreamer source, a successful UxPlay build, or an app
launch as a pass for any item in this table.
