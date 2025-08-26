# Testing & Deployment Guide - Cryptic

## Overview

Comprehensive testing and deployment strategies for Cryptic's high-performance encoding systems, ensuring reliability across all Apple devices and deployment scenarios.

## 🧪 Testing Strategy

### Test Pyramid Architecture

```
                /\
               /  \    E2E & Integration (5%)
              /____\
             /      \   
            / Unit   \  Unit Tests (70%)
           /  Tests   \ 
          /____________\ 
         /              \
        /   Golden       \  Golden Vector & Property Tests (25%)
       /    Vector       \
      /____________________\
```

### Test Categories

1. **Unit Tests**: Individual component validation
2. **Golden Vector Tests**: Codec accuracy verification  
3. **Property Tests**: Robustness and edge cases
4. **Integration Tests**: Service interaction validation
5. **Performance Tests**: Benchmark compliance
6. **UI Tests**: User interaction workflows

## 🎯 Unit Testing

### Codec Testing Framework

Each encoding service has comprehensive unit test coverage:

```swift
class EmojiCipherTests: XCTestCase {
    let cipher = EmojiCipher()
    
    func testBasicEncoding() async throws {
        let result = try await cipher.encode(text: "hello")
        
        XCTAssertTrue(result.artifact.sizeBytes > 0)
        XCTAssertLessThan(result.processingTime, 0.1)
        XCTAssertNotNil(result.qualityMetrics)
    }
    
    func testRoundTripAccuracy() async throws {
        let originalText = "The quick brown fox jumps over the lazy dog"
        
        let encoded = try await cipher.encode(text: originalText)
        let decoded = try await cipher.decode(from: encoded.artifact)
        
        XCTAssertEqual(decoded.text.lowercased(), originalText.lowercased())
        XCTAssertGreaterThan(decoded.confidence, 0.9)
    }
    
    func testPerformanceConstraints() async throws {
        let longText = String(repeating: "performance test ", count: 100)
        
        measure {
            let _ = try! await cipher.encode(text: longText)
        }
        
        // Verify performance target: ≤150ms for emoji encoding
        XCTAssertLessThan(measureTime, 0.15)
    }
}
```

### Metal GPU Testing

Specialized tests for Metal compute shaders:

```swift
class MetalStegoProcessorTests: XCTestCase {
    let processor = try! MetalStegoProcessor()
    
    func testLSBEmbedding() async throws {
        let coverImage = generateTestImage(size: CGSize(width: 256, height: 256))
        let testData = "Secret message".data(using: .utf8)!
        
        let stegoImage = try await processor.embedDataInImage(
            coverImage, 
            data: testData, 
            method: .lsb
        )
        
        // Verify image dimensions preserved
        XCTAssertEqual(stegoImage.size, coverImage.size)
        
        // Verify data extraction
        let extractedData = try await processor.extractDataFromImage(
            stegoImage, 
            expectedLength: testData.count, 
            method: .lsb
        )
        XCTAssertEqual(extractedData, testData)
    }
    
    func testPSNRQuality() async throws {
        let original = generateTestImage(size: CGSize(width: 512, height: 512))
        let modified = try await processor.embedDataInImage(
            original, 
            data: "test".data(using: .utf8)!, 
            method: .lsb
        )
        
        let psnr = try await processor.calculatePSNR(original: original, modified: modified)
        
        // LSB should maintain high quality: PSNR > 40dB
        XCTAssertGreaterThan(psnr, 40.0)
    }
    
    func testMemoryManagement() async throws {
        let memoryBefore = getCurrentMemoryUsage()
        
        // Process multiple images
        for _ in 0..<10 {
            let image = generateTestImage(size: CGSize(width: 1024, height: 1024))
            let _ = try await processor.embedDataInImage(
                image, 
                data: "test".data(using: .utf8)!, 
                method: .lsb
            )
        }
        
        // Force cleanup
        autoreleasepool {}
        
        let memoryAfter = getCurrentMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore
        
        // Memory growth should be minimal (< 10MB)
        XCTAssertLessThan(memoryDelta, 10 * 1024 * 1024)
    }
}
```

