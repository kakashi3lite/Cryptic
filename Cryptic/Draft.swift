//
//  Draft.swift
//  Cryptic
//
//  Minimal SwiftData model to represent a user draft
//  for CipherPlay encoders (emoji, QR, image-stego, audio-chirp).
//

import Foundation
import SwiftData

@Model
final class Draft {
    enum Mode: String, Codable, CaseIterable {
        case emoji
        case qr
        case imageStego
        case audioChirp
    }

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var mode: Mode
    var text: String
    var note: String?

    init(id: UUID = UUID(), createdAt: Date = .now, updatedAt: Date = .now, mode: Mode = .emoji, text: String = "", note: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mode = mode
        self.text = text
        self.note = note
    }
}

