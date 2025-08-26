//
//  EncodeCoordinator.swift
//  Cryptic
//
//  High-performance encoding coordinator with background processing and Metal acceleration.
//

import Foundation
import os.log

@MainActor
class EncodeCoordinator {
    private let logger = Logger.codec
    private let backgroundQueue = BackgroundProcessingQueue()
    
    // Service instances with proper initialization
    private let emojiCipher = EmojiCipher()
    private let qrCodeService = QRCodeService()
    private let audioChirpService = AudioChirpService()
    private var imageStegoService: ImageStegoService?
    
    init() {
        // Initialize Metal-dependent services
        do {
            imageStegoService = try ImageStegoService()
        } catch {
            logger.error("Failed to initialize ImageStegoService: \(error.localizedDescription)")
            imageStegoService = nil
        }
    }
    
    // MARK: - Main Encoding Interface
    
    func encode(draft: Draft, options: EncodingOptions = .default) async throws -> EncodeResult {
        logger.info("Starting encoding for mode: \(draft.mode.rawValue), text length: \(draft.text.count)")
        
        let result = try await backgroundQueue.enqueue {
            try await self._encode(draft: draft, options: options)
        }
        
        logger.info("Encoding completed in \(result.processingTime, format: .fixed(precision: 3))s")
        return result
    }
    
    func decode(from artifact: EncodeArtifact, expectedMode: Draft.Mode) async throws -> DecodeResult {
        logger.info("Starting decoding for mode: \(expectedMode.rawValue)")
        
        let result = try await backgroundQueue.enqueue {
            try await self._decode(from: artifact, expectedMode: expectedMode)
        }
        
        logger.info("Decoding completed in \(result.processingTime, format: .fixed(precision: 3))s, confidence: \(result.confidence)")
        return result
    }
    
    // MARK: - Batch Processing
    
    func encodeBatch(_ drafts: [Draft], options: EncodingOptions = .default) async throws -> [EncodeResult] {
        return try await withThrowingTaskGroup(of: EncodeResult.self) { group in
            for draft in drafts {
                group.addTask {
                    try await self.encode(draft: draft, options: options)
                }
            }
            
            var results: [EncodeResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // MARK: - Service Status
    
    func getServiceCapabilities() -> ServiceCapabilities {
        return ServiceCapabilities(
            supportsEmoji: true,
            supportsQR: true,
            supportsImageStego: imageStegoService != nil,
            supportsAudioChirp: true,
            metalAcceleration: qrCodeService.supportsMetalAcceleration || (imageStegoService?.supportsMetalAcceleration ?? false)
        )
    }
    
    func estimateProcessingTime(for draft: Draft) -> TimeInterval {
        let baseTime: TimeInterval
        
        switch draft.mode {
        case .emoji:
            baseTime = 0.05 // 50ms
        case .qr:
            baseTime = 0.08 // 80ms
        case .imageStego:
            baseTime = 0.12 + Double(draft.text.count) * 0.001 // 120ms + data size
        case .audioChirp:
            baseTime = 0.15 + Double(draft.text.count) * 0.002 // 150ms + encoding time
        }
        
        // Adjust for background queue overhead
        return baseTime * (backgroundQueue.isProcessing ? 1.5 : 1.0)
    }
    
    // MARK: - Private Implementation
    
    private func _encode(draft: Draft, options: EncodingOptions) async throws -> EncodeResult {
        switch draft.mode {
        case .emoji:
            return try await emojiCipher.encode(text: draft.text)
            
        case .qr:
            let metalOptions = MetalEncodingOptions(
                useGPUAcceleration: options.useMetalAcceleration && qrCodeService.supportsMetalAcceleration,
                qualityTarget: options.qualityTarget,
                speedTarget: options.speedTarget,
                maxMemoryMB: options.maxMemoryMB
            )
            return try await qrCodeService.encodeWithMetal(text: draft.text, options: metalOptions)
            
        case .imageStego:
            guard let stegoService = imageStegoService else {
                throw CodecError.unsupported
            }
            let metalOptions = MetalEncodingOptions(
                useGPUAcceleration: options.useMetalAcceleration && stegoService.supportsMetalAcceleration,
                qualityTarget: options.qualityTarget,
                speedTarget: options.speedTarget,
                maxMemoryMB: options.maxMemoryMB
            )
            return try await stegoService.encodeWithMetal(text: draft.text, options: metalOptions)
            
        case .audioChirp:
            return try await audioChirpService.encode(text: draft.text)
        }
    }
    
    private func _decode(from artifact: EncodeArtifact, expectedMode: Draft.Mode) async throws -> DecodeResult {
        switch expectedMode {
        case .emoji:
            return try await emojiCipher.decode(from: artifact)
            
        case .qr:
            return try await qrCodeService.decode(from: artifact)
            
        case .imageStego:
            guard let stegoService = imageStegoService else {
                throw CodecError.unsupported
            }
            return try await stegoService.decode(from: artifact)
            
        case .audioChirp:
            return try await audioChirpService.decode(from: artifact)
        }
    }
}

// MARK: - Supporting Types

struct EncodingOptions {
    let useMetalAcceleration: Bool
    let qualityTarget: Float // 0.0 - 1.0
    let speedTarget: Float // 0.0 - 1.0
    let maxMemoryMB: Int
    let timeoutSeconds: TimeInterval
    
    static let `default` = EncodingOptions(
        useMetalAcceleration: true,
        qualityTarget: 0.8,
        speedTarget: 0.7,
        maxMemoryMB: 256,
        timeoutSeconds: 30.0
    )
    
    static let highQuality = EncodingOptions(
        useMetalAcceleration: true,
        qualityTarget: 0.95,
        speedTarget: 0.3,
        maxMemoryMB: 512,
        timeoutSeconds: 60.0
    )
    
    static let fastProcessing = EncodingOptions(
        useMetalAcceleration: true,
        qualityTarget: 0.6,
        speedTarget: 0.95,
        maxMemoryMB: 128,
        timeoutSeconds: 10.0
    )
    
    static let batteryOptimized = EncodingOptions(
        useMetalAcceleration: false,
        qualityTarget: 0.7,
        speedTarget: 0.8,
        maxMemoryMB: 64,
        timeoutSeconds: 20.0
    )
}

struct ServiceCapabilities {
    let supportsEmoji: Bool
    let supportsQR: Bool
    let supportsImageStego: Bool
    let supportsAudioChirp: Bool
    let metalAcceleration: Bool
    
    var availableModes: [Draft.Mode] {
        var modes: [Draft.Mode] = []
        if supportsEmoji { modes.append(.emoji) }
        if supportsQR { modes.append(.qr) }
        if supportsImageStego { modes.append(.imageStego) }
        if supportsAudioChirp { modes.append(.audioChirp) }
        return modes
    }
}

