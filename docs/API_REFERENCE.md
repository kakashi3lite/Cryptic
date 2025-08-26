# API Reference - Cryptic iOS

## Overview

Cryptic provides a comprehensive API for high-performance message encoding and decoding. All services support async/await patterns with Metal GPU acceleration where available.

## 🏗 Core Architecture

### Service Protocols

All encoding services implement the `EncoderService` protocol for consistent behavior:

```swift
protocol EncoderService {
    func encode(text: String) async throws -> EncodeResult
    func decode(from artifact: EncodeArtifact) async throws -> DecodeResult
    
    var supportsMetalAcceleration: Bool { get }
    var estimatedCapacity: Int { get }
    var qualityPreservation: Float { get }
}
```

### Data Types

#### EncodeArtifact

Represents encoded output in various formats:

```swift
enum EncodeArtifact: Equatable {
    case text(String)           // Emoji-encoded text
    case image(UIImage)         // QR codes, steganographic images
    case data(Data)            // Raw binary data
    case audio(Data)           // WAV/PCM audio data
    
    var sizeBytes: Int { /* Returns size in bytes */ }
}
```

#### EncodeResult

Comprehensive encoding result with performance metrics:

```swift
struct EncodeResult: Equatable {
    let artifact: EncodeArtifact      // The encoded output
    let description: String           // Human-readable description
    let processingTime: TimeInterval  // Encoding duration
    let qualityMetrics: QualityMetrics? // Quality assessment
    let metadata: [String: Any]?      // Additional information
}
```

#### DecodeResult

Decoding result with confidence scoring:

```swift
struct DecodeResult {
    let text: String                  // Decoded plaintext
    let processingTime: TimeInterval  // Decoding duration
    let confidence: Float             // Success confidence (0.0-1.0)
    let metadata: [String: Any]?      // Decoding metadata
}
```

## 🎯 Emoji Cipher Service

### EmojiCipher

High-performance emoji substitution encoding with customizable themes.

#### Basic Usage

```swift
let cipher = EmojiCipher()

// Encoding
let result = try await cipher.encode(text: "Hello World")
// Returns: "🔥🌈🍀🍀⭐ 🌟⭐🚀🍀🦄"

// Decoding
let decoded = try await cipher.decode(from: .text("🔥🌈🍀🍀⭐ 🌟⭐🚀🍀🦄"))
// Returns: DecodeResult(text: "hello world", confidence: 0.95)
```

#### Custom Themes

```swift
let customMapping = EmojiCipher.createCustomMapping(theme: .animals)
// Supports: .animals, .food, .nature, .objects

// Theme-specific encoding
let animalCipher = EmojiCipher(mapping: customMapping)
let result = try await animalCipher.encode(text: "secret")
// Returns animal-themed emoji sequence
```

#### Performance Characteristics

- **Capacity**: Unlimited (scales with text length)
- **Speed**: ~45ms for 100 characters
- **Quality Preservation**: 1.0 (lossless)
- **Metal Acceleration**: No (CPU-optimized)

## 📱 QR Code Service

### QRCodeService

Metal-accelerated QR code generation with adaptive error correction.

#### Basic Usage

```swift
let qrService = QRCodeService()

// High-level encoding (uses default Metal options)
let result = try await qrService.encode(text: "https://example.com")
// Returns: EncodeResult with UIImage artifact

// Decoding with Vision framework
let decoded = try await qrService.decode(from: .image(qrImage))
// Returns: DecodeResult with confidence score
```

#### Advanced Configuration

```swift
// Custom Metal options for performance tuning
let options = MetalEncodingOptions(
    useGPUAcceleration: true,
    qualityTarget: 0.9,      // High quality
    speedTarget: 0.7,        // Balanced speed
    maxMemoryMB: 256
)

let result = try await qrService.encodeWithMetal(
    text: longUrl, 
    options: options
)
```

#### Error Correction Levels

The service automatically selects optimal error correction based on quality targets:

```swift
enum QRCorrectionLevel: String, CaseIterable {
    case low = "L"        // ~7% error recovery
    case medium = "M"     // ~15% error recovery  
    case quartile = "Q"   // ~25% error recovery
    case high = "H"       // ~30% error recovery
}
```