### AI Assistant Testing

Validation of AI recommendation accuracy:

```swift
class FoundationModelsAssistantTests: XCTestCase {
    let assistant = FoundationModelsAssistant()
    
    func testURLDetection() async throws {
        let urlTexts = [
            "Check out https://example.com",
            "Visit www.apple.com for more info",
            "Go to github.com/user/repo"
        ]
        
        for text in urlTexts {
            let proposal = try await assistant.propose(for: text)
            XCTAssertEqual(proposal.mode, .qr, "URL should recommend QR encoding")
            XCTAssertGreaterThan(proposal.confidence, 0.8)
        }
    }
    
    func testSecretMessageDetection() async throws {
        let secretTexts = [
            "This is a secret message",
            "Confidential: password is abc123",
            "Private information enclosed"
        ]
        
        for text in secretTexts {
            let proposal = try await assistant.propose(for: text)
            XCTAssertTrue([.imageStego, .audioChirp].contains(proposal.mode))
            XCTAssertGreaterThan(proposal.confidence, 0.7)
        }
    }
    
    func testPerformanceBounds() async throws {
        let testText = "This is a moderately long test message to analyze performance"
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = try await assistant.propose(for: testText)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // AI analysis should complete within 50ms
        XCTAssertLessThan(duration, 0.05)
    }
}
```

## 🏆 Golden Vector Testing

### Codec Accuracy Validation

Golden vector tests ensure encoding/decoding accuracy across updates:

```swift
struct GoldenVector {
    let input: String
    let mode: Draft.Mode
    let expectedOutput: String
    let tolerance: Float
}

class GoldenVectorTests: XCTestCase {
    
    static let emojiVectors: [GoldenVector] = [
        .init(input: "hello", mode: .emoji, expectedOutput: "🔥🌈🍀🍀⭐", tolerance: 0.0),
        .init(input: "world", mode: .emoji, expectedOutput: "🌟⭐🚀🍀🦄", tolerance: 0.0),
        .init(input: "test", mode: .emoji, expectedOutput: "🎯🌈🎲🎯", tolerance: 0.0)
    ]
    
    static let qrVectors: [GoldenVector] = [
        .init(input: "https://example.com", mode: .qr, expectedOutput: "QRv3M", tolerance: 0.0),
        .init(input: "Simple text message", mode: .qr, expectedOutput: "QRv2L", tolerance: 0.0)
    ]
    
    func testEmojiGoldenVectors() async throws {
        let cipher = EmojiCipher()
        
        for vector in Self.emojiVectors {
            let result = try await cipher.encode(text: vector.input)
            
            if case .text(let encoded) = result.artifact {
                XCTAssertEqual(encoded, vector.expectedOutput, 
                             "Golden vector mismatch for input: \\(vector.input)")
            } else {
                XCTFail("Expected text artifact for emoji encoding")
            }
        }
    }
    
    func testQRGoldenVectors() async throws {
        let qrService = QRCodeService()
        
        for vector in Self.qrVectors {
            let result = try await qrService.encode(text: vector.input)
            
            // Verify QR can be decoded back to original
            let decoded = try await qrService.decode(from: result.artifact)
            XCTAssertEqual(decoded.text, vector.input)
            XCTAssertGreaterThan(decoded.confidence, 0.99)
        }
    }
}
```

### Cross-Platform Compatibility

Ensure QR codes are readable by standard scanners:

