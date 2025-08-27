//
//  MetalGlassRenderer.swift
//  Cryptic
//
//  High-performance Metal-based glass effect renderer for Purple Glass UI system.
//

import Metal
import MetalKit
import SwiftUI
import simd

class MetalGlassRenderer: ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Compute pipeline states for different glass effects
    private let variableBlurPipeline: MTLComputePipelineState
    private let cryptoDistortionPipeline: MTLComputePipelineState
    private let glassTexturePipeline: MTLComputePipelineState
    private let purpleTintPipeline: MTLComputePipelineState
    private let animatedGlassPipeline: MTLComputePipelineState
    private let fastGlassPipeline: MTLComputePipelineState
    
    // Texture cache for performance
    private var textureCache: [String: MTLTexture] = [:]
    private let maxCacheSize = 20
    
    // Animation state
    @Published var animationTime: Float = 0.0
    private var displayLink: CADisplayLink?
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw GlassRendererError.metalNotAvailable
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw GlassRendererError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            throw GlassRendererError.libraryNotFound
        }
        self.library = library
        
        // Create compute pipeline states
        do {
            variableBlurPipeline = try device.makeComputePipelineState(
                function: library.makeFunction(name: "variableBlur")!
            )
            cryptoDistortionPipeline = try device.makeComputePipelineState(
                function: library.makeFunction(name: "cryptoDistortion")!
            )
            glassTexturePipeline = try device.makeComputePipelineState(
                function: library.makeFunction(name: "glassTexture")!
            )
            purpleTintPipeline = try device.makeComputePipelineState(
                function: library.makeFunction(name: "purpleTint")!
            )
            animatedGlassPipeline = try device.makeComputePipelineState(
                function: library.makeFunction(name: "animatedGlass")!
            )
            fastGlassPipeline = try device.makeComputePipelineState(
                function: library.makeFunction(name: "fastGlass")!
            )
        } catch {
            throw GlassRendererError.pipelineCreationFailed(error)
        }
        
        setupDisplayLink()
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    // MARK: - Animation Management
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateAnimation() {
        animationTime += 1.0 / 60.0 // Assuming 60fps
    }
    
    // MARK: - Main Glass Rendering Interface
    
    func renderGlassEffect(
        for image: UIImage,
        style: GlassStyle,
        animated: Bool = false
    ) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw GlassRendererError.invalidImage
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create input texture
        guard let inputTexture = createTexture(from: cgImage) else {
            throw GlassRendererError.textureCreationFailed
        }
        
        // Create output texture
        guard let outputTexture = createTexture(width: width, height: height) else {
            throw GlassRendererError.textureCreationFailed
        }
        
        // Select rendering path based on performance requirements
        if animated {
            try await renderAnimatedGlass(
                input: inputTexture,
                output: outputTexture,
                style: style
            )
        } else {
            try await renderStaticGlass(
                input: inputTexture,
                output: outputTexture,
                style: style
            )
        }
        
        // Convert texture back to UIImage
        return try textureToUIImage(outputTexture)
    }
    
    // MARK: - Rendering Implementations
    
    private func renderStaticGlass(
        input: MTLTexture,
        output: MTLTexture,
        style: GlassStyle
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                continuation.resume(throwing: GlassRendererError.commandBufferCreationFailed)
                return
            }
            
            // Multi-pass rendering for high quality
            let intermediateTexture = createTexture(width: Int(input.width), height: Int(input.height))!
            
            do {
                // Pass 1: Variable blur
                try encodeVariableBlur(
                    commandBuffer: commandBuffer,
                    input: input,
                    output: intermediateTexture,
                    style: style
                )
                
                // Pass 2: Purple tint and final composition
                try encodePurpleTint(
                    commandBuffer: commandBuffer,
                    input: intermediateTexture,
                    output: output,
                    style: style
                )
                
                commandBuffer.addCompletedHandler { _ in
                    continuation.resume()
                }
                
                commandBuffer.commit()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func renderAnimatedGlass(
        input: MTLTexture,
        output: MTLTexture,
        style: GlassStyle
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                continuation.resume(throwing: GlassRendererError.commandBufferCreationFailed)
                return
            }
            
            do {
                // Single-pass animated rendering for performance
                try encodeAnimatedGlass(
                    commandBuffer: commandBuffer,
                    input: input,
                    output: output,
                    style: style
                )
                
                commandBuffer.addCompletedHandler { _ in
                    continuation.resume()
                }
                
                commandBuffer.commit()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Compute Kernel Encoding
    
    private func encodeVariableBlur(
        commandBuffer: MTLCommandBuffer,
        input: MTLTexture,
        output: MTLTexture,
        style: GlassStyle
    ) throws {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw GlassRendererError.computeEncoderCreationFailed
        }
        
        computeEncoder.setComputePipelineState(variableBlurPipeline)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)
        
        var params = style.toGlassEffectParams(animationTime: animationTime)
        computeEncoder.setBytes(&params, length: MemoryLayout<GlassEffectParams>.size, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (input.width + 15) / 16,
            height: (input.height + 15) / 16,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
    }
    
    private func encodePurpleTint(
        commandBuffer: MTLCommandBuffer,
        input: MTLTexture,
        output: MTLTexture,
        style: GlassStyle
    ) throws {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw GlassRendererError.computeEncoderCreationFailed
        }
        
        // Generate glass surface texture
        let glassTexture = createTexture(width: Int(input.width), height: Int(input.height))!
        
        // First encode glass texture
        computeEncoder.setComputePipelineState(glassTexturePipeline)
        computeEncoder.setTexture(glassTexture, index: 0)
        
        var params = style.toGlassEffectParams(animationTime: animationTime)
        computeEncoder.setBytes(&params, length: MemoryLayout<GlassEffectParams>.size, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (input.width + 15) / 16,
            height: (input.height + 15) / 16,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        // Then apply purple tint
        computeEncoder.setComputePipelineState(purpleTintPipeline)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(glassTexture, index: 1)
        computeEncoder.setTexture(output, index: 2)
        computeEncoder.setBytes(&params, length: MemoryLayout<GlassEffectParams>.size, index: 0)
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
    }
    
    private func encodeAnimatedGlass(
        commandBuffer: MTLCommandBuffer,
        input: MTLTexture,
        output: MTLTexture,
        style: GlassStyle
    ) throws {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw GlassRendererError.computeEncoderCreationFailed
        }
        
        computeEncoder.setComputePipelineState(animatedGlassPipeline)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)
        
        var params = style.toGlassEffectParams(animationTime: animationTime)
        computeEncoder.setBytes(&params, length: MemoryLayout<GlassEffectParams>.size, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (input.width + 15) / 16,
            height: (input.height + 15) / 16,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
    }
    
    // MARK: - Texture Management
    
    private func createTexture(from cgImage: CGImage) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: cgImage.width,
            height: cgImage.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        let pixelData = context.data!
        let region = MTLRegionMake2D(0, 0, cgImage.width, cgImage.height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: cgImage.width * 4)
        
        return texture
    }
    
    private func createTexture(width: Int, height: Int) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    private func textureToUIImage(_ texture: MTLTexture) throws -> UIImage {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height
        
        let pixelData = UnsafeMutableRawPointer.allocate(byteCount: totalBytes, alignment: 1)
        defer { pixelData.deallocate() }
        
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(pixelData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        guard let cgImage = context.makeImage() else {
            throw GlassRendererError.imageConversionFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Glass Style Configuration

struct GlassStyle {
    let blurRadius: Float
    let distortionStrength: Float
    let noiseIntensity: Float
    let tintColor: simd_float4
    let opacity: Float
    let brightness: Float
    
    static let lightPurple = GlassStyle(
        blurRadius: 15.0,
        distortionStrength: 0.2,
        noiseIntensity: 0.1,
        tintColor: simd_float4(0.60, 0.40, 0.85, 1.0), // Electric purple
        opacity: 0.35,
        brightness: 0.15
    )
    
    static let deepPurple = GlassStyle(
        blurRadius: 25.0,
        distortionStrength: 0.1,
        noiseIntensity: 0.05,
        tintColor: simd_float4(0.15, 0.10, 0.25, 1.0), // Midnight purple
        opacity: 0.15,
        brightness: 0.05
    )
    
    static let crystalPurple = GlassStyle(
        blurRadius: 10.0,
        distortionStrength: 0.3,
        noiseIntensity: 0.2,
        tintColor: simd_float4(0.80, 0.70, 0.95, 1.0), // Crystal purple
        opacity: 0.45,
        brightness: 0.2
    )
    
    func toGlassEffectParams(animationTime: Float) -> GlassEffectParams {
        return GlassEffectParams(
            blurRadius: blurRadius,
            distortionStrength: distortionStrength,
            noiseIntensity: noiseIntensity,
            time: animationTime,
            resolution: simd_float2(1.0, 1.0), // Will be overridden per texture
            tintColor: tintColor,
            opacity: opacity,
            brightness: brightness
        )
    }
}

// MARK: - C-compatible structs for Metal

struct GlassEffectParams {
    let blurRadius: Float
    let distortionStrength: Float
    let noiseIntensity: Float
    let time: Float
    let resolution: simd_float2
    let tintColor: simd_float4
    let opacity: Float
    let brightness: Float
}

// MARK: - Error Handling

enum GlassRendererError: LocalizedError {
    case metalNotAvailable
    case commandQueueCreationFailed
    case libraryNotFound
    case pipelineCreationFailed(Error)
    case invalidImage
    case textureCreationFailed
    case commandBufferCreationFailed
    case computeEncoderCreationFailed
    case imageConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .metalNotAvailable:
            return "Metal is not available on this device"
        case .commandQueueCreationFailed:
            return "Failed to create Metal command queue"
        case .libraryNotFound:
            return "Metal shader library not found"
        case .pipelineCreationFailed(let error):
            return "Pipeline creation failed: \(error.localizedDescription)"
        case .invalidImage:
            return "Invalid input image"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        case .commandBufferCreationFailed:
            return "Failed to create command buffer"
        case .computeEncoderCreationFailed:
            return "Failed to create compute encoder"
        case .imageConversionFailed:
            return "Failed to convert texture to image"
        }
    }
}