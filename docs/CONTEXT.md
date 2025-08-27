# Project Context (Living Doc)

Purpose: capture key decisions, constraints, and intent so future work stays coherent and fast.

## Current Intent
- Privacy-first, on-device by default; no analytics.
- SwiftUI 6 + SwiftData for simple, reliable local drafts.
- Minimal but complete encode flow: Assistant → Coordinator → Encoder → Preview/Share.
- CI acts as guardrails (build, test, TSAN); keep it green.

## Key Decisions (links)
- Autosave strategy: `docs/CONTEXT_SAVING.md` (debounce, lifecycle saves).
- Encoding surface: `docs/SERVICES.md` (protocols, coordinator, threading).
- Optional protection: `docs/ENCRYPTION.md` (HKDF + ChaChaPoly envelope).
- Product/tech framing: `docs/ARCHITECTURE.md` (KPIs, personas, system).

## Component Context Cards
- UI: `docs/context/PurpleGlassSystem.md`, `docs/context/GlassAnimationSystem.md`
- Metal: `docs/context/MetalGlassRenderer.md`, `docs/context/GlassEffects.metal.md`, `docs/context/ImageStego.metal.md`, `docs/context/MetalStegoProcessor.md`

## Design Constraints
- iOS 18+, SwiftUI-first UX; fast and responsive at 60fps.
- On-device only content processing; explicit user action to share externally.
- App Store compliance: export compliance set; no forced sign-in.

## Extension Points
- Encoders: add `ImageStego`, `AudioChirp` behind `EncoderService`.
- Assistant: replace `HeuristicAssistant` with on-device FoundationModels tool-calls.
- Security: optional CryptoKit encryption already standardized via envelope.

## Testing Guidance
- Fast unit tests per encoder (golden vectors where applicable).
- Concurrency safety: TSAN CI pass; keep operations small and isolated.
- Persistence: in-memory SwiftData containers in tests.

## Operational Guidance
- Keep CI green; prefer small PRs with docs when behavior changes.
- Update this doc (and/or ADRs) when changing constraints or introducing new tradeoffs.

## Open Questions
- Adopt custom UTType for `.cryptic` envelopes for better share UX?
- Migrate to Xcode Cloud for TestFlight gating later?
- Minimum viable decoder/import screen scope and UX copy?
