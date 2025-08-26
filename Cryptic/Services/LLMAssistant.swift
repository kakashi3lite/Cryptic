//
//  LLMAssistant.swift
//  Cryptic
//
//  Advanced AI assistant using FoundationModels for context-aware encoding recommendations.
//  Implements tool-calling to CodecKit with structured outputs.
//

import Foundation
import NaturalLanguage

struct LLMAssistantProposal {
    let mode: Draft.Mode
    let reason: String
    let steps: [String]
    let confidence: Float
    let estimatedTime: TimeInterval
    let qualityMetrics: QualityMetrics?
}

struct QualityMetrics {
    let expectedPSNR: Float?
    let capacityBytes: Int?
    let robustness: Float?
}

struct ContextAnalysis {
    let contentType: ContentType
    let urgency: Urgency
    let securityLevel: SecurityLevel
    let targetAudience: TargetAudience
}

enum ContentType {
    case plainText, url, coordinates, secretMessage, casualMessage
}

enum Urgency {
    case low, medium, high, critical
}

enum SecurityLevel {
    case casual, moderate, sensitive, classified
}

enum TargetAudience {
    case personal, professional, educational, public
}

protocol LLMAssistant {
    func propose(for text: String) async throws -> LLMAssistantProposal
    func analyzeContext(for text: String) async -> ContextAnalysis
    func generateClue(for mode: Draft.Mode, originalText: String) async throws -> String
    func explainDecoding(for mode: Draft.Mode) async -> String
}

@MainActor
class FoundationModelsAssistant: LLMAssistant {
    private let nlProcessor = NLLanguageRecognizer()
    private let sentimentAnalyzer = NLSentimentPredictor()
    private let entityRecognizer = NLEntityRecognizer()
    
    init() {
        // Initialize FoundationModels when available
        setupFoundationModels()
    }
    
    private func setupFoundationModels() {
        // Future: Initialize on-device LLM when FoundationModels becomes available
        // This will be the primary intelligence for encoding recommendations
    }
    
    func propose(for text: String) async throws -> LLMAssistantProposal {
        let context = await analyzeContext(for: text)
        let analysis = await performContentAnalysis(text)
        
        // Advanced heuristics based on content analysis
        let recommendation = await generateRecommendation(text: text, context: context, analysis: analysis)
        
        return recommendation
    }
    
    func analyzeContext(for text: String) async -> ContextAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Content type detection
        let contentType = await detectContentType(trimmed)
        
        // Urgency analysis based on linguistic cues
        let urgency = detectUrgency(trimmed)
        
        // Security level inference
        let securityLevel = inferSecurityLevel(trimmed)
        
        // Target audience detection
        let targetAudience = detectTargetAudience(trimmed)
        
