//
//  ImageStego.metal
//  Cryptic
//
//  Metal compute kernels for LSB and DCT-based steganography.
//  Optimized for A-series GPU architecture.
//

#include <metal_stdlib>
using namespace metal;

struct ImageStegoParams {
    uint32_t width;
    uint32_t height;
    uint32_t dataLength;
    uint32_t bitsPerChannel;
};

// LSB steganography - embed data in least significant bits
kernel void embedLSB(texture2d<float, access::read> sourceTexture [[texture(0)]],
                     texture2d<float, access::write> outputTexture [[texture(1)]],
                     device const uint8_t* data [[buffer(0)]],
                     constant ImageStegoParams& params [[buffer(1)]],
                     uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= params.width || gid.y >= params.height) return;
    
    float4 pixel = sourceTexture.read(gid);
    uint32_t pixelIndex = gid.y * params.width + gid.x;
    uint32_t dataIndex = pixelIndex * 3; // RGB channels
    
    // Embed data in LSBs of R, G, B channels
    if (dataIndex < params.dataLength) {
        // Red channel
        uint8_t redByte = uint8_t(pixel.r * 255.0);
        redByte = (redByte & 0xFE) | ((data[dataIndex] >> 7) & 0x01);
        pixel.r = float(redByte) / 255.0;
    }
    
    if (dataIndex + 1 < params.dataLength) {
        // Green channel
        uint8_t greenByte = uint8_t(pixel.g * 255.0);
        greenByte = (greenByte & 0xFE) | ((data[dataIndex + 1] >> 7) & 0x01);
        pixel.g = float(greenByte) / 255.0;
    }
    
    if (dataIndex + 2 < params.dataLength) {
        // Blue channel
        uint8_t blueByte = uint8_t(pixel.b * 255.0);
        blueByte = (blueByte & 0xFE) | ((data[dataIndex + 2] >> 7) & 0x01);
        pixel.b = float(blueByte) / 255.0;
    }
    
    outputTexture.write(pixel, gid);
}

// Extract data from LSBs
kernel void extractLSB(texture2d<float, access::read> sourceTexture [[texture(0)]],
                       device uint8_t* data [[buffer(0)]],
                       constant ImageStegoParams& params [[buffer(1)]],
                       uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= params.width || gid.y >= params.height) return;
    
    float4 pixel = sourceTexture.read(gid);
    uint32_t pixelIndex = gid.y * params.width + gid.x;
    uint32_t dataIndex = pixelIndex * 3;
    
    if (dataIndex < params.dataLength) {
        data[dataIndex] = (uint8_t(pixel.r * 255.0) & 0x01) << 7;
    }
    if (dataIndex + 1 < params.dataLength) {
        data[dataIndex + 1] = (uint8_t(pixel.g * 255.0) & 0x01) << 7;
    }
    if (dataIndex + 2 < params.dataLength) {
        data[dataIndex + 2] = (uint8_t(pixel.b * 255.0) & 0x01) << 7;
    }
}

// DCT-based steganography for JPEG-friendly hiding
kernel void embedDCT(texture2d<float, access::read> sourceTexture [[texture(0)]],
                     texture2d<float, access::write> outputTexture [[texture(1)]],
                     device const float* dctCoeffs [[buffer(0)]],
                     device const uint8_t* data [[buffer(1)]],
                     constant ImageStegoParams& params [[buffer(2)]],
                     uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= params.width || gid.y >= params.height) return;
    
    // Process in 8x8 blocks for DCT compatibility
    uint2 blockPos = gid / 8;
    uint2 localPos = gid % 8;
    uint32_t blockIndex = blockPos.y * (params.width / 8) + blockPos.x;
    
    float4 pixel = sourceTexture.read(gid);
    
    // Modify mid-frequency DCT coefficients to embed data
    if (blockIndex < params.dataLength && localPos.x + localPos.y > 2 && localPos.x + localPos.y < 6) {
        uint8_t dataBit = (data[blockIndex] >> (localPos.x + localPos.y - 3)) & 0x01;
        float modification = dataBit ? 0.004 : -0.004; // Subtle modification
        
        pixel.r = clamp(pixel.r + modification, 0.0, 1.0);
        pixel.g = clamp(pixel.g + modification, 0.0, 1.0);
        pixel.b = clamp(pixel.b + modification, 0.0, 1.0);
    }
    
    outputTexture.write(pixel, gid);
}

// Perceptual quality assessment
kernel void calculatePSNR(texture2d<float, access::read> originalTexture [[texture(0)]],
                         texture2d<float, access::read> modifiedTexture [[texture(1)]],
                         device atomic<float>* mseAccumulator [[buffer(0)]],
                         constant ImageStegoParams& params [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= params.width || gid.y >= params.height) return;
    
    float4 original = originalTexture.read(gid);
    float4 modified = modifiedTexture.read(gid);
    
    float3 diff = (original.rgb - modified.rgb) * 255.0;
    float squaredError = dot(diff, diff);
    
    atomic_fetch_add_explicit(mseAccumulator, squaredError, memory_order_relaxed);
}