#### Performance Characteristics

- **Capacity**: 2,953 bytes (version 40)
- **Speed**: ~25ms with Metal acceleration
- **Quality Preservation**: 1.0 (lossless digital)
- **Metal Acceleration**: Yes (scaling and sharpening)

## 🖼 Image Steganography Service

### ImageStegoService

GPU-accelerated steganography using LSB and DCT methods.

#### Basic Usage

```swift
let stegoService = try ImageStegoService()

// Embed text in default cover image
let result = try await stegoService.encode(text: "Secret message")
// Returns: EncodeResult with steganographic image

// Extract hidden text
let decoded = try await stegoService.decode(from: .image(stegoImage))
// Returns: DecodeResult with confidence score
```

#### Custom Cover Images

```swift
let coverImage = UIImage(named: "myPhoto")!

let options = MetalEncodingOptions.highQuality
let result = try await stegoService.encodeWithMetal(
    text: secretText,
    options: options,
    coverImage: coverImage
)

// Quality validation
if let psnr = result.qualityMetrics?.expectedPSNR {
    print("Image quality: \\(psnr)dB PSNR")
}
```

#### Steganography Methods

```swift
enum StegoMethod {
    case lsb    // Least Significant Bit - faster, higher capacity
    case dct    // DCT coefficients - JPEG-resistant, lower capacity
}

// Method selection based on requirements
let method: StegoMethod = requiresJpegCompatibility ? .dct : .lsb
```

#### Performance Characteristics

- **Capacity**: ~1MB (depends on cover image size)
- **Speed**: ~95ms for 1080p image with Metal
- **Quality Preservation**: 0.85 (high with minimal artifacts)
- **Metal Acceleration**: Yes (compute shaders)

## 🔊 Audio Chirp Service

### AudioChirpService

BFSK audio encoding with MPSGraph acceleration and error correction.

#### Basic Usage

```swift
let audioService = AudioChirpService()

// Encode text as audio chirps
let result = try await audioService.encode(text: "Hidden message")
// Returns: EncodeResult with audio data

// Decode from recorded audio
let decoded = try await audioService.decode(from: .audio(recordedData))
// Returns: DecodeResult with confidence based on signal quality
```

#### Audio Parameters

```swift
// Service configuration
private let sampleRate: Double = 44100.0       // Standard audio quality
private let baseFrequency: Float = 1000.0      // Base carrier frequency
private let frequencyShift: Float = 500.0      // BFSK frequency separation
private let symbolDuration: Float = 0.1        // 100ms per bit
```

#### Forward Error Correction

Built-in 3x repetition code for noise resilience:

```swift
// Automatic FEC encoding
private func encodeWithFEC(text: String) throws -> [Bool] {
    let bits = textToBits(text)
    return bits.flatMap { bit in [bit, bit, bit] }  // Triple redundancy
}

// Majority voting decode
private func decodeWithFEC(binaryData: [Bool]) throws -> String {
    let decodedBits = stride(from: 0, to: binaryData.count, by: 3).map { i in
        let triplet = Array(binaryData[i..<min(i+3, binaryData.count)])
        return triplet.filter { $0 }.count >= 2  // Majority vote
    }
    return bitsToText(decodedBits)
}
```

#### Performance Characteristics

- **Capacity**: 1,024 characters practical limit
- **Speed**: ~180ms with MPSGraph acceleration  
- **Quality Preservation**: 0.7 (subject to environmental noise)
- **Metal Acceleration**: Yes (MPSGraph FFT on iOS 15+)

## 🎛 Encoding Coordinator

### EncodeCoordinator

Main service orchestrator with background processing and batch operations.

#### Basic Usage

```swift
@MainActor
let coordinator = EncodeCoordinator()

// Single encoding
let draft = Draft(mode: .qr, text: "Hello World")
let result = try await coordinator.encode(draft: draft)

// Batch processing
let drafts = [draft1, draft2, draft3]
let results = try await coordinator.encodeBatch(drafts)
```

#### Service Configuration

