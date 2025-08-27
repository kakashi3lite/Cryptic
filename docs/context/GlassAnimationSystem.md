# Glass Animation System (UI)

Purpose: responsive, contextual animations for glass components that communicate state without harming legibility.

- Types: ripple, reveal(direction), morph(style→style), shimmer
- Controller: `GlassAnimationController` publishes current animation; views opt-in
- Components: `AnimatedGlassCard`, `AnimatedGlassBackground`, `biometricGlass`, `glassTransition`
- Guidelines: keep durations ≤ 300ms; prefer spring curves for playful modes (emoji), ease-in-out for sensitive
- Performance: coalesce state changes; avoid continuous timers; reuse layers

