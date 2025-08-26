# Contributing to Cryptic (CipherPlay)

Thank you for helping build a playful, privacy-first encoder. This guide keeps changes coherent, safe, and fast.

## Development Quickstart
- Requirements: Xcode (latest stable), iOS 18 SDK.
- Build: `xcodebuild -project Cryptic.xcodeproj -scheme Cryptic -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Test: `xcodebuild -project Cryptic.xcodeproj -scheme Cryptic -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test`
- TSAN (optional): add `-enableThreadSanitizer YES` to the test command.

## Commit/PR Semantics
- Use Conventional Commits for PR titles (validated in CI):
  - `feat: ...`, `fix: ...`, `docs: ...`, `refactor: ...`, `perf: ...`, `test: ...`, `build: ...`, `ci: ...`, `chore: ...`, `revert: ...`
  - Optional scope: `feat(emoji): ...`
  - Breaking change: `feat!: ...`
- Keep PRs small and focused; include docs updates when behavior or decisions change.

## Code & UX Guidelines
- SwiftUI-first; keep UI responsive. Avoid long work on the main actor.
- Persistence: schedule saves via `ContextSaver`; wrap roots with `.autosaveModelContext()`.
- Tests: add unit tests for new services/encoders; use in-memory SwiftData for persistence tests.
- Privacy: on-device only by default; explicit user action to share externally.
- App Store: keep Info.plist compliance keys accurate (`ITSAppUsesNonExemptEncryption`).

## ADRs (Decisions)
- For notable design/security decisions, add an ADR under `docs/decisions/` using `_TEMPLATE.md`.
- File name: `NNNN-title.md` (increment `NNNN`). Link it from `docs/CONTEXT.md` if it changes constraints.

## Folder Map
- `Cryptic/` app code (models, views, services, security)
- `CrypticTests/` tests
- `docs/` architecture, context, decisions
- `.github/` CI and templates

## PR Checklist
- [ ] Build succeeds locally
- [ ] Tests added/updated and pass
- [ ] Docs updated (README/context/ADR as needed)
- [ ] CI green

---
Questions? Open a discussion or a draft PR early.

