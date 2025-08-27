# Metal Glass Renderer

Purpose: high-performance compute pipelines backing Purple Glass effects for rich blur, distortion, and tint.

- Pipelines: variableBlur, cryptoDistortion, glassTexture, purpleTint, animatedGlass, fastGlass
- Params: `GlassEffectParams` (blurRadius, distortionStrength, noiseIntensity, time, resolution, tintColor, opacity, brightness)
- Caching: small texture cache to limit heap churn
- Animation: CADisplayLink drives `animationTime` when active
- Integration: used by background views to precompute frames under heavy load

