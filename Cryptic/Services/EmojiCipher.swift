//
//  EmojiCipher.swift
//  Cryptic
//
//  Minimal emoji substitution encoder: a->😀, b->🎈, etc.
//

import Foundation

struct EmojiCipher: EncoderService {
    private static let map: [Character: Character] = {
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        let emojis = Array("😀🎈🚀🌟🍀🎵🔥🌈🍎⚡️🐱🐶🦊🦄🐼🐧🐙🦋🌸🍩🎮🎲🎯🎁🎨🥇")
        var dict: [Character: Character] = [:]
        for (l, e) in zip(letters, emojis) { dict[l] = e }
        return dict
    }()

    func encode(text: String) throws -> EncodeResult {
        guard !text.isEmpty else { throw CodecError.invalidInput }
        let transformed = String(text.lowercased().map { Self.map[$0] ?? $0 })
        return EncodeResult(artifact: .text(transformed), description: "Emoji substitution")
    }
}

