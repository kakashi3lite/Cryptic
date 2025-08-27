//
//  GlassEffects.metal
//  Cryptic
//
//  Advanced Metal compute shaders for custom glass blur and distortion effects.
//  Optimized for Apple A-series GPUs with sophisticated glassmorphism rendering.
//

#include <metal_stdlib>
using namespace metal;

struct GlassEffectParams {
    float blurRadius;
    float distortionStrength;
    float noiseIntensity;
    float time;
    float2 resolution;
    float4 tintColor;
    float opacity;
    float brightness;
};

// MARK: - Advanced Blur Kernels

// Custom variable blur with edge preservation
kernel void variableBlur(texture2d<float, access::read> sourceTexture [[texture(0)]],
                        texture2d<float, access::write> outputTexture [[texture(1)]],
                        constant GlassEffectParams& params [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= sourceTexture.get_width() || gid.y >= sourceTexture.get_height()) {
        return;
    }
    
    float4 center = sourceTexture.read(gid);
    float4 accumulator = float4(0.0);
    float weightSum = 0.0;
    
    // Dynamic blur radius based on content luminance
    float luminance = dot(center.rgb, float3(0.299, 0.587, 0.114));
    float adaptiveRadius = params.blurRadius * (1.0 + luminance * 0.5);
    
    int radius = int(adaptiveRadius);
    
    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            int2 samplePos = int2(gid) + int2(x, y);
            
            // Bounds checking
            if (samplePos.x < 0 || samplePos.x >= int(sourceTexture.get_width()) ||
                samplePos.y < 0 || samplePos.y >= int(sourceTexture.get_height())) {
                continue;
            }
            
            float4 sample = sourceTexture.read(uint2(samplePos));
            
            // Gaussian weight calculation
            float distance = length(float2(x, y));
            float weight = exp(-0.5 * pow(distance / adaptiveRadius, 2.0));
            
            // Edge-preserving factor
            float colorDiff = length(sample.rgb - center.rgb);
            float edgeWeight = exp(-colorDiff * 10.0);
            
            weight *= edgeWeight;
            accumulator += sample * weight;
            weightSum += weight;
        }
    }
    
    float4 blurred = accumulator / weightSum;
    outputTexture.write(blurred, gid);
}

// MARK: - Glass Distortion Effects

// Cryptographic pattern-based glass distortion
kernel void cryptoDistortion(texture2d<float, access::read> sourceTexture [[texture(0)]],
                            texture2d<float, access::write> outputTexture [[texture(1)]],
                            constant GlassEffectParams& params [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= sourceTexture.get_width() || gid.y >= sourceTexture.get_height()) {
        return;
    }
    
    float2 uv = float2(gid) / params.resolution;
    float2 center = float2(0.5);
    float2 toCenter = uv - center;
    
    // Generate AES-inspired pattern distortion
    float pattern = sin(uv.x * 16.0 + params.time) * cos(uv.y * 16.0 + params.time * 0.7);
    pattern += sin(uv.x * 8.0 - params.time * 0.5) * cos(uv.y * 12.0 + params.time);
    pattern *= 0.5;
    
    // Radial distortion from center
    float radialDist = length(toCenter);
    float radialFactor = 1.0 + radialDist * params.distortionStrength * 0.1;
    
    // Combine pattern and radial distortion
    float2 distortion = toCenter * radialFactor * params.distortionStrength * 0.02;
    distortion += float2(pattern) * params.distortionStrength * 0.005;
    
    // Sample with distorted coordinates
    float2 distortedUV = uv + distortion;
    distortedUV = clamp(distortedUV, 0.0, 1.0);
    
    uint2 samplePos = uint2(distortedUV * params.resolution);
    float4 distortedColor = sourceTexture.read(samplePos);
    
    outputTexture.write(distortedColor, gid);
}

// MARK: - Noise and Texture Generation