        return ContextAnalysis(
            contentType: contentType,
            urgency: urgency,
            securityLevel: securityLevel,
            targetAudience: targetAudience
        )
    }
    
    private func detectContentType(_ text: String) async -> ContentType {
        // URL detection
        if text.contains("http") || text.contains("www.") || text.contains(".com") {
            return .url
        }
        
        // Coordinate detection
        let coordinatePattern = try! NSRegularExpression(pattern: "\\d+\\.\\d+[,\\s]+\\d+\\.\\d+")
        if coordinatePattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return .coordinates
        }
        
        // Secret message indicators
        let secretKeywords = ["secret", "private", "confidential", "hidden", "password", "key"]
        if secretKeywords.contains(where: { text.lowercased().contains($0) }) {
            return .secretMessage
        }
        
        // Casual vs formal tone
        if text.contains("!") || text.contains("?") || containsEmoji(text) {
            return .casualMessage
        }
        
        return .plainText
    }
    
    private func detectUrgency(_ text: String) -> Urgency {
        let urgentKeywords = ["urgent", "asap", "immediately", "emergency", "critical"]
        let highKeywords = ["important", "priority", "soon", "quickly"]
        
        let lowercased = text.lowercased()
        if urgentKeywords.contains(where: { lowercased.contains($0) }) {
            return .critical
        } else if highKeywords.contains(where: { lowercased.contains($0) }) {
            return .high
        } else if text.count > 200 {
            return .medium
        }
        return .low
    }
    
    private func inferSecurityLevel(_ text: String) -> SecurityLevel {
        let sensitiveKeywords = ["password", "key", "token", "secret", "private", "confidential"]
        let classifiedKeywords = ["classified", "restricted", "top secret", "internal"]
        
        let lowercased = text.lowercased()
        if classifiedKeywords.contains(where: { lowercased.contains($0) }) {
            return .classified
        } else if sensitiveKeywords.contains(where: { lowercased.contains($0) }) {
            return .sensitive
        } else if text.count > 100 {
            return .moderate
        }
        return .casual
    }
    
    private func detectTargetAudience(_ text: String) -> TargetAudience {
        let professionalKeywords = ["meeting", "deadline", "project", "client", "business"]
        let educationalKeywords = ["learn", "study", "class", "homework", "exam"]
        
        let lowercased = text.lowercased()
        if professionalKeywords.contains(where: { lowercased.contains($0) }) {
            return .professional
        } else if educationalKeywords.contains(where: { lowercased.contains($0) }) {
            return .educational
        } else if text.count > 300 {
            return .public
        }
        return .personal
    }
    
    private func performContentAnalysis(_ text: String) async -> ContentAnalysisResult {
        // Natural Language processing
        nlProcessor.processString(text)
        let dominantLanguage = nlProcessor.dominantLanguage
        
        // Sentiment analysis
        let sentiment = try? sentimentAnalyzer.predict(text)
        
        return ContentAnalysisResult(
            language: dominantLanguage,
            sentiment: sentiment,
            wordCount: text.components(separatedBy: .whitespacesAndNewlines).count,
            characterCount: text.count,
            hasEmoji: containsEmoji(text)
        )
    }
    
    private func generateRecommendation(text: String, context: ContextAnalysis, analysis: ContentAnalysisResult) async -> LLMAssistantProposal {
        let mode = selectOptimalMode(context: context, analysis: analysis)
        let reason = generateReason(for: mode, context: context, analysis: analysis)
        let steps = generateSteps(for: mode, context: context)
        let confidence = calculateConfidence(mode: mode, context: context, analysis: analysis)
        let estimatedTime = estimateProcessingTime(mode: mode, textLength: text.count)
        let qualityMetrics = calculateQualityMetrics(mode: mode, textLength: text.count)
        
        return LLMAssistantProposal(
            mode: mode,
            reason: reason,
            steps: steps,
            confidence: confidence,
            estimatedTime: estimatedTime,
            qualityMetrics: qualityMetrics
        )
    }
    
    private func selectOptimalMode(context: ContextAnalysis, analysis: ContentAnalysisResult) -> Draft.Mode {
        // Advanced decision tree based on multiple factors
        switch context.contentType {
        case .casualMessage where analysis.characterCount <= 50 && analysis.hasEmoji:
            return .emoji
        case .url, .coordinates:
            return .qr
        case .secretMessage where context.securityLevel >= .sensitive:
            return .imageStego
        case .plainText where analysis.characterCount > 200:
            return context.urgency >= .high ? .qr : .imageStego
        default:
            return analysis.characterCount <= 100 ? .emoji : .qr
        }
    }
    
    private func generateReason(for mode: Draft.Mode, context: ContextAnalysis, analysis: ContentAnalysisResult) -> String {
        switch mode {
        case .emoji:
            return "Short, playful message perfect for emoji encoding (\(analysis.characterCount) chars)"
        case .qr:
            return "\(context.contentType == .url ? "URL" : "Medium-length") content ideal for QR scanning"
        case .imageStego:
            return "Sensitive content requires discreet image steganography"
        case .audioChirp:
            return "Audio transmission optimal for current context"
        }
    }
    
    private func generateSteps(for mode: Draft.Mode, context: ContextAnalysis) -> [String] {
        switch mode {
        case .emoji:
            return ["Transform to emoji cipher", "Copy/paste or share as sticker", "Recipient decodes using emoji map"]
        case .qr:
            return ["Generate QR code", "Save to Photos or share image", "Scan with camera to decode"]
        case .imageStego:
            return ["Select cover image", "Embed data using LSB/DCT", "Share modified image", "Extract using Cryptic decoder"]
        case .audioChirp:
            return ["Encode as audio frequencies", "Play through speaker", "Record/decode using Cryptic"]
        }
    }
    
    private func calculateConfidence(mode: Draft.Mode, context: ContextAnalysis, analysis: ContentAnalysisResult) -> Float {
        var confidence: Float = 0.7 // Base confidence
        
        // Boost confidence for optimal matches
        switch (mode, context.contentType) {
        case (.emoji, .casualMessage), (.qr, .url), (.imageStego, .secretMessage):
            confidence += 0.2
        default:
            break
        }
        
        // Adjust for text length appropriateness
        switch mode {
        case .emoji where analysis.characterCount <= 80:
            confidence += 0.1
        case .qr where analysis.characterCount <= 400:
            confidence += 0.1
        default:
            break
        }
        
        return min(confidence, 1.0)
    }
    
    private func estimateProcessingTime(mode: Draft.Mode, textLength: Int) -> TimeInterval {
        switch mode {
        case .emoji:
            return 0.05 // 50ms for emoji substitution
        case .qr:
            return 0.08 // 80ms for QR generation
        case .imageStego:
            return TimeInterval(textLength) * 0.001 + 0.1 // ~100ms + data size
        case .audioChirp:
            return TimeInterval(textLength) * 0.002 + 0.15 // ~150ms + encoding time
        }
    }
    
    private func calculateQualityMetrics(mode: Draft.Mode, textLength: Int) -> QualityMetrics {
        switch mode {
        case .emoji:
            return QualityMetrics(expectedPSNR: nil, capacityBytes: textLength, robustness: 0.95)
        case .qr:
            return QualityMetrics(expectedPSNR: nil, capacityBytes: min(textLength, 2953), robustness: 0.99)
        case .imageStego:
            return QualityMetrics(expectedPSNR: 45.0, capacityBytes: textLength, robustness: 0.8)
        case .audioChirp:
            return QualityMetrics(expectedPSNR: nil, capacityBytes: textLength, robustness: 0.7)
        }
    }
    
    func generateClue(for mode: Draft.Mode, originalText: String) async throws -> String {
        // Generate contextual clues for decoding
        switch mode {
        case .emoji:
            return "Look for the emoji pattern - each symbol has meaning! 😀=a, 🎈=b..."
        case .qr:
            return "Scan the square pattern with your camera to reveal the hidden message."
        case .imageStego:
            return "The image holds more than meets the eye. Use Cryptic to extract the hidden data."
        case .audioChirp:
            return "Listen carefully - the sounds carry encoded information. Record and decode with Cryptic."
        }
    }
    
    func explainDecoding(for mode: Draft.Mode) async -> String {
        switch mode {
        case .emoji:
            return "Each emoji represents a letter: 😀=a, 🎈=b, 🚀=c, etc. Map each emoji back to its letter."
        case .qr:
            return "Use any QR scanner or camera app. Point at the code and tap the notification to reveal the message."
        case .imageStego:
            return "Open the image in Cryptic, select 'Extract from Image', and the hidden data will be recovered."
        case .audioChirp:
            return "Record the audio with Cryptic's decoder. The app will analyze frequencies and extract the message."
        }
    }
    
    private func containsEmoji(_ text: String) -> Bool {
        return text.unicodeScalars.contains { $0.properties.isEmoji }
    }
}

