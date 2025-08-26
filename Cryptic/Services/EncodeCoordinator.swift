//
//  EncodeCoordinator.swift
//  Cryptic
//
//  Selects an encoder based on Draft.Mode and returns an EncodeResult.
//

import Foundation

struct EncodeCoordinator {
    func encode(draft: Draft) throws -> EncodeResult {
        switch draft.mode {
        case .emoji:
            return try EmojiCipher().encode(text: draft.text)
        case .qr:
            return try QRCodeService().encode(text: draft.text)
        case .imageStego:
            // Future: implement LSB/DCT
            throw CodecError.unsupported
        case .audioChirp:
            // Future: implement BFSK/OFDM-lite
            throw CodecError.unsupported
        }
    }
}