```swift
class CrossPlatformCompatibilityTests: XCTestCase {
    
    func testQRCodeStandardCompliance() async throws {
        let qrService = QRCodeService()
        let testData = "https://cryptic.app/test"
        
        let result = try await qrService.encode(text: testData)
        
        guard case .image(let qrImage) = result.artifact else {
            XCTFail("Expected image artifact")
            return
        }
        
        // Test with iOS Vision framework (simulates standard scanner)
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.QR]
        
        let handler = VNImageRequestHandler(cgImage: qrImage.cgImage!)
        try handler.perform([request])
        
        guard let observation = request.results?.first,
              let payload = observation.payloadStringValue else {
            XCTFail("QR code not readable by standard scanner")
            return
        }
        
        XCTAssertEqual(payload, testData)
        XCTAssertGreaterThan(observation.confidence, 0.95)
    }
}
```

## 🔬 Property-Based Testing

### QR Code Error Correction Testing

Validate error correction capabilities:

```swift
class QRErrorCorrectionPropertyTests: XCTestCase {
    
    func testErrorRecoveryProperty() async throws {
        let qrService = QRCodeService()
        let testMessages = generateRandomStrings(count: 100, maxLength: 200)
        
        for message in testMessages {
            let encoded = try await qrService.encode(text: message)
            
            guard case .image(let qrImage) = encoded.artifact else { continue }
            
            // Introduce random errors (up to error correction limit)
            let corruptedImage = introduceRandomErrors(qrImage, errorRate: 0.15) // 15% corruption
            
            // Should still decode successfully
            let decoded = try await qrService.decode(from: .image(corruptedImage))
            XCTAssertEqual(decoded.text, message, 
                         "Error correction failed for message: \\(message)")
        }
    }
    
    func testDataCapacityLimits() async throws {
        let qrService = QRCodeService()
        
        // Test boundary conditions
        let capacityLimits = [
            25,    // Version 1 numeric
            47,    // Version 2 alphanumeric  
            77,    // Version 3 byte
            2953   // Version 40 maximum
        ]
        
        for limit in capacityLimits {
            let testData = String(repeating: "A", count: limit)
            
            // Should encode without error at capacity limit
            XCTAssertNoThrow(try await qrService.encode(text: testData))
            
            // Should fail gracefully when exceeding capacity
            let oversizedData = testData + "X"
            do {
                let _ = try await qrService.encode(text: oversizedData)
                XCTFail("Should have thrown capacity exceeded error")
            } catch CodecError.capacityExceeded {
                // Expected error
            } catch {
                XCTFail("Unexpected error type: \\(error)")
            }
        }
    }
}
```

### Audio Processing Robustness

Test audio encoding under various noise conditions:

```swift
class AudioChirpPropertyTests: XCTestCase {
    
    func testNoiseResistanceProperty() async throws {
        let audioService = AudioChirpService()
        let testMessages = generateRandomStrings(count: 50, maxLength: 100)
        
        for message in testMessages {
            let encoded = try await audioService.encode(text: message)
            
            guard case .audio(let audioData) = encoded.artifact else { continue }
            
            // Add various types of noise
            let noisyAudio = addGaussianNoise(audioData, snr: 20.0) // 20dB SNR
            let decoded = try await audioService.decode(from: .audio(noisyAudio))
            
            // Should decode with reasonable confidence
            XCTAssertEqual(decoded.text, message)
            XCTAssertGreaterThan(decoded.confidence, 0.6)
        }
    }
    
    func testFrequencyDriftTolerance() async throws {
        let audioService = AudioChirpService()
        let testMessage = "frequency test"
        
        let encoded = try await audioService.encode(text: testMessage)
        guard case .audio(let audioData) = encoded.artifact else {
            XCTFail("Expected audio artifact")
            return
        }
        
        // Simulate frequency drift (±50Hz)
        let driftedAudio = applyFrequencyDrift(audioData, maxDrift: 50.0)
        let decoded = try await audioService.decode(from: .audio(driftedAudio))
        
        XCTAssertEqual(decoded.text, testMessage)
        XCTAssertGreaterThan(decoded.confidence, 0.5)
    }
}
```

## 📊 Performance Testing

### Benchmark Validation

Automated performance regression testing:

