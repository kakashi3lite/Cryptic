import XCTest
@testable import Cryptic

final class QRCodeServiceTests: XCTestCase {
    func testQRGeneratesImage() throws {
        let sut = QRCodeService()
        let res = try sut.encode(text: "hello")
        switch res.artifact {
        case .image(let img):
            XCTAssertGreaterThan(img.size.width, 0)
        default:
            XCTFail("Expected image")
        }
    }
}

