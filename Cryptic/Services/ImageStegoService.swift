//
//  ImageStegoService.swift
//  Cryptic
//
//  Metal-accelerated steganography service integrating with the compute shaders.
//

import UIKit
import Foundation
import os.log

class ImageStegoService: EncoderService, MetalAcceleratedEncoder {
    private let logger = Logger.codec
    private let metalProcessor: MetalStegoProcessor
    
    let metalDevice: MTLDevice?
    
    init() throws {
        self.metalProcessor = try MetalStegoProcessor()
        self.metalDevice = metalProcessor.device
    }
    
    // MARK: - Protocol Implementation
    
    var supportsMetalAcceleration: Bool { metalDevice != nil }
    var estimatedCapacity: Int { 1048576 } // 1MB capacity for typical images
    var qualityPreservation: Float { 0.85 } // High quality preservation with LSB
    
    func encode(text: String) async throws -> EncodeResult {
        // For steganography, we need a cover image
        // In a real implementation, this would come from user selection
        let defaultCoverImage = try generateDefaultCoverImage()
        return try await encodeWithMetal(text: text, options: .default, coverImage: defaultCoverImage)
    }
    
    func encodeWithMetal(text: String, options: MetalEncodingOptions) async throws -> EncodeResult {
        let defaultCoverImage = try generateDefaultCoverImage()
        return try await encodeWithMetal(text: text, options: options, coverImage: defaultCoverImage)
    }
    
    func encodeWithMetal(text: String, options: MetalEncodingOptions, coverImage: UIImage) async throws -> EncodeResult {
        let (result, metrics) = await PerformanceMetrics.measureAsync {
            try await _encode(text: text, options: options, coverImage: coverImage)
        }
        
        logger.logPerformance(metrics, operation: "ImageStegoService.encode")
        return result
    }
    
    func decode(from artifact: EncodeArtifact) async throws -> DecodeResult {
        guard case .image(let image) = artifact else {
            throw CodecError.invalidInput
        }
        
        let (result, metrics) = await PerformanceMetrics.measureAsync {
            try await _decode(image: image)
        }
        
        logger.logPerformance(metrics, operation: "ImageStegoService.decode")
        return result
    }
    
    // MARK: - Private Implementation
    
    private func _encode(text: String, options: MetalEncodingOptions, coverImage: UIImage) async throws -> EncodeResult {
        guard !text.isEmpty else { throw CodecError.invalidInput }
        
        let textData = Data(text.utf8)
        guard textData.count <= estimatedCapacity else {
            throw CodecError.capacityExceeded(requested: textData.count, maximum: estimatedCapacity)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Add length header (4 bytes) and data
        var dataToEmbed = Data()
        let lengthBytes = withUnsafeBytes(of: UInt32(textData.count).bigEndian) { Data($0) }
        dataToEmbed.append(lengthBytes)
        dataToEmbed.append(textData)
        
        // Select steganography method based on options
        let method: StegoMethod = options.qualityTarget > 0.8 ? .dct : .lsb
        
        // Embed data using Metal-accelerated processing
        let stegoImage = try await metalProcessor.embedDataInImage(
            coverImage,
            data: dataToEmbed,
            method: method
        )
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Calculate PSNR for quality assessment
        let psnr = try await metalProcessor.calculatePSNR(original: coverImage, modified: stegoImage)
        
        // Validate quality threshold
        let expectedPSNR: Float = method == .lsb ? 45.0 : 40.0
        if psnr < expectedPSNR * options.qualityTarget {
            throw CodecError.qualityThresholdNotMet(expected: expectedPSNR * options.qualityTarget, actual: psnr)
        }
        
        let qualityMetrics = QualityMetrics(
            expectedPSNR: psnr,
            capacityBytes: textData.count,
            robustness: method == .lsb ? 0.8 : 0.9
        )
        
        let metadata: [String: Any] = [
            "method": method == .lsb ? "LSB" : "DCT",
            "psnr": psnr,
            "coverImageSize": "\(Int(coverImage.size.width))x\(Int(coverImage.size.height))",
            "dataSize": dataToEmbed.count,
            "compressionRatio": Float(stegoImage.pngData()?.count ?? 0) / Float(coverImage.pngData()?.count ?? 1),
            "qualityTarget": options.qualityTarget
        ]
        
        return EncodeResult(
            artifact: .image(stegoImage),
            description: "Image steganography (\(method == .lsb ? "LSB" : "DCT"), PSNR: \(String(format: "%.1f", psnr))dB)",
            processingTime: processingTime,
            qualityMetrics: qualityMetrics,
            metadata: metadata
        )
    }
    
    private func _decode(image: UIImage) async throws -> DecodeResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Try LSB method first, then DCT if needed
        var decodedText: String?
        var confidence: Float = 0.0
        var method: StegoMethod = .lsb
        
        do {
            // Extract length header first (4 bytes)
            let lengthData = try await metalProcessor.extractDataFromImage(image, expectedLength: 4, method: .lsb)
            let dataLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            guard dataLength > 0 && dataLength < 1000000 else { // Sanity check
                throw CodecError.invalidInput
            }
            
            // Extract the actual data
            let fullData = try await metalProcessor.extractDataFromImage(image, expectedLength: Int(dataLength) + 4, method: .lsb)
            let textData = fullData.dropFirst(4) // Remove length header
            
            if let text = String(data: Data(textData), encoding: .utf8), !text.isEmpty {
                decodedText = text
                confidence = 0.9 // High confidence for successful LSB decode
            }
        } catch {
            // Try DCT method as fallback
            do {
                method = .dct
                let lengthData = try await metalProcessor.extractDataFromImage(image, expectedLength: 4, method: .dct)
                let dataLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                
                guard dataLength > 0 && dataLength < 1000000 else {
                    throw CodecError.invalidInput
                }
                
                let fullData = try await metalProcessor.extractDataFromImage(image, expectedLength: Int(dataLength) + 4, method: .dct)
                let textData = fullData.dropFirst(4)
                
                if let text = String(data: Data(textData), encoding: .utf8), !text.isEmpty {
                    decodedText = text
                    confidence = 0.7 // Lower confidence for DCT decode
                }
            } catch {
                throw CodecError.invalidInput
            }
        }
        
        guard let text = decodedText else {
            throw CodecError.invalidInput
        }
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        let metadata: [String: Any] = [
            "method": method == .lsb ? "LSB" : "DCT",
            "imageSize": "\(Int(image.size.width))x\(Int(image.size.height))",
            "extractedLength": text.count,
            "decodeConfidence": confidence
        ]
        
        return DecodeResult(
            text: text,
            processingTime: processingTime,
            confidence: confidence,
            metadata: metadata
        )
    }
    
    private func generateDefaultCoverImage() throws -> UIImage {
        // Generate a simple cover image for demonstration
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Create a subtle gradient background
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Add some texture for better steganography
            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            for i in stride(from: 0, to: Int(size.width), by: 32) {
                for j in stride(from: 0, to: Int(size.height), by: 32) {
                    if (i/32 + j/32) % 2 == 0 {
                        context.cgContext.fill(CGRect(x: i, y: j, width: 32, height: 32))
                    }
                }
            }
        }
        
        return image
    }
}