```swift
class PerformanceRegressionTests: XCTestCase {
    
    struct PerformanceBenchmark {
        let operation: String
        let target: TimeInterval
        let tolerance: TimeInterval
    }
    
    static let benchmarks: [PerformanceBenchmark] = [
        .init(operation: "emoji_encode_100chars", target: 0.045, tolerance: 0.010),
        .init(operation: "qr_encode_400chars", target: 0.025, tolerance: 0.005),
        .init(operation: "image_stego_1080p", target: 0.095, tolerance: 0.020),
        .init(operation: "audio_chirp_50chars", target: 0.180, tolerance: 0.030)
    ]
    
    func testPerformanceBenchmarks() async throws {
        let coordinator = EncodeCoordinator()
        
        for benchmark in Self.benchmarks {
            let draft = createTestDraft(for: benchmark.operation)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let _ = try await coordinator.encode(draft: draft)
            let actualTime = CFAbsoluteTimeGetCurrent() - startTime
            
            let maxAllowedTime = benchmark.target + benchmark.tolerance
            XCTAssertLessThan(actualTime, maxAllowedTime, 
                            "Performance regression in \\(benchmark.operation): " +
                            "\\(actualTime)s > \\(maxAllowedTime)s")
        }
    }
    
    func testMemoryUsageBounds() async throws {
        let memoryBefore = getCurrentMemoryUsage()
        
        // Perform intensive operations
        let coordinator = EncodeCoordinator()
        let largeDraft = Draft(mode: .imageStego, text: String(repeating: "A", count: 1000))
        
        let _ = try await coordinator.encode(draft: largeDraft)
        
        let memoryAfter = getCurrentMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore
        
        // Memory usage should be bounded (< 100MB for any single operation)
        XCTAssertLessThan(memoryDelta, 100 * 1024 * 1024)
    }
}
```

### Load Testing

Stress testing under heavy concurrent usage:

```swift
class LoadTests: XCTestCase {
    
    func testConcurrentEncodingLoad() async throws {
        let coordinator = EncodeCoordinator()
        let concurrentOperations = 20
        
        await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOperations {
                group.addTask {
                    let draft = Draft(mode: .qr, text: "Concurrent test \\(i)")
                    let _ = try await coordinator.encode(draft: draft)
                }
            }
        }
        
        // All operations should complete without errors
        // Verify system remains responsive
        let memoryManager = MemoryManager.shared
        XCTAssertLessThan(memoryManager.getMemoryStats().currentUsageMB, 200)
    }
    
    func testBatchProcessingScalability() async throws {
        let coordinator = EncodeCoordinator()
        let batchSizes = [1, 5, 10, 20, 50]
        
        for batchSize in batchSizes {
            let drafts = (0..<batchSize).map { i in
                Draft(mode: .emoji, text: "Batch test \\(i)")
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let results = try await coordinator.encodeBatch(drafts)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            XCTAssertEqual(results.count, batchSize)
            
            // Batch processing should show efficiency gains
            let expectedLinearTime = 0.05 * Double(batchSize) // 50ms per item
            let efficiencyRatio = duration / expectedLinearTime
            
            if batchSize > 1 {
                XCTAssertLessThan(efficiencyRatio, 0.8, "Batch processing not efficient enough")
            }
        }
    }
}
```

## 🎭 UI Testing

### User Workflow Validation

End-to-end user interaction testing:

```swift
class CrypticUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        app = XCUIApplication()
        app.launch()
        continueAfterFailure = false
    }
    
    func testBasicEncodingFlow() throws {
        // Create new draft
        app.buttons["Add"].tap()
        app.buttons["New Draft"].tap()
        
        // Enter text
        let textField = app.textFields["draft.text"]
        textField.tap()
        textField.typeText("Hello World Test")
        
        // Select encoding mode
        app.buttons["Mode: Emoji"].tap()
        app.buttons["QR Code"].tap()
        
        // Encode
        app.buttons["Encode"].tap()
        
        // Verify result
        let resultView = app.images["encoded.result"]
        XCTAssertTrue(resultView.waitForExistence(timeout: 2.0))
        
        // Share functionality
        app.buttons["Share"].tap()
        let shareSheet = app.sheets.firstMatch
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 1.0))
        
        app.buttons["Cancel"].tap()
    }
    
    func testAIRecommendationFlow() throws {
        app.buttons["Add"].tap()
        app.buttons["New Draft"].tap()
        
        // Enter URL to trigger AI recommendation
        let textField = app.textFields["draft.text"]
        textField.tap()
        textField.typeText("https://secret-site.com/login")
        
        // AI should recommend QR mode
        let aiSuggestion = app.buttons["AI Recommends: QR Code"]
        XCTAssertTrue(aiSuggestion.waitForExistence(timeout: 2.0))
        
        aiSuggestion.tap()
        
        // Verify mode changed
        XCTAssertTrue(app.buttons["Mode: QR Code"].exists)
    }
    
    func testPerformanceMonitoring() throws {
        // Monitor app launch performance
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
        
        // Monitor encoding performance
        app.buttons["Add"].tap()
        app.buttons["New Draft"].tap()
        
        let textField = app.textFields["draft.text"]
        textField.tap()
        textField.typeText(String(repeating: "Performance test ", count: 50))
        
        measure(metrics: [XCTClockMetric()]) {
            app.buttons["Encode"].tap()
            
            // Wait for completion
            let resultView = app.images["encoded.result"]
            _ = resultView.waitForExistence(timeout: 5.0)
        }
    }
}
```

## 🚀 Deployment Pipeline

### Build Configuration

Optimized build settings for different environments:

#### Debug Configuration
```bash
# Development builds with full debugging
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
SWIFT_OPTIMIZATION_LEVEL = -Onone
SWIFT_COMPILATION_MODE = singlefile
ENABLE_TESTABILITY = YES
MTL_ENABLE_DEBUG_INFO = YES
```

#### Release Configuration  
```bash
# Production builds optimized for performance
SWIFT_OPTIMIZATION_LEVEL = -O
SWIFT_COMPILATION_MODE = wholemodule
ENABLE_TESTABILITY = NO
DEAD_CODE_STRIPPING = YES
MTL_FAST_MATH = YES
```

### CI/CD Pipeline

GitHub Actions workflow for automated testing and deployment:

```yaml
name: iOS Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macOS-14
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Select Xcode
      run: sudo xcode-select -switch /Applications/Xcode_15.2.app
    
    - name: Build for Testing
      run: |
        xcodebuild build-for-testing \\
          -project Cryptic.xcodeproj \\
          -scheme Cryptic \\
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
    
    - name: Run Unit Tests
      run: |
        xcodebuild test-without-building \\
          -project Cryptic.xcodeproj \\
          -scheme Cryptic \\
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \\
          -testPlan UnitTests
    
    - name: Run Performance Tests
      run: |
        xcodebuild test-without-building \\
          -project Cryptic.xcodeproj \\
          -scheme Cryptic \\
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \\
          -testPlan PerformanceTests
    
    - name: Archive for Distribution
      if: github.ref == 'refs/heads/main'
      run: |
        xcodebuild archive \\
          -project Cryptic.xcodeproj \\
          -scheme Cryptic \\
          -destination generic/platform=iOS \\
          -archivePath ./build/Cryptic.xcarchive
    
    - name: Export IPA
      if: github.ref == 'refs/heads/main'
      run: |
        xcodebuild -exportArchive \\
          -archivePath ./build/Cryptic.xcarchive \\
          -exportPath ./build \\
          -exportOptionsPlist ExportOptions.plist
```

### Device Testing Matrix

Comprehensive device coverage for validation:

| Device Category | Models | iOS Versions | Test Coverage |
|----------------|--------|--------------|---------------|
| Latest Pro | iPhone 15 Pro/Max | iOS 17.0+ | Full suite |
| Current Standard | iPhone 15/Plus | iOS 17.0+ | Full suite |  
| Previous Gen | iPhone 14 Series | iOS 16.0+ | Core features |
| Legacy | iPhone 12/13 Series | iOS 15.0+ | Basic functions |
| iPad | iPad Air/Pro (M1+) | iPadOS 17.0+ | Full suite |

