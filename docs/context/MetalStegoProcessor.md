# MetalStegoProcessor

Purpose: orchestrates `ImageStego.metal` kernels for encode/decode with guard bands and resource reuse.

- Interface: encode(text/data, into: UIImage) -> UIImage; decode(from: UIImage) -> Data
- Parameters: capacity limits, ECC toggles, perceptual score gates
- Integration: future `ImageStego` `EncoderService` implementation

