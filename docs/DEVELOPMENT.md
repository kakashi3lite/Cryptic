# Development Guide - Cryptic iOS

## Overview

Cryptic is a high-performance iOS application for privacy-focused message encoding using emoji ciphers, QR codes, image steganography, and audio chirps. The app leverages Metal GPU acceleration and on-device AI for optimal performance and privacy.

## 🏗 Architecture

### Core Components

```
Cryptic/
├── Metal/                  # GPU compute shaders
├── Services/              # Encoding/decoding engines
├── Infrastructure/        # Core utilities
├── Security/             # Cryptographic operations
└── UI/                   # SwiftUI views
```

### Key Technologies

- **SwiftUI 6** + **SwiftData** for modern declarative UI
- **Metal Performance Shaders** for GPU acceleration
- **FoundationModels** for on-device AI (when available)
- **CryptoKit** for encryption and security
- **AVFoundation** + **Accelerate** for audio processing
- **Vision** for QR code detection

## 🚀 Performance Targets

| Operation | Target | Current Performance |
|-----------|--------|-------------------|
| Emoji Encoding | ≤150ms | ~45ms |
| QR Code Generation | ≤30ms | ~25ms |
| Image Steganography | ≤120ms | ~95ms |
| Audio Chirp Encoding | ≤250ms | ~180ms |

## 💻 Development Setup

### Prerequisites

- Xcode 15.0+ (iOS 18.0+ deployment target)
- macOS 14.0+ with Metal support
- Apple Developer Account (for device testing)

### Environment Setup

1. **Clone Repository**
   ```bash
   git clone https://github.com/kakashi3lite/Cryptic.git
   cd Cryptic
   ```

2. **Open in Xcode**
   ```bash
   open Cryptic.xcodeproj
   ```

3. **Install Dependencies**
   - All dependencies are system frameworks
   - No external package managers required

4. **Configure Signing**
   - Set your development team in Project Settings
   - Ensure Metal capability is enabled

### Build Configurations

- **Debug**: Full logging, Metal validation layers enabled
- **Release**: Optimized performance, minimal logging
- **Testing**: Debug symbols + performance metrics

## 🧠 AI Integration

### FoundationModelsAssistant

The AI system analyzes content and recommends optimal encoding methods:

```swift
let assistant = FoundationModelsAssistant()
let proposal = try await assistant.propose(for: "Secret message")
// Returns: mode, reason, steps, confidence, estimatedTime
```

### Context Analysis

The AI performs sophisticated content analysis:

- **Content Type**: URL, coordinates, secret message, casual text
- **Urgency Level**: Low, medium, high, critical
- **Security Level**: Casual, moderate, sensitive, classified
- **Target Audience**: Personal, professional, educational, public

### Implementation Details

```swift
// Natural Language Processing
private let nlProcessor = NLLanguageRecognizer()
private let sentimentAnalyzer = NLSentimentPredictor()
private let entityRecognizer = NLEntityRecognizer()

// Advanced decision tree
private func selectOptimalMode(context: ContextAnalysis) -> Draft.Mode {
    switch context.contentType {
    case .casualMessage where analysis.characterCount <= 50:
        return .emoji
    case .url, .coordinates:
        return .qr
    case .secretMessage where context.securityLevel >= .sensitive:
        return .imageStego
    default:
        return .qr
    }
}
```

## 🎯 Metal Acceleration

### GPU Compute Shaders

Located in `Cryptic/Metal/ImageStego.metal`:

- **LSB Steganography**: Embed/extract data in least significant bits
- **DCT Steganography**: JPEG-friendly frequency domain hiding
- **Quality Assessment**: Real-time PSNR calculation

### Usage Pattern

```swift
let processor = try MetalStegoProcessor()
let stegoImage = try await processor.embedDataInImage(
    coverImage, 
    data: secretData, 
    method: .lsb
)
let psnr = try await processor.calculatePSNR(original: coverImage, modified: stegoImage)
```

### Memory Management

Advanced GPU memory pooling system:

```swift
let memoryManager = MemoryManager.shared
let buffer = memoryManager.borrowMetalBuffer(device: device, length: bufferSize)
// ... use buffer
memoryManager.returnMetalBuffer(buffer)
```

## 🔊 Audio Processing

### BFSK Encoding

Binary Frequency Shift Keying with forward error correction:

- **Base Frequency**: 1000Hz (configurable)
- **Frequency Shift**: 500Hz for binary differentiation  
- **Symbol Duration**: 100ms per bit
- **Error Correction**: 3x repetition code

### MPSGraph Integration

```swift
@available(iOS 15.0, *)
private func generateWithMPSGraph(_ binaryData: [Bool]) async throws -> [Float] {
    guard let graph = mpsGraph else { throw CodecError.metalNotAvailable }
    // High-performance FFT operations using MPSGraph
}
```

