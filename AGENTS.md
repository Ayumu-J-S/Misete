# Misete development

Misete is a macOS app that receives an iPad's screen through the standard
AirPlay Screen Mirroring picker. The receiver name is `Misete`. Linux is a
future target; keep protocol/transport decisions separate from the macOS UI.

## Working agreements

- Plan substantial changes, write meaningful failing tests first, then implement.
- Delegate bounded implementation/review work to GPT 5.6 Sol or Terra. Use the
  lead model for architecture and verification. Do not select unavailable models.
- Commit small, coherent changes using conventional commit messages. Review the
  diff and security implications before each commit. Do not push unless requested.
- Keep functions and files focused. Prefer immutable value models; confine
  necessary stream/process/UI state to explicit owners and queues.
- Validate configuration and bound untrusted network buffers. Launch processes
  with argument arrays, never a shell command assembled from user input.
- Keep local video transport on loopback. The user explicitly chose passwordless
  AirPlay on 2026-09-11; do not silently re-enable pairing. Do not
  persist screen contents or credentials in logs or source control.
- Cover core logic at 80% or higher. Report unit/integration coverage separately
  from UI and real-iPad evidence. A synthetic video is not an AirPlay test.

## Layout and commands

- `Sources/MiseteCore`: configuration, framing, and pure state transformations.
- `Sources/MiseteReceiver`: local transport and UxPlay process lifecycle.
- `Sources/MiseteApp`: macOS presentation.
- `scripts`: reproducible setup, packaging, checks, and smoke tests.
- `docs`: architecture, operational instructions, and validation evidence.
- `.agents/skills/misete-airplay/SKILL.md`: receiver development and real-device QA.

Use `swift test --enable-code-coverage`, `scripts/build-app.sh`, and the checks
documented in README. Never claim Linux support or real-device success without
running those paths. Treat UxPlay as a separately built GPL dependency and keep
its license/source provenance in packaged outputs.
