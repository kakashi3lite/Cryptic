import XCTest
@testable import Cryptic

final class CryptoEnvelopeTests: XCTestCase {
    func testEncryptDecryptRoundtrip() throws {
        let plain = Data("secret message".utf8)
        let pass = "p@ssw0rd"
        let env = try CrypticEnvelope.encrypt(plain, passphrase: pass)
        let out = try CrypticEnvelope.decrypt(env, passphrase: pass)
        XCTAssertEqual(out, plain)
    }
}

