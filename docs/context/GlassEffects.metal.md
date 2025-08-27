# GlassEffects.metal (Kernels)

Kernels
- `variableBlur`: adaptive blur with edge preservation
- `cryptoDistortion`: pattern-based radial distortion with time-based animation
- `glassTexture`: multi-octave noise for surface imperfections
- `purpleTint`: tint and brightness blend with glass texture
- `animatedGlass`: time-varying composite (see renderer)

Usage
- Provide `GlassEffectParams` via buffer(0); read/write 2D textures
- Clamp sampling and respect bounds; prefer half-precision where possible (future)

