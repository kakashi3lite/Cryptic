//
//  CodecKit.swift
//  Cryptic
//
//  Minimal protocol surface for encoding/decoding.
//

import Foundation
import SwiftUI

enum EncodeArtifact: Equatable {
    case text(String)
    case image(UIImage)
    case data(Data)
}

struct EncodeResult: Equatable {
    let artifact: EncodeArtifact
    let description: String

    static func == (lhs: EncodeResult, rhs: EncodeResult) -> Bool {
        switch (lhs.artifact, rhs.artifact) {
        case let (.text(a), .text(b)): return a == b
        case (.image, .image): return false // images are not equatable; ignore here
        case let (.data(a), .data(b)): return a == b
        default: return false
        }
    }
}

protocol EncoderService {
    func encode(text: String) throws -> EncodeResult
}

enum CodecError: Error {
    case unsupported
    case invalidInput
}

