//
//  GlassAnimationSystem.swift
//  Cryptic
//
//  Responsive animation system for Purple Glass UI with contextual transitions and performance optimization.
//

import SwiftUI
import Combine

// MARK: - Glass Animation Types

enum GlassAnimation {
    case breathe(amplitude: Double, duration: Double)
    case ripple(center: CGPoint, intensity: Double)
    case shimmer(angle: Angle, speed: Double)
    case encode(progress: Double, mode: Draft.Mode)
    case reveal(progress: Double, direction: GlassRevealDirection)
    case morph(from: GlassStyle, to: GlassStyle, progress: Double)
    case biometric(isScanning: Bool, confidence: Double)
    
    var duration: TimeInterval {
        switch self {
        case .breathe(_, let duration): return duration
        case .ripple: return 1.2
        case .shimmer: return 2.0
        case .encode: return 0.8
        case .reveal: return 0.6
        case .morph: return 1.0
        case .biometric: return 2.5
        }
    }
}

enum GlassRevealDirection {
    case topToBottom
    case bottomToTop
    case leftToRight
    case rightToLeft
    case centerOut
    case edgesIn
}

// MARK: - Animation State Management

@MainActor
class GlassAnimationController: ObservableObject {
    @Published var currentAnimation: GlassAnimation?
    @Published var animationProgress: Double = 0.0
    @Published var isAnimating: Bool = false
    
    private var animationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Performance monitoring
    @Published var frameRate: Double = 60.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    private var lastFrameTime: CFTimeInterval = 0
    
    // Context-aware animation scaling
    @Published var animationScale: Double = 1.0 {
        didSet {
            updateAnimationIntensity()
        }
    }
    
    init() {
        setupPerformanceMonitoring()
        setupThermalMonitoring()
    }
    
    // MARK: - Animation Control
    
    func startAnimation(_ animation: GlassAnimation) {
        currentAnimation = animation
        isAnimating = true
        animationProgress = 0.0
        
        let scaledDuration = animation.duration * animationScale
        
        withAnimation(.easeInOut(duration: scaledDuration)) {
            animationProgress = 1.0
        }
        
        // Auto-stop animation after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + scaledDuration) {
            self.stopAnimation()
        }
    }
    
    func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            animationProgress = 0.0
            isAnimating = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentAnimation = nil
        }
    }
    
    func pauseAnimation() {
        animationTimer?.invalidate()
        isAnimating = false
    }
    
    func resumeAnimation() {
        guard currentAnimation != nil else { return }
        isAnimating = true
        // Resume animation logic here
    }
    
    // MARK: - Context-Aware Animations
    
    func animateForEncoding(mode: Draft.Mode, progress: Double) {
        let animation: GlassAnimation
        
        switch mode {
        case .emoji:
            animation = .shimmer(angle: .degrees(45), speed: 1.5)
        case .qr:
            animation = .ripple(center: CGPoint(x: 0.5, y: 0.5), intensity: 0.8)
        case .imageStego:
            animation = .reveal(progress: progress, direction: .centerOut)
        case .audioChirp:
            animation = .breathe(amplitude: 0.1, duration: 1.0)
        }
        
        startAnimation(animation)
    }
    
    func animateForBiometric(isScanning: Bool, confidence: Double = 0.0) {
        startAnimation(.biometric(isScanning: isScanning, confidence: confidence))
    }
    
    func animateTransition(from: GlassStyle, to: GlassStyle) {
        startAnimation(.morph(from: from, to: to, progress: 0.0))
    }
    
    // MARK: - Performance Optimization
    
    private func setupPerformanceMonitoring() {
        // Monitor frame rate and adjust animation complexity
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateFrameRate()
                self?.adaptAnimationComplexity()
            }
            .store(in: &cancellables)
    }
    
    private func setupThermalMonitoring() {
        NotificationCenter.default.publisher(
            for: ProcessInfo.thermalStateDidChangeNotification
        )
        .sink { [weak self] _ in
            self?.thermalState = ProcessInfo.processInfo.thermalState
            self?.adaptToThermalState()
        }
        .store(in: &cancellables)
    }
    
    private func updateFrameRate() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        if lastFrameTime > 0 {
            let deltaTime = currentTime - lastFrameTime
            frameRate = 1.0 / deltaTime
        }
        lastFrameTime = currentTime
    }
    
    private func adaptAnimationComplexity() {
        switch frameRate {
        case 0..<30:
            animationScale = 0.5 // Reduce animation complexity significantly
        case 30..<45:
            animationScale = 0.7 // Moderate reduction
        case 45..<55:
            animationScale = 0.9 // Slight reduction
        default:
            animationScale = 1.0 // Full complexity
        }
    }
    
    private func adaptToThermalState() {
        switch thermalState {
        case .serious, .critical:
            animationScale = 0.3 // Minimal animations
        case .fair:
            animationScale = 0.6 // Reduced animations
        case .nominal:
            animationScale = 1.0 // Full animations
        @unknown default:
            animationScale = 0.8 // Conservative fallback
        }
    }
    
    private func updateAnimationIntensity() {
        // Notify views to update their animation parameters
        objectWillChange.send()
    }
}