```swift
struct EncodingOptions {
    let useMetalAcceleration: Bool = true
    let qualityTarget: Float = 0.8
    let speedTarget: Float = 0.7
    let maxMemoryMB: Int = 256
    let timeoutSeconds: TimeInterval = 30.0
}

// Predefined configurations
let options = EncodingOptions.highQuality  // Best quality, slower
let options = EncodingOptions.fastProcessing  // Fastest, lower quality
let options = EncodingOptions.batteryOptimized  // No GPU acceleration
```

#### Service Capabilities

```swift
let capabilities = coordinator.getServiceCapabilities()

if capabilities.supportsImageStego {
    print("Image steganography available")
}

if capabilities.metalAcceleration {
    print("GPU acceleration enabled")
}

// Available encoding modes
let availableModes = capabilities.availableModes
// Returns: [.emoji, .qr, .imageStego, .audioChirp] (based on device)
```

## 🧠 AI Assistant

### FoundationModelsAssistant

Advanced AI for intelligent encoding recommendations.

#### Basic Usage

```swift
@MainActor
let assistant = FoundationModelsAssistant()

let proposal = try await assistant.propose(for: "https://secret-site.com/login")
// Returns optimized recommendation with reasoning
```

#### Proposal Structure

```swift
struct LLMAssistantProposal {
    let mode: Draft.Mode                    // Recommended encoding method
    let reason: String                      // Human-readable explanation
    let steps: [String]                    // Step-by-step instructions
    let confidence: Float                   // Recommendation confidence
    let estimatedTime: TimeInterval         // Expected processing time
    let qualityMetrics: QualityMetrics?     // Expected quality metrics
}
```

#### Context Analysis

```swift
let context = await assistant.analyzeContext(for: text)

struct ContextAnalysis {
    let contentType: ContentType           // .url, .secretMessage, .casualMessage
    let urgency: Urgency                  // .low, .medium, .high, .critical
    let securityLevel: SecurityLevel      // .casual, .moderate, .sensitive
    let targetAudience: TargetAudience    // .personal, .professional, .educational
}
```

#### Helper Methods

```swift
// Generate contextual clues for recipients
let clue = try await assistant.generateClue(
    for: .imageStego, 
    originalText: secretMessage
)
// Returns: "The image holds more than meets the eye..."

// Explain decoding process
let explanation = await assistant.explainDecoding(for: .audioChirp)
// Returns: "Record the audio with Cryptic's decoder..."
```

## 💾 Memory Management

### MemoryManager

Advanced memory management for Metal operations.

#### Usage

```swift
@MainActor
let memoryManager = MemoryManager.shared

// Check current memory status
let stats = memoryManager.getMemoryStats()
print("Memory usage: \\(stats.currentUsageMB)MB")

// Borrow Metal buffers (automatic pooling)
let buffer = memoryManager.borrowMetalBuffer(
    device: metalDevice, 
    length: bufferSize
)
// Use buffer...
memoryManager.returnMetalBuffer(buffer)
```

#### Memory Pressure Handling

```swift
// Check if heavy operations should be deferred
if memoryManager.shouldDeferHeavyOperation() {
    // Wait for memory pressure to reduce
    try await Task.sleep(for: .seconds(1))
}

// Get adaptive batch size
let batchSize = memoryManager.recommendedBatchSize(baseSize: 100)
// Returns smaller batches during memory pressure
```

#### Resource Tracking

```swift
// Automatic resource management with leak detection
let result = memoryManager.withManagedResource({
    return heavyProcessingOperation()
}, cleanup: {
    releaseResources()
})

// Async version
let result = await memoryManager.withManagedAsyncResource({
    return await asyncProcessingOperation()
}, cleanup: {
    await asyncCleanup()
})
```

## 📊 Performance Monitoring

### Metrics Collection

All services provide detailed performance metrics:

```swift
struct PerformanceMetrics {
    let encodeTime: TimeInterval
    let decodeTime: TimeInterval?
    let memoryUsage: Int
    let gpuUtilization: Float?
    let qualityScore: Float?
}

// Automatic measurement
let (result, metrics) = await PerformanceMetrics.measureAsync {
    try await encodingOperation()
}

Logger.codec.logPerformance(metrics, operation: "QRCodeService.encode")
```

### Quality Metrics

