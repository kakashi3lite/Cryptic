# Optional Passphrase Protection

For simplicity and privacy, users can toggle “Protect with passphrase” in the preview panel before sharing. When enabled, the app encrypts the artifact (text/image/data) into a compact JSON envelope using ChaChaPoly and an HKDF-SHA256 key derived from the passphrase.

## Format
```
{
  "version": 1,
  "alg": "ChaChaPoly",
  "salt": "base64",
  "nonce": "base64",
  "ciphertext": "base64"
}
```

## Notes
- Key derivation: HKDF-SHA256(passphrase, salt, info="CrypticEnvelope", 32 bytes)
- Cipher: ChaChaPoly (AEAD) with random nonce; ciphertext contains tag
- File type: shared as generic data; future: custom UTType `com.worksy.cryptic`

## User Simplicity
- One toggle + passphrase field; no key management screens
- Works consistently for text and images
- Decryption flow can be added later (scan/import → passphrase → decode)

