//
//  QRCodeService.swift
//  Cryptic
//
//  High-performance QR code generator with Metal acceleration and advanced error correction.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import MetalPerformanceShaders
import UIKit
import Vision
import os.log

struct QRCodeService: EncoderService, MetalAcceleratedEncoder {
    private let context: CIContext
    private let logger = Logger.codec
    
    let metalDevice: MTLDevice?
    
    init() {
        if let device = MTLCreateSystemDefaultDevice() {
            self.metalDevice = device
            self.context = CIContext(mtlDevice: device)
        } else {
            self.metalDevice = nil
            self.context = CIContext()
        }
    }
    
    // MARK: - Protocol Implementation
    
    var supportsMetalAcceleration: Bool { metalDevice != nil }
    var estimatedCapacity: Int { 2953 } // QR Code version 40 with byte mode
    var qualityPreservation: Float { 1.0 } // Lossless for digital data
    
    func encode(text: String) async throws -> EncodeResult {
        let options = MetalEncodingOptions.default
        return try await encodeWithMetal(text: text, options: options)
    }
    
    func encodeWithMetal(text: String, options: MetalEncodingOptions) async throws -> EncodeResult {
        let (result, metrics) = await PerformanceMetrics.measureAsync {
            try await _encode(text: text, options: options)
        }
        
        logger.logPerformance(metrics, operation: "QRCodeService.encode")
        return result
    }
    
    func decode(from artifact: EncodeArtifact) async throws -> DecodeResult {
        guard case .image(let image) = artifact else {
            throw CodecError.invalidInput
        }
        
        let (result, metrics) = await PerformanceMetrics.measureAsync {
            try await _decode(image: image)
        }
        
        logger.logPerformance(metrics, operation: "QRCodeService.decode")
        return result
    }
    
    // MARK: - Private Implementation
    
