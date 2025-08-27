//
//  PurpleGlassSystem.swift
//  Cryptic
//
//  Advanced glassmorphism design system with contextual transparency and Metal-enhanced effects.
//

import SwiftUI
import simd

// MARK: - Purple Glass Color System

struct PurpleGlass {
    // Primary brand spectrum
    static let midnight = Color(red: 0.15, green: 0.10, blue: 0.25)     // #261A40
    static let royal = Color(red: 0.35, green: 0.20, blue: 0.60)        // #5933CC  
    static let electric = Color(red: 0.60, green: 0.40, blue: 0.85)     // #9966DD
    static let crystal = Color(red: 0.80, green: 0.70, blue: 0.95)      // #CCB3F2
    static let whisper = Color(red: 0.95, green: 0.92, blue: 0.98)      // #F2EBFA
    
    // Glass opacity system
    static let deepGlass: Double = 0.15      // Maximum privacy/security
    static let mediumGlass: Double = 0.25    // Standard content
    static let lightGlass: Double = 0.35     // Light content
    static let crystalGlass: Double = 0.45   // Interactive elements
    
    // Contextual mappings
    static func opacity(for mode: Draft.Mode) -> Double {
        switch mode {
        case .emoji: return lightGlass        // Playful, transparent
        case .qr: return mediumGlass         // Balanced readability
        case .imageStego: return deepGlass   // Maximum secrecy
        case .audioChirp: return crystalGlass // Dynamic, shimmering
        }
    }
    
    static func color(for mode: Draft.Mode) -> Color {
        switch mode {
        case .emoji: return electric
        case .qr: return royal
        case .imageStego: return midnight
        case .audioChirp: return crystal
        }
    }
}

// MARK: - Glass Material Effects

struct GlassMaterial: ViewModifier {
    let opacity: Double
    let blur: CGFloat
    let tint: Color
    let brightness: Double
    
    init(
        opacity: Double = PurpleGlass.mediumGlass,
        blur: CGFloat = 20,
        tint: Color = PurpleGlass.royal,
        brightness: Double = 0.1
    ) {
        self.opacity = opacity
        self.blur = blur
        self.tint = tint
        self.brightness = brightness
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                GlassBackground(
                    opacity: opacity,
                    blur: blur,
                    tint: tint,
                    brightness: brightness
                )
            }
    }
}

struct GlassBackground: View {
    let opacity: Double
    let blur: CGFloat  
    let tint: Color
    let brightness: Double
    
    var body: some View {
        ZStack {
            // Base glass layer
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(opacity)
            
            // Purple tint layer
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.3))
                .blendMode(.overlay)
            
            // Brightness adjustment
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(brightness))
                .blendMode(.softLight)
            
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
        .blur(radius: blur * 0.1) // Subtle additional blur
    }
}

// MARK: - Interactive Glass Components

struct GlassCard<Content: View>: View {
    let mode: Draft.Mode
    let content: () -> Content
    
    @State private var isPressed = false
    @State private var hoverLocation: CGPoint = .zero
    
    init(mode: Draft.Mode, @ViewBuilder content: @escaping () -> Content) {
        self.mode = mode
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(20)
            .modifier(
                GlassMaterial(
                    opacity: isPressed ? PurpleGlass.crystalGlass : PurpleGlass.opacity(for: mode),
                    blur: 25,
                    tint: PurpleGlass.color(for: mode),
                    brightness: isPressed ? 0.2 : 0.1
                )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPressed = false
                    }
                }
            }
    }
}

struct GlassButton: View {
    let title: String
    let mode: Draft.Mode
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withHapticFeedback(.light) {
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: iconName(for: mode))
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .modifier(
                GlassMaterial(
                    opacity: isPressed ? 0.6 : PurpleGlass.crystalGlass,
                    blur: 15,
                    tint: PurpleGlass.color(for: mode),
                    brightness: isPressed ? 0.25 : 0.15
                )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0) { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        } perform: {}
    }
    
    private func iconName(for mode: Draft.Mode) -> String {
        switch mode {
        case .emoji: return "face.smiling"
        case .qr: return "qrcode"
        case .imageStego: return "photo"
        case .audioChirp: return "waveform"
        }
    }
}

