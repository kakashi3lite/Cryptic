# ADR 0001: Passphrase Protection via JSON Envelope

Date: 2025-08-26

## Status
Accepted

## Context
Users want an easy, consistent way to protect shared artifacts (text, QR, images) without dealing with keys/accounts. We also want sane cryptography while keeping UX minimal.

## Decision
Add a single toggle in the preview to encrypt the output into a JSON envelope (`CrypticEnvelope`) using HKDF-SHA256(passphrase, salt) → ChaChaPoly AEAD.

## Consequences
- Pros: simple UX (toggle + passphrase), consistent across artifact types, safe defaults, testable.
- Cons: passphrase entry friction; envelope consumers need a decrypt flow; no multi-device key sync.

## Alternatives Considered
- Raw AES-GCM: similar UX; ChaChaPoly chosen for speed and platform support.
- PBKDF2/Scrypt: stronger KDF with cost; HKDF chosen for simplicity (might revisit if threat model tightens).
- Public-key sharing: more complex UX; out-of-scope for minimal v1.

## Implementation Notes
- File format: versioned JSON with base64 fields (salt, nonce, ciphertext).
- Tests: roundtrip encrypt/decrypt unit test.
- Future: custom UTType (e.g., `com.worksy.cryptic`), decrypt/import screen.

