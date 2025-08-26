# Services and Flow

This app wires a minimal but complete flow to turn user input into an encoded artifact, guided by a stub assistant.

## Overview
- `LLMAssistant` (stubbed as `HeuristicAssistant`) proposes a mode for a given text.
- `EncodeCoordinator` selects an `EncoderService` by `Draft.Mode` and returns an `EncodeResult`.
- `DraftEditorView` shows a preview and ShareLink for the result.

## Protocols
- `EncoderService` → `encode(text:) -> EncodeResult`
- `LLMAssistant` → `propose(for:) -> LLMAssistantProposal`

## Implementations
- `EmojiCipher` → simple letter→emoji substitution.
- `QRCodeService` → CoreImage `CIQRCodeGenerator` with ECC M.
- Future: `ImageStego`, `AudioChirp`.

## Threading
- Encoding runs in a detached Task at `.userInitiated`. UI updates return to the main actor.
- SwiftData saves are debounced via `ContextSaver`.

## Security (future)
- Add optional CryptoKit passphrase encryption of artifacts before share.
- Keys: derive via HKDF from user passphrase, store ephemeral session keys only.