### App Store Deployment

#### Pre-submission Checklist

- [ ] All unit tests passing (100% for core codecs)
- [ ] Performance benchmarks met
- [ ] Memory leak testing completed
- [ ] UI testing across all supported devices
- [ ] Privacy compliance verification
- [ ] Export compliance documentation
- [ ] TestFlight beta testing completed
- [ ] Accessibility validation (VoiceOver, Dynamic Type)

#### App Store Connect Configuration

```plist
<!-- Export compliance for cryptography -->
<key>ITSAppUsesNonExemptEncryption</key>
<true/>
<key>ITSEncryptionExportComplianceCode</key>
<string>YOUR_COMPLIANCE_CODE</string>

<!-- Privacy manifest -->
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSFileSystemPathAccess</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>C617.1</string>
        </array>
    </dict>
</array>
```

### Production Monitoring

#### Crash Reporting

Integrated crash reporting with performance context:

```swift
func configureCrashReporting() {
    // Configure crash reporting service
    CrashReporter.shared.configure { reporter in
        reporter.setCustomKey("metalSupported", value: MTLCreateSystemDefaultDevice() != nil)
        reporter.setCustomKey("memoryPressure", value: MemoryManager.shared.memoryPressureLevel.rawValue)
        reporter.setCustomKey("activeOperations", value: EncodeCoordinator.shared.activeOperationCount)
    }
}
```

#### Performance Telemetry

Anonymous performance metrics collection:

```swift
struct PerformanceTelemetry {
    static func recordOperation(_ operation: String, duration: TimeInterval, success: Bool) {
        guard UserDefaults.standard.bool(forKey: "analyticsEnabled") else { return }
        
        let event = PerformanceEvent(
            operation: operation,
            duration: duration,
            success: success,
            deviceModel: UIDevice.current.model,
            iosVersion: UIDevice.current.systemVersion,
            timestamp: Date()
        )
        
        // Send to analytics service (anonymized)
        TelemetryService.shared.record(event)
    }
}
```

### Hotfix Deployment

Emergency deployment process for critical issues:

1. **Hotfix Branch**: Create from latest production tag
2. **Minimal Change**: Address only critical issue
3. **Expedited Testing**: Core functionality validation only
4. **Emergency Review**: Fast-track App Store review
5. **Rollout Strategy**: Phased deployment with monitoring

## 📋 Release Checklist

### Pre-Release Validation

#### Code Quality
- [ ] SwiftLint warnings resolved
- [ ] Code review completed
- [ ] Documentation updated
- [ ] API changes documented

#### Testing
- [ ] Unit test coverage >95%
- [ ] Golden vector tests passing
- [ ] Performance regression tests passing
- [ ] UI tests on all target devices
- [ ] Memory leak validation
- [ ] Accessibility testing

#### Performance
- [ ] All KPI targets met
- [ ] Battery usage within limits
- [ ] Thermal testing completed
- [ ] Memory pressure handling verified

#### Security & Privacy
- [ ] Privacy manifest updated
- [ ] Export compliance documentation
- [ ] Security audit completed
- [ ] No sensitive data logging

#### App Store Compliance
- [ ] Human Interface Guidelines compliance
- [ ] App Store Review Guidelines compliance
- [ ] Privacy policy updated
- [ ] Metadata and screenshots prepared

### Post-Release Monitoring

#### First 24 Hours
- Monitor crash rates (<0.1%)
- Track performance metrics
- Watch user feedback
- Monitor memory usage patterns

#### First Week
- Analyze usage patterns
- Review performance telemetry
- Address user feedback
- Plan next iteration

---

*This testing and deployment guide ensures Cryptic maintains the highest standards of quality, performance, and user experience across all supported devices and deployment scenarios.*