//
//  LLMAssistant.swift
//  Cryptic
//
//  Stub assistant that can propose an encoding mode based on heuristics.
//  Future: integrate on-device FoundationModels with tool-calls.
//

import Foundation

struct LLMAssistantProposal {
    let mode: Draft.Mode
    let reason: String
    let steps: [String]
}

protocol LLMAssistant {
    func propose(for text: String) -> LLMAssistantProposal
}

struct HeuristicAssistant: LLMAssistant {
    func propose(for text: String) -> LLMAssistantProposal {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 && trimmed.contains(where: { $0.isLetter }) {
            return .init(mode: .emoji, reason: "Short playful message", steps: ["Encode as emoji", "Share as text or sticker"]) }
        if trimmed.count <= 400 && (trimmed.contains("http") || trimmed.contains("www.")) {
            return .init(mode: .qr, reason: "Link or medium-length content", steps: ["Generate QR", "Save/share image"]) }
        return .init(mode: .qr, reason: "Default to scannable", steps: ["Generate QR", "Save/share image"]) }
}