```swift
struct QualityMetrics {
    let expectedPSNR: Float?      // Peak Signal-to-Noise Ratio
    let capacityBytes: Int?       // Data capacity
    let robustness: Float?        // Error resilience (0.0-1.0)
}
```

## ⚡ Background Processing

### BackgroundProcessingQueue

Actor-based queue for non-blocking operations:

```swift
actor BackgroundProcessingQueue {
    func enqueue<T>(_ operation: @escaping () async throws -> T) async throws -> T
    
    var isProcessing: Bool { /* Returns current processing state */ }
    var activeTaskCount: Int { /* Returns number of active tasks */ }
}

// Usage
let queue = BackgroundProcessingQueue()
let result = try await queue.enqueue {
    try await heavyEncodingOperation()
}
```

## 🔐 Error Handling

### Error Types

```swift
enum CodecError: LocalizedError {
    case unsupported
    case invalidInput
    case metalNotAvailable
    case insufficientMemory
    case processingTimeout
    case qualityThresholdNotMet(expected: Float, actual: Float)
    case capacityExceeded(requested: Int, maximum: Int)
    
    var errorDescription: String? { /* Localized descriptions */ }
}
```

### Error Recovery

Services implement automatic retry for transient failures:

```swift
// Automatic retry logic in ContextSaver
private func isRetryableError(_ error: Error) -> Bool {
    if let nsError = error as NSError? {
        switch nsError.domain {
        case NSCocoaErrorDomain:
            return [NSFileWriteFileExistsError, NSFileWriteVolumeReadOnlyError].contains(nsError.code)
        default:
            return false
        }
    }
    return false
}
```

## 🧪 Testing Support

### Mock Services

For unit testing, mock implementations are available:

```swift
class MockEncoderService: EncoderService {
    var mockResult: EncodeResult?
    var mockError: Error?
    
    func encode(text: String) async throws -> EncodeResult {
        if let error = mockError { throw error }
        return mockResult ?? EncodeResult(artifact: .text("mocked"), description: "Mock")
    }
}
```

### Performance Testing

```swift
func testEncodingPerformance() async throws {
    let service = EmojiCipher()
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let result = try await service.encode(text: longTestText)
    
    let duration = CFAbsoluteTimeGetCurrent() - startTime
    XCTAssertLessThan(duration, 0.15, "Encoding should complete within 150ms")
}
```

## 🚀 Best Practices

### Async/Await Usage

```swift
// ✅ Correct: Use structured concurrency
func encodeMultipleTexts(_ texts: [String]) async throws -> [EncodeResult] {
    try await withThrowingTaskGroup(of: EncodeResult.self) { group in
        for text in texts {
            group.addTask {
                try await self.encoder.encode(text: text)
            }
        }
        
        var results: [EncodeResult] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}

// ❌ Incorrect: Sequential processing
func encodeMultipleTextsSlowly(_ texts: [String]) async throws -> [EncodeResult] {
    var results: [EncodeResult] = []
    for text in texts {
        let result = try await encoder.encode(text: text)  // Blocks unnecessarily
        results.append(result)
    }
    return results
}
```

### Memory Management

```swift
// ✅ Correct: Use memory manager for large operations
let result = await memoryManager.withManagedAsyncResource({
    try await imageProcessor.processLargeImage(image)
}, cleanup: {
    await imageProcessor.releaseResources()
})

// ✅ Correct: Check memory pressure before heavy operations
if !memoryManager.shouldDeferHeavyOperation() {
    try await performHeavyTask()
}
```

### Error Handling

```swift
// ✅ Correct: Handle specific error types
do {
    let result = try await service.encode(text: text)
    return result
} catch CodecError.capacityExceeded(let requested, let maximum) {
    // Offer to split the text
    return try await handleOversizedText(requested: requested, maximum: maximum)
} catch CodecError.metalNotAvailable {
    // Fall back to CPU processing
    return try await service.encode(text: text, options: .batteryOptimized)
} catch {
    // Generic error handling
    throw ProcessingError.encodingFailed(error)
}
```

---

*This API reference provides comprehensive coverage of Cryptic's encoding services. For implementation examples and advanced usage patterns, refer to the Development Guide and optimization documentation.*