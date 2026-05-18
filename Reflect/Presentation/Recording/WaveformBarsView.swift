import SwiftUI

/// Decorative waveform bars during recording. The amplitude is simulated —
/// we don't have a meter on the audio engine yet, but the visual rhythm
/// confirms the mic is live.
struct WaveformBarsView: View {
    let isActive: Bool
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.1, count: 24)
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(amplitudes.enumerated()), id: \.offset) { _, amp in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                ReflectTheme.accent.opacity(0.3 + amp * 0.6),
                                ReflectTheme.accentLight.opacity(0.2 + amp * 0.4)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: isActive ? max(6, amp * 42) : 6)
                    .animation(.easeOut(duration: 0.08), value: amp)
            }
        }
        .frame(height: 50)
        .onChange(of: isActive) { _, active in
            if active { startSimulation() } else { stopSimulation() }
        }
        .onAppear { if isActive { startSimulation() } }
        .onDisappear { stopSimulation() }
    }

    private func startSimulation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                guard self.isActive else { return }
                self.amplitudes = self.amplitudes.map { _ in CGFloat.random(in: 0.15...1.0) }
            }
        }
    }

    private func stopSimulation() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            amplitudes = Array(repeating: 0.08, count: 24)
        }
    }
}
