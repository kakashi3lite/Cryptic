# CipherPlay — Fun Encoding/Decoding with On-Device AI (iOS 18+)

This document captures the product and technical context for Cryptic/CipherPlay. It guides future development and CI expectations.

## 1) One-liner
Playful, privacy-first message encoding: emoji ciphers, QR, image-stego, and audio chirps — all guided by an on-device LLM and GPU-accelerated with Metal.

## 2) Goals & Non-Goals
- Goals: delightful “secret message” creation; offline by default; instant performance; App Store compliance; zero analytics by default.
- Non-Goals: anonymity network, illicit comms tooling, or circumventing platform policies.

## 3) Personas & JTBD
- Creator: “Make a hidden birthday clue as a QR/poster.”
- Teammate: “Send a stealth hint in an image.”
- Classroom: “STEM demo: sound → data.”

## 4) KPIs
- Crash-free sessions > 99.8%
- Median encode time: QR ≤ 30 ms, stego(1080p) ≤ 120 ms, emoji ≤ 150 ms, chirp pack ≤ 250 ms
- Task completion (encode→share) ≤ 10 s p50
- Decode success (QR-M): ≥ 99.5%
- 7-day retention uplift vs control: +8%

## 5) System Architecture
- App: SwiftUI 6 (iOS 18+), SF Symbols 7 effects, materials (HIG).
- LLM: `FoundationModels` on-device; tool-calling to `CodecKit`.
- CodecKit (module):
  - EmojiCipher: substitution tables, seeded by user/LLM.
  - QRCode: ISO/IEC 18004; ECC L/M/Q/H; renderer+scanner.
  - ImageStego: LSB (PNG) + DCT (JPEG); Metal compute; perceptual QA.
  - AudioChirp: BFSK/OFDM-lite with FEC; MPSGraph FFT; vDSP fallback.
- Security: CryptoKit (ChaChaPoly/AES-GCM), Curve25519, Secure Enclave, zero-log.
- Storage: SwiftData (local drafts); Photos limited-scope save on user action.
- CI/CD: GitHub Actions now; align with Xcode Cloud later for TestFlight.

## 6) LLM Integration
- Assistant roles:
  1) Recommend encoding (context-aware).
  2) Generate playful clues/recovery hints.
  3) Summarize “how to decode” instructions.
- Constraints:
  - On-device only for content; no text leaves device unless user shares.
  - Tool-calling only into `CodecKit` with structured inputs.
- Example flow:
  - `LLMAssistant.propose(mode, reason, steps)` → UI shows one-tap actions.

## 7) Metal/DSP Details
- Audio: windowed FFT (MPSGraph); magnitude thresholding; FEC interleave; pilot tone for sync.
- Image: compute kernels per-tile; guard bands; DCT domain to preserve JPEG quality. See `docs/context/ImageStego.metal.md` and `docs/context/MetalStegoProcessor.md`.
- Perf budget: single command buffer/frame; reuse pipelines; avoid heap churn. See `docs/context/MetalGlassRenderer.md` and `docs/context/GlassEffects.metal.md`.

## 8) UX & Accessibility
- Materials: `.ultraThinMaterial` with scrim overlays.
- Large controls, haptics, Dynamic Type, VoiceOver labels.
- Color contrast AA even on busy backdrops.

## 9) Privacy & Compliance
- App Privacy: “Data Not Collected.” No analytics by default.
- Export Compliance: Apple CryptoKit; set `ITSAppUsesNonExemptEncryption` and follow App Store Connect guidance.
- Guideline 5.1: no forced sign-in; features accessible without account.

## 10) Threat Model (light)
- Protect keys in Secure Enclave; ephemeral session keys; wipe plaintext buffers.
- Educate users that stego ≠ encryption; combine with passphrase for secrecy.

## 11) Testing Strategy
- Unit tests for codecs (golden vectors).
- Property tests for QR ECC corruption.
- Snapshot tests for image diff (ΔE* thresholds).
- Audio loopback tests across common iPhone models.

## 12) Release Plan
- Beta 1: Emoji + QR + LLM assist.
- Beta 2: Image stego + CryptoKit.
- Beta 3: Audio chirp + FEC; accessibility polish.
- 1.0: Export compliance docs; Privacy Label “Data Not Collected”; phased App Store release.

## 13) Monetization (optional)
- Free core; Pro: themes, batch tools, higher stego capacity, offline clue packs.
- One-time unlock or $1.99/mo; student discount.

## 14) Open Questions
- Add AR “Code Hunt” later?
- Allow custom ECC tuning UI?

---

See also: `docs/CONTEXT_SAVING.md` for SwiftData autosave guidance.
