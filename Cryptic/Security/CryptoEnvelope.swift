//
//  CryptoEnvelope.swift
//  Cryptic
//
//  Minimal passphrase-based encryption for shareable artifacts.
//  Not a replacement for full key management; designed for simple user flow.
//

import Foundation
import CryptoKit

struct CrypticEnvelope: Codable {
    let version: Int
    let alg: String // "ChaChaPoly"
    let salt: String // base64
    let nonce: String // base64
    let ciphertext: String // base64 (includes tag)

    static let currentVersion = 1
    static let info = Data("CrypticEnvelope".utf8)

    static func encrypt(_ plaintext: Data, passphrase: String) throws -> Data {
        guard !passphrase.isEmpty else { throw NSError(domain: "Cryptic", code: -1) }
        let passwordKey = SymmetricKey(data: Data(passphrase.utf8))
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: passwordKey, salt: salt, info: info, outputByteCount: 32)
        let sealed = try ChaChaPoly.seal(plaintext, using: key)
        let env = CrypticEnvelope(
            version: currentVersion,
            alg: "ChaChaPoly",
            salt: salt.base64EncodedString(),
            nonce: sealed.nonce.withUnsafeBytes { Data($0).base64EncodedString() },
            ciphertext: sealed.ciphertext.base64EncodedString()
        )
        return try JSONEncoder().encode(env)
    }

    static func decrypt(_ envelopeData: Data, passphrase: String) throws -> Data {
        let env = try JSONDecoder().decode(CrypticEnvelope.self, from: envelopeData)
        guard env.version == currentVersion, env.alg == "ChaChaPoly" else { throw NSError(domain: "Cryptic", code: -2) }
        guard let salt = Data(base64Encoded: env.salt), let nonceData = Data(base64Encoded: env.nonce), let ciphertext = Data(base64Encoded: env.ciphertext) else {
            throw NSError(domain: "Cryptic", code: -3)
        }
        let passwordKey = SymmetricKey(data: Data(passphrase.utf8))
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: passwordKey, salt: salt, info: info, outputByteCount: 32)
        let nonce = try ChaChaPoly.Nonce(data: nonceData)
        let box = try ChaChaPoly.SealedBox(nonce: nonce, ciphertext: ciphertext)
        return try ChaChaPoly.open(box, using: key)
    }
}