// MARK: - Animated Glass Components

struct AnimatedGlassCard<Content: View>: View {
    let mode: Draft.Mode
    let content: () -> Content
    
    @StateObject private var animationController = GlassAnimationController()
    @State private var baseOpacity: Double = 0.25
    @State private var animatedOpacity: Double = 0.25
    @State private var shimmerOffset: CGFloat = -100
    @State private var rippleScale: CGFloat = 0
    @State private var breatheScale: CGFloat = 1.0
    
    init(mode: Draft.Mode, @ViewBuilder content: @escaping () -> Content) {
        self.mode = mode
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(20)
            .background {
                AnimatedGlassBackground(
                    mode: mode,
                    opacity: animatedOpacity,
                    shimmerOffset: shimmerOffset,
                    rippleScale: rippleScale,
                    breatheScale: breatheScale
                )
            }
            .scaleEffect(breatheScale)
            .onReceive(animationController.$currentAnimation) { animation in
                handleAnimationChange(animation)
            }
            .onReceive(animationController.$animationProgress) { progress in
                updateAnimationProgress(progress)
            }
            .onAppear {
                baseOpacity = PurpleGlass.opacity(for: mode)
                animatedOpacity = baseOpacity
            }
    }
    
    private func handleAnimationChange(_ animation: GlassAnimation?) {
        guard let animation = animation else {
            resetToBaseState()
            return
        }
        
        switch animation {
        case .shimmer(let angle, let speed):
            startShimmerAnimation(angle: angle, speed: speed)
        case .ripple(_, let intensity):
            startRippleAnimation(intensity: intensity)
        case .breathe(let amplitude, let duration):
            startBreatheAnimation(amplitude: amplitude, duration: duration)
        case .encode(let progress, _):
            updateEncodingAnimation(progress: progress)
        default:
            break
        }
    }
    
    private func updateAnimationProgress(_ progress: Double) {
        // Update opacity based on animation progress
        let scaledProgress = progress * animationController.animationScale
        animatedOpacity = baseOpacity + (scaledProgress * 0.2)
    }
    
    private func startShimmerAnimation(angle: Angle, speed: Double) {
        let scaledSpeed = speed * animationController.animationScale
        
        withAnimation(
            .linear(duration: 2.0 / scaledSpeed)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 200
        }
    }
    