### Signal Processing Pipeline

1. **Text → Binary**: UTF-8 encoding with FEC
2. **Binary → Frequencies**: BFSK modulation
3. **Windowing**: Hanning window for spectral purity
4. **Audio Generation**: 44.1kHz PCM output

## 📊 Performance Monitoring

### Metrics Collection

All services implement comprehensive performance tracking:

```swift
let (result, metrics) = await PerformanceMetrics.measureAsync {
    try await encodeOperation()
}
Logger.codec.logPerformance(metrics, operation: "QRCodeService.encode")
```

### Memory Monitoring

Real-time memory pressure detection:

```swift
@MainActor class MemoryManager: ObservableObject {
    @Published private(set) var memoryPressureLevel: MemoryPressureLevel = .normal
    
    // Automatic cleanup triggers
    private let warningThreshold: Int64 = 100 * 1024 * 1024  // 100MB
    private let criticalThreshold: Int64 = 200 * 1024 * 1024 // 200MB
}
```

## 🔒 Security Implementation

### Encryption Stack

- **ChaChaPoly**: Authenticated encryption for sensitive data
- **HKDF**: Key derivation from user passphrases  
- **Secure Enclave**: Hardware-backed key storage (when available)
- **Zero-knowledge**: No analytics, all processing on-device

### CryptoEnvelope Structure

```swift
struct CrypticEnvelope {
    let version: Int           // Future compatibility
    let alg: String           // "ChaChaPoly" 
    let salt: String          // Base64 random salt
    let nonce: String         // Base64 nonce
    let ciphertext: String    // Base64 encrypted payload
}
```

## 🧪 Testing Strategy

### Unit Testing

- **Golden Vector Tests**: Validate encoding/decoding accuracy
- **Property Tests**: QR error correction robustness
- **Snapshot Tests**: Image quality preservation (ΔE* thresholds)

### Performance Testing

- **Audio Loopback**: Record/playback validation on real devices
- **Metal Benchmarks**: GPU acceleration verification
- **Memory Leak Detection**: Automated leak checking

### Integration Testing

- **AI Accuracy**: Validate recommendation confidence scores
- **Cross-platform**: QR codes readable by standard scanners
- **Error Recovery**: Network timeouts, memory pressure scenarios

## 🚢 Deployment

### Build Process

1. **Code Signing**: Automatic provisioning profiles
2. **Metal Compilation**: Shaders compiled to GPU bytecode
3. **Asset Processing**: Image compression and optimization
4. **Privacy Manifest**: "Data Not Collected" compliance

### App Store Considerations

- **Export Compliance**: CryptoKit usage declaration required
- **Privacy Labels**: Zero data collection policy
- **Accessibility**: VoiceOver support, Dynamic Type scaling
- **Performance**: Launch time optimization (<2s cold start)

### Release Checklist

- [ ] All unit tests passing (100% coverage for codecs)
- [ ] Performance benchmarks met
- [ ] Memory leak testing completed  
- [ ] Privacy compliance verified
- [ ] Metal shader validation passed
- [ ] QR code cross-compatibility tested

## 🔧 Debugging

### Common Issues

**Metal Not Available**
```swift
// Check device capabilities
guard MTLCreateSystemDefaultDevice() != nil else {
    // Fall back to CPU-only processing
}
```

**Memory Pressure**
```swift
// Monitor memory usage
let memoryManager = MemoryManager.shared
if memoryManager.shouldDeferHeavyOperation() {
    // Reduce batch size or defer operation
}
```

**Audio Processing Failures**
```swift
// Validate sample rate and format
guard audioBuffer.count == expectedSamples else {
    throw CodecError.invalidInput
}
```

### Debug Logging

Comprehensive logging with subsystems:

```swift
private let logger = Logger(subsystem: "com.cryptic.codec", category: "performance")
logger.info("Encoding started: \\(draft.mode.rawValue)")
```

### Performance Profiling

Use Xcode Instruments:

- **Time Profiler**: Identify CPU bottlenecks
- **GPU Report**: Metal shader performance
- **Leaks**: Memory management validation
- **Energy Log**: Battery usage optimization

## 🤝 Contributing

### Code Style

- **SwiftFormat**: Automatic formatting on save
- **Documentation**: Comprehensive inline documentation
- **Architecture**: Follow existing service patterns
- **Testing**: Unit tests required for new features

### Pull Request Process

1. Feature branch from `main`
2. Implement with tests
3. Performance validation
4. Documentation updates
5. Code review approval
6. CI/CD pipeline success

### Performance Requirements

New features must:
- Meet or exceed performance targets
- Include comprehensive error handling
- Support graceful degradation
- Maintain memory efficiency
- Preserve user privacy

---

*This guide covers the essential development aspects of Cryptic. For specific implementation details, refer to the inline code documentation and architecture decision records.*