// Perlin-style noise for glass texture
float noise2D(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Smooth interpolation
    
    float a = noise2D(i);
    float b = noise2D(i + float2(1.0, 0.0));
    float c = noise2D(i + float2(0.0, 1.0));
    float d = noise2D(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Glass surface texture with subtle imperfections
kernel void glassTexture(texture2d<float, access::write> outputTexture [[texture(0)]],
                        constant GlassEffectParams& params [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float2 uv = float2(gid) / params.resolution;
    
    // Multi-octave noise for glass imperfections
    float noise = 0.0;
    float amplitude = 1.0;
    float frequency = 8.0;
    
    for (int i = 0; i < 4; i++) {
        noise += smoothNoise(uv * frequency + params.time * 0.1) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    // Convert to glass-like surface normal variations
    float intensity = noise * params.noiseIntensity * 0.1;
    float4 glassTexture = float4(intensity, intensity, intensity, 1.0);
    
    outputTexture.write(glassTexture, gid);
}

// MARK: - Purple Tint and Color Mixing

// Advanced color blending for purple glass effect
kernel void purpleTint(texture2d<float, access::read> sourceTexture [[texture(0)]],
                      texture2d<float, access::read> glassTexture [[texture(1)]],
                      texture2d<float, access::write> outputTexture [[texture(2)]],
                      constant GlassEffectParams& params [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= sourceTexture.get_width() || gid.y >= sourceTexture.get_height()) {
        return;
    }
    
    float4 original = sourceTexture.read(gid);
    float4 glass = glassTexture.read(gid);
    
    // Purple tint mixing with original content
    float4 tintedColor = mix(original, params.tintColor, params.opacity);
    
    // Add glass surface texture variations
    tintedColor.rgb += glass.rgb * 0.1;
    
    // Brightness adjustment
    tintedColor.rgb += float3(params.brightness);
    
    // Preserve alpha and clamp values
    tintedColor.a = original.a;
    tintedColor = clamp(tintedColor, 0.0, 1.0);
    
    outputTexture.write(tintedColor, gid);
}

// MARK: - Dynamic Glass Animation

// Animated glass surface with time-based effects
kernel void animatedGlass(texture2d<float, access::read> sourceTexture [[texture(0)]],
                         texture2d<float, access::write> outputTexture [[texture(1)]],
                         constant GlassEffectParams& params [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= sourceTexture.get_width() || gid.y >= sourceTexture.get_height()) {
        return;
    }
    
    float2 uv = float2(gid) / params.resolution;
    float4 original = sourceTexture.read(gid);
    
    // Time-based glass surface animation
    float wave1 = sin(uv.x * 10.0 + params.time * 2.0) * 0.5 + 0.5;
    float wave2 = cos(uv.y * 8.0 + params.time * 1.5) * 0.5 + 0.5;
    float wave3 = sin(length(uv - 0.5) * 15.0 - params.time * 3.0) * 0.5 + 0.5;
    
    float animation = (wave1 + wave2 + wave3) / 3.0;
    animation = smoothstep(0.3, 0.7, animation);
    
    // Apply animated transparency variation
    float dynamicOpacity = params.opacity * (0.8 + animation * 0.4);
    
    // Purple glass color with animation
    float4 glassColor = params.tintColor;
    glassColor.a = dynamicOpacity;
    
    // Blend with original using animated opacity
    float4 result = mix(original, glassColor, dynamicOpacity);
    
    // Add subtle brightness variation
    result.rgb += sin(params.time + length(uv) * 5.0) * 0.02;
    
    outputTexture.write(clamp(result, 0.0, 1.0), gid);
}

// MARK: - Depth-Based Glass Effect

// Glass effect that responds to depth/distance for layering
kernel void depthGlass(texture2d<float, access::read> sourceTexture [[texture(0)]],
                      texture2d<float, access::read> depthTexture [[texture(1)]],
                      texture2d<float, access::write> outputTexture [[texture(2)]],
                      constant GlassEffectParams& params [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= sourceTexture.get_width() || gid.y >= sourceTexture.get_height()) {
        return;
    }
    
    float4 original = sourceTexture.read(gid);
    float depth = depthTexture.read(gid).r;
    
    // Vary glass intensity based on depth
    float depthFactor = 1.0 - depth; // Closer objects = more glass effect
    float adaptiveOpacity = params.opacity * (0.5 + depthFactor * 0.5);
    float adaptiveBlur = params.blurRadius * (1.0 + depth * 0.5);
    
    // Distance-based color shifting
    float4 tintColor = params.tintColor;
    tintColor.rgb = mix(tintColor.rgb, float3(0.9, 0.8, 1.0), depth * 0.3);
    
    // Apply depth-modified glass effect
    float4 glassEffect = mix(original, tintColor, adaptiveOpacity);
    
    outputTexture.write(glassEffect, gid);
}

// MARK: - Performance-Optimized Single-Pass Glass

// Efficient single-pass glass effect for real-time use
kernel void fastGlass(texture2d<float, access::read> sourceTexture [[texture(0)]],
                     texture2d<float, access::write> outputTexture [[texture(1)]],
                     constant GlassEffectParams& params [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= sourceTexture.get_width() || gid.y >= sourceTexture.get_height()) {
        return;
    }
    
    float4 original = sourceTexture.read(gid);
    float2 uv = float2(gid) / params.resolution;
    
    // Fast blur approximation using 4-sample pattern
    float4 blur = float4(0.0);
    blur += sourceTexture.read(gid + uint2(1, 0)) * 0.25;
    blur += sourceTexture.read(gid + uint2(0, 1)) * 0.25;
    blur += sourceTexture.read(gid - uint2(1, 0)) * 0.25;  
    blur += sourceTexture.read(gid - uint2(0, 1)) * 0.25;
    
    // Quick noise for surface texture
    float noise = sin(uv.x * 47.0 + uv.y * 73.0 + params.time) * 0.5 + 0.5;
    noise = noise * params.noiseIntensity * 0.05;
    
    // Combine blur, tint, and noise
    float4 result = mix(blur, params.tintColor, params.opacity);
    result.rgb += noise;
    result.a = params.opacity;
    
    // Blend with original
    result = mix(original, result, params.opacity);
    
    outputTexture.write(clamp(result, 0.0, 1.0), gid);
}