    private func startRippleAnimation(intensity: Double) {
        let scaledIntensity = intensity * animationController.animationScale
        
        withAnimation(
            .easeOut(duration: 1.2 * animationController.animationScale)
        ) {
            rippleScale = CGFloat(scaledIntensity * 2.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 * animationController.animationScale) {
            withAnimation(.easeIn(duration: 0.3)) {
                self.rippleScale = 0
            }
        }
    }
    
    private func startBreatheAnimation(amplitude: Double, duration: Double) {
        let scaledAmplitude = amplitude * animationController.animationScale
        let scaledDuration = duration * animationController.animationScale
        
        withAnimation(
            .easeInOut(duration: scaledDuration)
            .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.0 + CGFloat(scaledAmplitude)
        }
    }
    
    private func updateEncodingAnimation(progress: Double) {
        let scaledProgress = progress * animationController.animationScale
        
        withAnimation(.easeInOut(duration: 0.3)) {
            animatedOpacity = baseOpacity * (1.0 - scaledProgress * 0.5)
        }
    }
    
    private func resetToBaseState() {
        withAnimation(.easeOut(duration: 0.5)) {
            animatedOpacity = baseOpacity
            shimmerOffset = -100
            rippleScale = 0
            breatheScale = 1.0
        }
    }
}

// MARK: - Animated Glass Background

struct AnimatedGlassBackground: View {
    let mode: Draft.Mode
    let opacity: Double
    let shimmerOffset: CGFloat
    let rippleScale: CGFloat
    let breatheScale: CGFloat
    
    var body: some View {
        ZStack {
            // Base glass layer
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(opacity)
            
            // Purple tint layer
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PurpleGlass.color(for: mode).opacity(0.3))
                .blendMode(.overlay)
            
            // Shimmer effect
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(x: shimmerOffset)
                .mask(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            
            // Ripple effect
            if rippleScale > 0 {
                Circle()
                    .stroke(
                        Color.white.opacity(0.4),
                        lineWidth: 2
                    )
                    .scaleEffect(rippleScale)
                    .opacity(1.0 - Double(rippleScale) / 2.0)
            }
            
            // Subtle border highlight
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .scaleEffect(breatheScale)
    }
}

// MARK: - Biometric Glass Animation

struct BiometricGlassOverlay: View {
    @State private var scanProgress: Double = 0.0
    @State private var confidenceGlow: Double = 0.0
    @State private var isScanning: Bool = false
    
    let confidence: Double
    
    var body: some View {
        ZStack {
            // Scanning sweep effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            PurpleGlass.crystal.opacity(0.6),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 3)
                .offset(y: -100 + (scanProgress * 200))
                .opacity(isScanning ? 1.0 : 0.0)
            
            // Confidence glow
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Color.green.opacity(confidenceGlow),
                    lineWidth: 2
                )
                .scaleEffect(1.0 + confidenceGlow * 0.05)
        }
        .onAppear {
            startBiometricAnimation()
        }
        .onChange(of: confidence) { newConfidence in
            updateConfidenceGlow(newConfidence)
        }
    }
    
    private func startBiometricAnimation() {
        isScanning = true
        
        withAnimation(
            .linear(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            scanProgress = 1.0
        }
    }
    
    private func updateConfidenceGlow(_ newConfidence: Double) {
        withAnimation(.easeInOut(duration: 0.3)) {
            confidenceGlow = newConfidence
        }
    }
}

// MARK: - Glass Transition Effects

struct GlassTransition: ViewModifier {
    let isVisible: Bool
    let direction: GlassRevealDirection
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(offset(for: direction, visible: isVisible))
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
    }
    
    private func offset(for direction: GlassRevealDirection, visible: Bool) -> CGSize {
        if visible { return .zero }
        
        switch direction {
        case .topToBottom: return CGSize(width: 0, height: -50)
        case .bottomToTop: return CGSize(width: 0, height: 50)
        case .leftToRight: return CGSize(width: -50, height: 0)
        case .rightToLeft: return CGSize(width: 50, height: 0)
        case .centerOut, .edgesIn: return .zero
        }
    }
}

// MARK: - View Extensions for Animation

extension View {
    func animatedGlass(
        mode: Draft.Mode,
        animation: GlassAnimation? = nil
    ) -> some View {
        AnimatedGlassCard(mode: mode) {
            self
        }
    }
    
    func glassTransition(
        isVisible: Bool,
        direction: GlassRevealDirection = .centerOut
    ) -> some View {
        modifier(GlassTransition(isVisible: isVisible, direction: direction))
    }
    
    func biometricGlass(confidence: Double = 0.0) -> some View {
        overlay {
            BiometricGlassOverlay(confidence: confidence)
        }
    }
}