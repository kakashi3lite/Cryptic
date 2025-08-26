//
//  CodecKit.swift
//  Cryptic
//
//  High-performance codec protocols with async/await support and Metal acceleration.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Artifacts and Results

enum EncodeArtifact: Equatable {
    case text(String)
    case image(UIImage)
    case data(Data)
    case audio(Data) // WAV/PCM audio data
    
    var sizeBytes: Int {
        switch self {
        case .text(let string):
            return string.utf8.count
        case .image(let uiImage):
            return uiImage.pngData()?.count ?? 0
        case .data(let data), .audio(let data):
            return data.count
        }
    }
}

struct EncodeResult: Equatable {
    let artifact: EncodeArtifact
    let description: String
    let processingTime: TimeInterval
    let qualityMetrics: QualityMetrics?
    let metadata: [String: Any]?
    
    init(artifact: EncodeArtifact, description: String, processingTime: TimeInterval = 0, qualityMetrics: QualityMetrics? = nil, metadata: [String: Any]? = nil) {
        self.artifact = artifact
        self.description = description
        self.processingTime = processingTime
        self.qualityMetrics = qualityMetrics
        self.metadata = metadata
    }
    
    static func == (lhs: EncodeResult, rhs: EncodeResult) -> Bool {
        switch (lhs.artifact, rhs.artifact) {
        case let (.text(a), .text(b)): return a == b && lhs.description == rhs.description
        case (.image, .image): return lhs.description == rhs.description // images are not equatable; compare description
        case let (.data(a), .data(b)), let (.audio(a), .audio(b)): return a == b && lhs.description == rhs.description
        default: return false
        }
    }
}

struct DecodeResult {
    let text: String
    let processingTime: TimeInterval
    let confidence: Float // 0.0 - 1.0
    let metadata: [String: Any]?
    
    init(text: String, processingTime: TimeInterval = 0, confidence: Float = 1.0, metadata: [String: Any]? = nil) {
        self.text = text
        self.processingTime = processingTime
        self.confidence = confidence
        self.metadata = metadata
    }
}

// MARK: - Performance Monitoring

struct PerformanceMetrics {
    let encodeTime: TimeInterval
    let decodeTime: TimeInterval?
    let memoryUsage: Int
    let gpuUtilization: Float?
    let qualityScore: Float?
    
    static func measure<T>(_ operation: () throws -> T) rethrows -> (result: T, metrics: PerformanceMetrics) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = mach_task_basic_info().resident_size
        
        let result = try operation()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = mach_task_basic_info().resident_size
        
        let metrics = PerformanceMetrics(
            encodeTime: endTime - startTime,
            decodeTime: nil,
            memoryUsage: Int(endMemory - startMemory),
            gpuUtilization: nil,
            qualityScore: nil
        )
        
        return (result: result, metrics: metrics)
    }
    
    static func measureAsync<T>(_ operation: () async throws -> T) async rethrows -> (result: T, metrics: PerformanceMetrics) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = mach_task_basic_info().resident_size
        
        let result = try await operation()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = mach_task_basic_info().resident_size
        
        let metrics = PerformanceMetrics(
            encodeTime: endTime - startTime,
            decodeTime: nil,
            memoryUsage: Int(endMemory - startMemory),
            gpuUtilization: nil,
            qualityScore: nil
        )
        
        return (result: result, metrics: metrics)
    }
}

// MARK: - Protocols

protocol EncoderService {
    func encode(text: String) async throws -> EncodeResult
    func decode(from artifact: EncodeArtifact) async throws -> DecodeResult
    
    var supportsMetalAcceleration: Bool { get }
    var estimatedCapacity: Int { get } // Maximum bytes that can be encoded
    var qualityPreservation: Float { get } // 0.0 - 1.0, how well original quality is preserved
}

protocol MetalAcceleratedEncoder: EncoderService {
    func encodeWithMetal(text: String, options: MetalEncodingOptions) async throws -> EncodeResult
    var metalDevice: MTLDevice? { get }
}

struct MetalEncodingOptions {
    let useGPUAcceleration: Bool
    let qualityTarget: Float // 0.0 - 1.0
    let speedTarget: Float // 0.0 - 1.0 (0 = best quality, 1 = fastest)
    let maxMemoryMB: Int
    
    static let `default` = MetalEncodingOptions(
        useGPUAcceleration: true,
        qualityTarget: 0.8,
        speedTarget: 0.7,
        maxMemoryMB: 256
    )
    
    static let highQuality = MetalEncodingOptions(
        useGPUAcceleration: true,
        qualityTarget: 0.95,
        speedTarget: 0.3,
        maxMemoryMB: 512
    )
    
    static let fastProcessing = MetalEncodingOptions(
        useGPUAcceleration: true,
        qualityTarget: 0.6,
        speedTarget: 0.95,
        maxMemoryMB: 128
    )
}

// MARK: - Background Processing

actor BackgroundProcessingQueue {
    private let queue = DispatchQueue(label: "cryptic.encoding", qos: .userInitiated)
    private var activeTasks: Set<UUID> = []
    
    func enqueue<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        let taskID = UUID()
        activeTasks.insert(taskID)
        
        defer {
            Task { await self.removeTask(taskID) }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func removeTask(_ taskID: UUID) {
        activeTasks.remove(taskID)
    }
    
    var isProcessing: Bool {
        !activeTasks.isEmpty
    }
    
    var activeTaskCount: Int {
        activeTasks.count
    }
}

// MARK: - Error Handling

enum CodecError: LocalizedError {
    case unsupported
    case invalidInput
    case metalNotAvailable
    case insufficientMemory
    case processingTimeout
    case qualityThresholdNotMet(expected: Float, actual: Float)
    case capacityExceeded(requested: Int, maximum: Int)
    
    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "This encoding method is not supported on this device"
        case .invalidInput:
            return "The input data is invalid or corrupted"
        case .metalNotAvailable:
            return "Metal GPU acceleration is not available"
        case .insufficientMemory:
            return "Not enough memory to complete the operation"
        case .processingTimeout:
            return "The operation timed out"
        case .qualityThresholdNotMet(let expected, let actual):
            return "Quality threshold not met: expected \(expected), got \(actual)"
        case .capacityExceeded(let requested, let maximum):
            return "Data size (\(requested) bytes) exceeds maximum capacity (\(maximum) bytes)"
        }
    }
}

// MARK: - Utilities

private func mach_task_basic_info() -> mach_task_basic_info {
    let name = mach_task_self_
    let flavor = task_flavor_t(MACH_TASK_BASIC_INFO)
    var size = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
    let infoPointer = UnsafeMutablePointer<mach_task_basic_info>.allocate(capacity: 1)
    defer { infoPointer.deallocate() }
    
    let result = task_info(name, flavor, task_info_t(infoPointer), &size)
    guard result == KERN_SUCCESS else {
        return mach_task_basic_info()
    }
    
    return infoPointer.pointee
}

// MARK: - Logging

extension Logger {
    static let codec = Logger(subsystem: "com.cryptic.codec", category: "performance")
    
    func logPerformance(_ metrics: PerformanceMetrics, operation: String) {
        self.info("\(operation): encode=\(metrics.encodeTime, format: .fixed(precision: 3))s, memory=\(metrics.memoryUsage)b")
    }
}

