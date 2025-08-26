import XCTest
@testable import Cryptic

final class EmojiCipherTests: XCTestCase {
    func testEmojiEncodeMapsLetters() throws {
        let sut = EmojiCipher()
        let res = try sut.encode(text: "abc")
        guard case let .text(output) = res.artifact else { return XCTFail("Expected text") }
        XCTAssertNotEqual(output, "abc")
        XCTAssertFalse(output.isEmpty)
    }
}

