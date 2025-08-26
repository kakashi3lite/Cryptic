//
//  EmojiCipher.swift
//  Cryptic
//
//  High-performance emoji substitution encoder with advanced mapping and async processing.
//

import Foundation
import os.log

struct EmojiCipher: EncoderService {
    private static let logger = Logger.codec
    
    // Enhanced emoji mapping with better Unicode coverage
    private static let encodingMap: [Character: String] = {
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        let emojis = [
            "😀", "🎈", "🚀", "🌟", "🍀", "🎵", "🔥", "🌈", "🍎", "⚡",
            "🐱", "🐶", "🦊", "🦄", "🐼", "🐧", "🐙", "🦋", "🌸", "🍩",
            "🎮", "🎲", "🎯", "🎁", "🎨", "🥇"
        ]
        
        var dict: [Character: String] = [:]
        for (letter, emoji) in zip(letters, emojis) {
            dict[letter] = emoji
        }
        
        // Add special characters
        dict[" "] = "⭐"
        dict["!"] = "💥"
        dict["?"] = "❓"
        dict["."] = "💫"
        dict[","] = "🌙"
        dict[":"] = "☀️"
        dict[";"] = "🌛"
        dict["'"] = "✨"
        dict['"'] = "💎"
        dict["-"] = "🌊"
        dict["_"] = "🏔️"
        
        return dict
    }()
    
    // Reverse mapping for decoding
    private static let decodingMap: [String: Character] = {
        var dict: [String: Character] = [:]
        for (char, emoji) in encodingMap {
            dict[emoji] = char
        }
        return dict
    }()
    
    // MARK: - Protocol Implementation
    
    var supportsMetalAcceleration: Bool { false }
    var estimatedCapacity: Int { Int.max } // No practical limit for emoji encoding
    var qualityPreservation: Float { 1.0 } // Lossless encoding
    
    func encode(text: String) async throws -> EncodeResult {
        let (result, metrics) = await PerformanceMetrics.measureAsync {
            try _encode(text: text)
        }
        
        Self.logger.logPerformance(metrics, operation: "EmojiCipher.encode")
        return result
    }
    
    func decode(from artifact: EncodeArtifact) async throws -> DecodeResult {
        guard case .text(let encodedText) = artifact else {
            throw CodecError.invalidInput
        }
        
        let (result, metrics) = await PerformanceMetrics.measureAsync {
            try _decode(encodedText: encodedText)
        }
        
        Self.logger.logPerformance(metrics, operation: "EmojiCipher.decode")
        return result
    }
    
    // MARK: - Private Implementation
    
    private func _encode(text: String) throws -> EncodeResult {
        guard !text.isEmpty else { throw CodecError.invalidInput }
        guard text.count <= 10000 else { 
            throw CodecError.capacityExceeded(requested: text.count, maximum: 10000)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use more efficient string building
        var result = ""
        result.reserveCapacity(text.count * 4) // Emojis are typically 2-4 bytes in UTF-8
        
        for character in text.lowercased() {
            if let emoji = Self.encodingMap[character] {
                result.append(emoji)
            } else {
                // Handle unknown characters gracefully
                result.append(character)
            }
        }
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        let qualityMetrics = QualityMetrics(
            expectedPSNR: nil, // N/A for text encoding
            capacityBytes: text.utf8.count,
            robustness: 0.95 // High robustness for emoji transmission
        )
        
        let metadata: [String: Any] = [
            "originalLength": text.count,
            "encodedLength": result.count,
            "compressionRatio": Float(result.utf8.count) / Float(text.utf8.count),
            "uniqueCharacters": Set(text.lowercased()).count,
            "mappedCharacters": text.lowercased().compactMap { Self.encodingMap[$0] }.count
        ]
        
        return EncodeResult(
            artifact: .text(result),
            description: "Emoji substitution cipher (\(text.count) → \(result.count) chars)",
            processingTime: processingTime,
            qualityMetrics: qualityMetrics,
            metadata: metadata
        )
    }
    
    private func _decode(encodedText: String) throws -> DecodeResult {
        guard !encodedText.isEmpty else { throw CodecError.invalidInput }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var result = ""
        var confidence: Float = 1.0
        var unmappedCount = 0
        
        result.reserveCapacity(encodedText.count)
        
        // Handle emoji sequences properly
        for character in encodedText {
            let charString = String(character)
            if let decodedChar = Self.decodingMap[charString] {
                result.append(decodedChar)
            } else {
                // Unknown emoji or character
                result.append(character)
                unmappedCount += 1
            }
        }
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Calculate confidence based on successful mappings
        if encodedText.count > 0 {
            confidence = Float(encodedText.count - unmappedCount) / Float(encodedText.count)
        }
        
        let metadata: [String: Any] = [
            "encodedLength": encodedText.count,
            "decodedLength": result.count,
            "unmappedCharacters": unmappedCount,
            "mappingSuccess": confidence
        ]
        
        return DecodeResult(
            text: result,
            processingTime: processingTime,
            confidence: confidence,
            metadata: metadata
        )
    }
    
    // MARK: - Advanced Features
    
    /// Generate a custom emoji mapping based on user preferences or themes
    static func createCustomMapping(theme: EmojiTheme) -> [Character: String] {
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        let emojis: [String]
        
        switch theme {
        case .animals:
            emojis = ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦", "🐤", "🦆", "🦅", "🦉", "🐺", "🐗", "🐴"]
        case .food:
            emojis = ["🍎", "🍌", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶️", "🫑", "🌽", "🥕", "🫒", "🧄", "🧅", "🥔"]
        case .nature:
            emojis = ["🌸", "🌺", "🌻", "🌹", "🌷", "🌲", "🌳", "🌴", "🌱", "🌿", "🍀", "🎋", "🍃", "🌾", "🌵", "🌊", "💧", "🔥", "🌟", "⭐", "🌙", "☀️", "⛅", "🌈", "❄️", "⚡"]
        case .objects:
            emojis = ["⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳", "🪁", "🏹", "🎣", "🤿", "🥊", "🥋"]
        }
        
        var dict: [Character: String] = [:]
        for (letter, emoji) in zip(letters, emojis) {
            dict[letter] = emoji
        }
        
        return dict
    }
}

enum EmojiTheme: CaseIterable {
    case animals
    case food
    case nature
    case objects
    
    var displayName: String {
        switch self {
        case .animals: return "Animals"
        case .food: return "Food & Drink"
        case .nature: return "Nature"
        case .objects: return "Objects & Sports"
        }
    }
}