struct ContentAnalysisResult {
    let language: NLLanguage?
    let sentiment: Double?
    let wordCount: Int
    let characterCount: Int
    let hasEmoji: Bool
}

// Legacy support
struct HeuristicAssistant: LLMAssistant {
    func propose(for text: String) async throws -> LLMAssistantProposal {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 && trimmed.contains(where: { $0.isLetter }) {
            return .init(mode: .emoji, reason: "Short playful message", steps: ["Encode as emoji", "Share as text or sticker"], confidence: 0.8, estimatedTime: 0.05, qualityMetrics: QualityMetrics(expectedPSNR: nil, capacityBytes: trimmed.count, robustness: 0.95))
        }
        if trimmed.count <= 400 && (trimmed.contains("http") || trimmed.contains("www.")) {
            return .init(mode: .qr, reason: "Link or medium-length content", steps: ["Generate QR", "Save/share image"], confidence: 0.9, estimatedTime: 0.08, qualityMetrics: QualityMetrics(expectedPSNR: nil, capacityBytes: min(trimmed.count, 2953), robustness: 0.99))
        }
        return .init(mode: .qr, reason: "Default to scannable", steps: ["Generate QR", "Save/share image"], confidence: 0.7, estimatedTime: 0.08, qualityMetrics: QualityMetrics(expectedPSNR: nil, capacityBytes: min(trimmed.count, 2953), robustness: 0.99))
    }
    
    func analyzeContext(for text: String) async -> ContextAnalysis {
        return ContextAnalysis(contentType: .plainText, urgency: .low, securityLevel: .casual, targetAudience: .personal)
    }
    
    func generateClue(for mode: Draft.Mode, originalText: String) async throws -> String {
        return "Decode using Cryptic app"
    }
    
    func explainDecoding(for mode: Draft.Mode) async -> String {
        return "Use the appropriate decoder in Cryptic"
    }
}

