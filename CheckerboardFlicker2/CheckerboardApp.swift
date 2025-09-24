// NoiseFlickerApp.swift - Complete iPad Black & White Noise Flicker App

import SwiftUI
import Combine

// MARK: - Animation Timer
class FlickerTimer: ObservableObject {
    private var timer: Timer?
    private var accumulator: TimeInterval = 0.0
    private var lastTimestamp: TimeInterval = 0.0
    
    @Published var frameCounter: Int = 0
    @Published var actualHz: Double = 0.0
    
    private var targetHz: Double = 0.0
    private var isActive: Bool = false
    private var updateCount: Int = 0
    private var fpsStartTime: TimeInterval = 0.0
    
    func start(hz: Double) {
        stop()
        
        guard hz > 0 else {
            actualHz = 0.0
            return
        }
        
        targetHz = hz
        isActive = true
        accumulator = 0.0
        updateCount = 0
        frameCounter = 0
        fpsStartTime = Date().timeIntervalSince1970
        lastTimestamp = Date().timeIntervalSince1970
        
        // Use Timer instead of CADisplayLink for cross-platform compatibility
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { _ in
            self.tick()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        actualHz = 0.0
    }
    
    private func tick() {
        let currentTime = Date().timeIntervalSince1970
        
        if lastTimestamp == 0 {
            lastTimestamp = currentTime
            return
        }
        
        let deltaTime = currentTime - lastTimestamp
        lastTimestamp = currentTime
        
        guard targetHz > 0 else { return }
        
        let interval = 1.0 / targetHz
        accumulator += deltaTime
        
        while accumulator >= interval {
            accumulator -= interval
            frameCounter += 1
            updateCount += 1
        }
        
        // Calculate actual Hz every second
        let elapsed = currentTime - fpsStartTime
        if elapsed >= 1.0 {
            actualHz = Double(updateCount) / elapsed
            updateCount = 0
            fpsStartTime = currentTime
        }
    }
}

// MARK: - Noise Canvas View
struct NoiseCanvas: View {
    let squares: Int
    let frameCounter: Int
    
    var body: some View {
        ZStack {
            // Main noise canvas
            Canvas { context, size in
                let squareSize = min(size.width, size.height) / CGFloat(squares)
                let boardSize = squareSize * CGFloat(squares)
                let offsetX = (size.width - boardSize) / 2
                let offsetY = (size.height - boardSize) / 2
                
                for row in 0..<squares {
                    for col in 0..<squares {
                        let x = offsetX + CGFloat(col) * squareSize
                        let y = offsetY + CGFloat(row) * squareSize
                        let rect = CGRect(x: x, y: y, width: squareSize, height: squareSize)
                        
                        // Pure random noise - each square is random black or white
                        let isBlack = Bool.random()
                        
                        context.fill(
                            Path(rect),
                            with: .color(isBlack ? .black : .white)
                        )
                    }
                }
            }
            
            // Independent toggle square in top-right corner
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        // Label and arrow
                        HStack(spacing: 4) {
                            Text("Toggle Square")
                                .font(.caption)
                                .foregroundColor(.red)
                                .bold()
                            
                            // Red arrow pointing down-left to the square
                            Image(systemName: "arrow.down.left")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Independent toggle square
                        Rectangle()
                            .fill(frameCounter % 2 == 0 ? Color.black : Color.white)
                            .frame(width: 80, height: 80)
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Control Panel
struct ControlPanel: View {
    @Binding var frequency: Double
    @Binding var squares: Int
    @Binding var isPlaying: Bool
    
    let actualHz: Double
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Play/Pause Button
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                
                Spacer()
                
                // Debug Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Target: \(frequency, specifier: "%.1f") Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Actual: \(actualHz, specifier: "%.1f") Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Controls Grid - Only Frequency and Squares
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                // Frequency Control
                VStack(spacing: 4) {
                    Text("Frequency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("-") {
                            frequency = max(0.0, frequency - 0.5)
                        }
                        .controlButtonStyle()
                        
                        Text("\(frequency, specifier: "%.1f") Hz")
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 80)
                        
                        Button("+") {
                            frequency = min(60.0, frequency + 0.5)
                        }
                        .controlButtonStyle()
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Frequency: \(frequency, specifier: "%.1f") Hz")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        frequency = min(60.0, frequency + 0.5)
                    case .decrement:
                        frequency = max(0.0, frequency - 0.5)
                    @unknown default:
                        break
                    }
                }
                
                // Squares Control
                VStack(spacing: 4) {
                    Text("Grid Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("-") {
                            squares = max(2, squares - 1)
                        }
                        .controlButtonStyle()
                        
                        Text("\(squares)×\(squares)")
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 80)
                        
                        Button("+") {
                            squares = min(128, squares + 1)
                        }
                        .controlButtonStyle()
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Grid size: \(squares) by \(squares)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        squares = min(128, squares + 1)
                    case .decrement:
                        squares = max(2, squares - 1)
                    @unknown default:
                        break
                    }
                }
            }
        }
        .padding()
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

// MARK: - Control Button Style
struct ControlButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3)
            .foregroundColor(.primary)
            .frame(width: 32, height: 32)
            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
            .clipShape(Circle())
    }
}

extension View {
    func controlButtonStyle() -> some View {
        modifier(ControlButtonStyle())
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    @AppStorage("noise_frequency_v2") private var frequency: Double = 30.0
    @AppStorage("noise_squares_v2") private var squares: Int = 12
    @AppStorage("noise_playing_v2") private var isPlaying: Bool = false
    
    @StateObject private var flickerTimer = FlickerTimer()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen random noise
                NoiseCanvas(
                    squares: squares,
                    frameCounter: flickerTimer.frameCounter
                )
                .ignoresSafeArea()
                
                // Control panel at bottom
                VStack {
                    Spacer()
                    
                    ControlPanel(
                        frequency: $frequency,
                        squares: $squares,
                        isPlaying: $isPlaying,
                        actualHz: flickerTimer.actualHz
                    )
                    .padding(.horizontal)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 0)
                }
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                flickerTimer.start(hz: frequency)
            } else {
                flickerTimer.stop()
            }
        }
        .onChange(of: frequency) { _, newFreq in
            if isPlaying {
                flickerTimer.start(hz: newFreq)
            }
        }
        .onAppear {
            if isPlaying {
                flickerTimer.start(hz: frequency)
            }
        }
        .onDisappear {
            flickerTimer.stop()
        }
    }
}

// MARK: - App Entry Point
@main
struct NoiseFlickerApp: App {
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .preferredColorScheme(.dark)
        }
    }
}
