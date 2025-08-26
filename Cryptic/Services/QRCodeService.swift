//
//  QRCodeService.swift
//  Cryptic
//
//  Minimal QR generator using CoreImage.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct QRCodeService: EncoderService {
    private let context = CIContext()

    func encode(text: String) throws -> EncodeResult {
        guard let data = text.data(using: .utf8), !data.isEmpty else { throw CodecError.invalidInput }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else {
            throw CodecError.unsupported
        }
        guard let cg = context.createCGImage(output, from: output.extent) else {
            throw CodecError.unsupported
        }
        let image = UIImage(cgImage: cg)
        return EncodeResult(artifact: .image(image), description: "QR Code (M)")
    }
}