// MARK: - Animated Glass Background

struct CosmicGlassBackground: View {
    @State private var animationPhase: Double = 0
    @State private var particleOffsets: [CGPoint] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep cosmic gradient
                LinearGradient(
                    colors: [
                        PurpleGlass.midnight,
                        Color.black,
                        PurpleGlass.midnight.opacity(0.7),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Animated gradient overlay
                RadialGradient(
                    colors: [
                        PurpleGlass.royal.opacity(0.3),
                        Color.clear,
                        PurpleGlass.electric.opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 400
                )
                .rotationEffect(.degrees(animationPhase * 30))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: animationPhase)
                
                // Floating glass particles
                ForEach(0..<15, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    PurpleGlass.crystal.opacity(0.6),
                                    PurpleGlass.whisper.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .blur(radius: 10)
                        .offset(
                            x: particleOffsets.indices.contains(index) ? particleOffsets[index].x : 0,
                            y: particleOffsets.indices.contains(index) ? particleOffsets[index].y : 0
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: particleOffsets.indices.contains(index) ? particleOffsets[index] : .zero
                        )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Initialize particle positions
            particleOffsets = (0..<15).map { _ in
                CGPoint(
                    x: Double.random(in: -200...200),
                    y: Double.random(in: -300...300)
                )
            }
            
            // Start main animation
            animationPhase = 1
            
            // Animate particles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    particleOffsets = particleOffsets.map { _ in
                        CGPoint(
                            x: Double.random(in: -250...250),
                            y: Double.random(in: -350...350)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Contextual Glass Modifiers

struct ContextualGlass: ViewModifier {
    let securityLevel: SecurityLevel
    let isProcessing: Bool
    let progress: Double
    
    var computedOpacity: Double {
        let baseOpacity: Double
        switch securityLevel {
        case .casual: baseOpacity = PurpleGlass.lightGlass
        case .moderate: baseOpacity = PurpleGlass.mediumGlass  
        case .sensitive: baseOpacity = PurpleGlass.deepGlass
        case .classified: baseOpacity = 0.08
        }
        
        // Increase opacity during processing for focus
        let processingBonus = isProcessing ? 0.1 : 0.0
        
        // Decrease opacity as progress increases (revealing content)
        let progressFactor = progress * 0.15
        
        return max(0.05, baseOpacity + processingBonus - progressFactor)
    }
    
    var computedTint: Color {
        switch securityLevel {
        case .casual: return PurpleGlass.electric
        case .moderate: return PurpleGlass.royal
        case .sensitive: return PurpleGlass.midnight
        case .classified: return Color.black
        }
    }
    
    func body(content: Content) -> some View {
        content
            .modifier(
                GlassMaterial(
                    opacity: computedOpacity,
                    blur: isProcessing ? 30 : 20,
                    tint: computedTint,
                    brightness: isProcessing ? 0.05 : 0.1
                )
            )
            .animation(.easeInOut(duration: 0.3), value: isProcessing)
            .animation(.easeInOut(duration: 0.5), value: progress)
    }
}

// MARK: - Haptic Feedback Integration

extension View {
    func withHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle, _ action: @escaping () -> Void) -> some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
            action()
        }) {
            self
        }
    }
}

// MARK: - View Extensions

extension View {
    func purpleGlass(
        mode: Draft.Mode,
        opacity: Double? = nil,
        blur: CGFloat = 20
    ) -> some View {
        self.modifier(
            GlassMaterial(
                opacity: opacity ?? PurpleGlass.opacity(for: mode),
                blur: blur,
                tint: PurpleGlass.color(for: mode)
            )
        )
    }
    
    func contextualGlass(
        securityLevel: SecurityLevel,
        isProcessing: Bool = false,
        progress: Double = 0.0
    ) -> some View {
        self.modifier(
            ContextualGlass(
                securityLevel: securityLevel,
                isProcessing: isProcessing,
                progress: progress
            )
        )
    }
}