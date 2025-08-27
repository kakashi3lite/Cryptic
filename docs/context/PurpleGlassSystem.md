# Purple Glass System (UI)

Purpose: semantic, accessible glassmorphism for CipherPlay that adapts by task sensitivity and mode.

- Surface colors: midnight (bg), royal/electric (brand), crystal/whisper (accents)
- Opacity presets: deep (max privacy), medium, light, crystal (interactive)
- Context mapping: Draft.mode → opacity/tint for legibility and intent
- Components: `GlassMaterial`, `GlassCard`, `GlassButton`, `CosmicGlassBackground`
- Extensibility: `contextualGlass(sensitivity:)` for AA contrast under busy backdrops

Usage
- Prefer `purpleGlass(mode:)` for defaults; override `opacity`/`tint` only if necessary
- For lists and sheets, use `CosmicGlassBackground` behind content

Performance
- Most effects are SwiftUI + materials; heavy effects defer to Metal renderer when present