    private func _encode(text: String, options: MetalEncodingOptions) async throws -> EncodeResult {
        guard let data = text.data(using: .utf8), !data.isEmpty else {
            throw CodecError.invalidInput
        }
        
        guard data.count <= estimatedCapacity else {
            throw CodecError.capacityExceeded(requested: data.count, maximum: estimatedCapacity)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Determine optimal error correction level
        let correctionLevel = selectCorrectionLevel(dataSize: data.count, qualityTarget: options.qualityTarget)
        
        // Generate QR code
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel.rawValue
        
        guard let qrImage = filter.outputImage else {
            throw CodecError.unsupported
        }
        
        // Apply Metal-accelerated scaling and enhancement
        let finalImage = try await enhanceQRCode(qrImage, options: options)
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Calculate quality metrics
        let moduleSize = calculateModuleSize(for: data.count, correctionLevel: correctionLevel)
        let qualityMetrics = QualityMetrics(
            expectedPSNR: nil,
            capacityBytes: data.count,
            robustness: correctionLevel.robustness
        )
        
        let metadata: [String: Any] = [
            "correctionLevel": correctionLevel.rawValue,
            "moduleSize": moduleSize,
            "version": calculateQRVersion(for: data.count),
            "dataCapacity": estimatedCapacity,
            "usedCapacity": data.count,
            "scaleFactor": calculateScaleFactor(options: options)
        ]
        
        return EncodeResult(
            artifact: .image(finalImage),
            description: "QR Code (\(correctionLevel.rawValue), v\(calculateQRVersion(for: data.count)))",
            processingTime: processingTime,
            qualityMetrics: qualityMetrics,
            metadata: metadata
        )
    }
    
    private func _decode(image: UIImage) async throws -> DecodeResult {
        guard let cgImage = image.cgImage else {
            throw CodecError.invalidInput
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.QR]
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    
                    let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                    
                    if let result = request.results?.first,
                       let payload = result.payloadStringValue {
                        
                        let confidence = Float(result.confidence)
                        let metadata: [String: Any] = [
                            "detectedSymbology": result.symbology.rawValue,
                            "boundingBox": result.boundingBox,
                            "corners": result.topLeft ?? CGPoint.zero
                        ]
                        
                        let decodeResult = DecodeResult(
                            text: payload,
                            processingTime: processingTime,
                            confidence: confidence,
                            metadata: metadata
                        )
                        
                        continuation.resume(returning: decodeResult)
                    } else {
                        continuation.resume(throwing: CodecError.invalidInput)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func enhanceQRCode(_ ciImage: CIImage, options: MetalEncodingOptions) async throws -> UIImage {
        if options.useGPUAcceleration && supportsMetalAcceleration {
            return try await enhanceWithMetal(ciImage, options: options)
        } else {
            return enhanceWithCoreImage(ciImage, options: options)
        }
    }
    
    private func enhanceWithMetal(_ ciImage: CIImage, options: MetalEncodingOptions) async throws -> UIImage {
        guard let device = metalDevice else {
            throw CodecError.metalNotAvailable
        }
        
        let scaleFactor = calculateScaleFactor(options: options)
        
        // Create high-quality scaling using Metal
        let scaleTransform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        let scaledImage = ciImage.transformed(by: scaleTransform)
        
        // Apply sharpening filter for better readability
        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = scaledImage
        sharpenFilter.sharpness = 0.8
        
        guard let outputImage = sharpenFilter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw CodecError.unsupported
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func enhanceWithCoreImage(_ ciImage: CIImage, options: MetalEncodingOptions) -> UIImage {
        let scaleFactor = calculateScaleFactor(options: options)
        let transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        let scaledImage = ciImage.transformed(by: transform)
        
        let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent)!
        return UIImage(cgImage: cgImage)
    }
    
    private func calculateScaleFactor(options: MetalEncodingOptions) -> CGFloat {
        // Balance between quality and speed
        let baseScale: CGFloat = 8.0
        let qualityBoost = CGFloat(options.qualityTarget) * 4.0 // 0-4 additional scale
        let speedPenalty = CGFloat(1.0 - options.speedTarget) * 2.0 // 0-2 reduction
        
        return max(4.0, baseScale + qualityBoost - speedPenalty)
    }
    
    // MARK: - QR Code Optimization
    
    private func selectCorrectionLevel(dataSize: Int, qualityTarget: Float) -> QRCorrectionLevel {
        if qualityTarget >= 0.9 {
            return .high // 30% error recovery
        } else if qualityTarget >= 0.7 {
            return .quartile // 25% error recovery
        } else if qualityTarget >= 0.5 {
            return .medium // 15% error recovery
        } else {
            return .low // 7% error recovery
        }
    }
    
    private func calculateQRVersion(for dataSize: Int) -> Int {
        // Simplified version calculation based on data size
        switch dataSize {
        case 0...25: return 1
        case 26...47: return 2
        case 48...77: return 3
        case 78...114: return 4
        case 115...154: return 5
        case 155...195: return 6
        case 196...224: return 7
        case 225...279: return 8
        case 280...335: return 9
        case 336...395: return 10
        default: return min(40, (dataSize / 100) + 10)
        }
    }
    
    private func calculateModuleSize(for dataSize: Int, correctionLevel: QRCorrectionLevel) -> Int {
        let version = calculateQRVersion(for: dataSize)
        return 21 + (version - 1) * 4 // Standard QR module count formula
    }
}

// MARK: - Supporting Types

enum QRCorrectionLevel: String, CaseIterable {
    case low = "L"
    case medium = "M"
    case quartile = "Q"
    case high = "H"
    
    var robustness: Float {
        switch self {
        case .low: return 0.7
        case .medium: return 0.85
        case .quartile: return 0.95
        case .high: return 0.99
        }
    }
    
    var errorRecoveryPercentage: Float {
        switch self {
        case .low: return 0.07
        case .medium: return 0.15
        case .quartile: return 0.25
        case .high: return 0.30
        }
    }
}

