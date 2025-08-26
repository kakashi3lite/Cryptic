//
//  MetalStegoProcessor.swift
//  Cryptic
//
//  High-performance steganography processor using Metal compute shaders.
//

import Metal
import MetalPerformanceShaders
import UIKit
import CoreImage

class MetalStegoProcessor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private let context: CIContext
    
    // Compute pipeline states
    private let embedLSBPipeline: MTLComputePipelineState
    private let extractLSBPipeline: MTLComputePipelineState
    private let embedDCTPipeline: MTLComputePipelineState
    private let psnrPipeline: MTLComputePipelineState
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw CodecError.unsupported
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw CodecError.unsupported
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            throw CodecError.unsupported
        }
        self.library = library
        
        self.context = CIContext(mtlDevice: device)
        
        // Create compute pipeline states
        guard let embedLSBFunction = library.makeFunction(name: "embedLSB"),
              let extractLSBFunction = library.makeFunction(name: "extractLSB"),
              let embedDCTFunction = library.makeFunction(name: "embedDCT"),
              let psnrFunction = library.makeFunction(name: "calculatePSNR") else {
            throw CodecError.unsupported
        }
        
        do {
            embedLSBPipeline = try device.makeComputePipelineState(function: embedLSBFunction)
            extractLSBPipeline = try device.makeComputePipelineState(function: extractLSBFunction)
            embedDCTPipeline = try device.makeComputePipelineState(function: embedDCTFunction)
            psnrPipeline = try device.makeComputePipelineState(function: psnrFunction)
        } catch {
            throw CodecError.unsupported
        }
    }
    
    struct StegoParams {
        let width: UInt32
        let height: UInt32
        let dataLength: UInt32
        let bitsPerChannel: UInt32
    }
    
    func embedDataInImage(_ image: UIImage, data: Data, method: StegoMethod = .lsb) async throws -> UIImage {
        guard let cgImage = image.cgImage else { throw CodecError.invalidInput }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create input texture from image
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let sourceTexture = device.makeTexture(descriptor: textureDescriptor),
              let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            throw CodecError.unsupported
        }
        
        // Load image data into texture
        let ciImage = CIImage(cgImage: cgImage)
        context.render(ciImage, to: sourceTexture, commandBuffer: nil, bounds: ciImage.extent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        
        // Create data buffer
        guard let dataBuffer = device.makeBuffer(bytes: data.withUnsafeBytes { $0.baseAddress! },
                                                length: data.count,
                                                options: .storageModeShared) else {
            throw CodecError.unsupported
        }
        
        // Create params buffer
        let params = StegoParams(
            width: UInt32(width),
            height: UInt32(height),
            dataLength: UInt32(data.count),
            bitsPerChannel: 1
        )
        
        guard let paramsBuffer = device.makeBuffer(bytes: [params],
                                                 length: MemoryLayout<StegoParams>.size,
                                                 options: .storageModeShared) else {
            throw CodecError.unsupported
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                continuation.resume(throwing: CodecError.unsupported)
                return
            }
            
            let pipeline = method == .lsb ? embedLSBPipeline : embedDCTPipeline
            computeEncoder.setComputePipelineState(pipeline)
            computeEncoder.setTexture(sourceTexture, index: 0)
            computeEncoder.setTexture(outputTexture, index: 1)
            computeEncoder.setBuffer(dataBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 1)
            
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (width + threadsPerGroup.width - 1) / threadsPerGroup.width,
                height: (height + threadsPerGroup.height - 1) / threadsPerGroup.height,
                depth: 1
            )
            
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            computeEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { _ in
                // Convert texture back to image
                let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .rgba8Unorm,
                    width: width,
                    height: height,
                    mipmapped: false
                )
                
                let ciImage = CIImage(mtlTexture: outputTexture, options: nil)!
                let bounds = CGRect(x: 0, y: 0, width: width, height: height)
                
                if let cgImage = self.context.createCGImage(ciImage, from: bounds) {
                    let resultImage = UIImage(cgImage: cgImage)
                    continuation.resume(returning: resultImage)
                } else {
                    continuation.resume(throwing: CodecError.unsupported)
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    func extractDataFromImage(_ image: UIImage, expectedLength: Int, method: StegoMethod = .lsb) async throws -> Data {
        guard let cgImage = image.cgImage else { throw CodecError.invalidInput }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = .shaderRead
        
        guard let sourceTexture = device.makeTexture(descriptor: textureDescriptor) else {
            throw CodecError.unsupported
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        context.render(ciImage, to: sourceTexture, commandBuffer: nil, bounds: ciImage.extent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        
        guard let dataBuffer = device.makeBuffer(length: expectedLength, options: .storageModeShared) else {
            throw CodecError.unsupported
        }
        
        let params = StegoParams(
            width: UInt32(width),
            height: UInt32(height),
            dataLength: UInt32(expectedLength),
            bitsPerChannel: 1
        )
        
        guard let paramsBuffer = device.makeBuffer(bytes: [params],
                                                 length: MemoryLayout<StegoParams>.size,
                                                 options: .storageModeShared) else {
            throw CodecError.unsupported
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                continuation.resume(throwing: CodecError.unsupported)
                return
            }
            
            computeEncoder.setComputePipelineState(extractLSBPipeline)
            computeEncoder.setTexture(sourceTexture, index: 0)
            computeEncoder.setBuffer(dataBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 1)
            
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (width + threadsPerGroup.width - 1) / threadsPerGroup.width,
                height: (height + threadsPerGroup.height - 1) / threadsPerGroup.height,
                depth: 1
            )
            
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            computeEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { _ in
                let resultData = Data(bytes: dataBuffer.contents(), count: expectedLength)
                continuation.resume(returning: resultData)
            }
            
            commandBuffer.commit()
        }
    }
    
    func calculatePSNR(original: UIImage, modified: UIImage) async throws -> Float {
        guard let originalCG = original.cgImage,
              let modifiedCG = modified.cgImage,
              originalCG.width == modifiedCG.width,
              originalCG.height == modifiedCG.height else {
            throw CodecError.invalidInput
        }
        
        let width = originalCG.width
        let height = originalCG.height
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = .shaderRead
        
        guard let originalTexture = device.makeTexture(descriptor: textureDescriptor),
              let modifiedTexture = device.makeTexture(descriptor: textureDescriptor) else {
            throw CodecError.unsupported
        }
        
        let originalCI = CIImage(cgImage: originalCG)
        let modifiedCI = CIImage(cgImage: modifiedCG)
        
        context.render(originalCI, to: originalTexture, commandBuffer: nil, bounds: originalCI.extent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        context.render(modifiedCI, to: modifiedTexture, commandBuffer: nil, bounds: modifiedCI.extent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        
        guard let mseBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: .storageModeShared) else {
            throw CodecError.unsupported
        }
        
        let params = StegoParams(
            width: UInt32(width),
            height: UInt32(height),
            dataLength: 0,
            bitsPerChannel: 8
        )
        
        guard let paramsBuffer = device.makeBuffer(bytes: [params],
                                                 length: MemoryLayout<StegoParams>.size,
                                                 options: .storageModeShared) else {
            throw CodecError.unsupported
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                continuation.resume(throwing: CodecError.unsupported)
                return
            }
            
            computeEncoder.setComputePipelineState(psnrPipeline)
            computeEncoder.setTexture(originalTexture, index: 0)
            computeEncoder.setTexture(modifiedTexture, index: 1)
            computeEncoder.setBuffer(mseBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 1)
            
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (width + threadsPerGroup.width - 1) / threadsPerGroup.width,
                height: (height + threadsPerGroup.height - 1) / threadsPerGroup.height,
                depth: 1
            )
            
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            computeEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { _ in
                let mse = mseBuffer.contents().load(as: Float.self) / Float(width * height * 3)
                let psnr = 20.0 * log10(255.0 / sqrt(mse))
                continuation.resume(returning: psnr)
            }
            
            commandBuffer.commit()
        }
    }
}

enum StegoMethod {
    case lsb
    case dct
}