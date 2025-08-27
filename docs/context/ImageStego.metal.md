# ImageStego.metal (Kernels)

Purpose: GPU-accelerated image steganography (LSB and future DCT) for PNG/JPEG.

- LSB path: toggle least-significant bits in pixel channels with guard bands
- Future DCT: operate in frequency domain for JPEG robustness
- QA: perceptual thresholds for artifact rejection

Performance
- Tile-based compute; reuse pipelines; single command buffer per frame

