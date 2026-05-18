import SwiftUI
@preconcurrency import SwiftData

/// Full-screen recording surface: pulsing orb, live transcript, waveform,
/// and a stop CTA. Drives everything through `RecordingViewModel`.
struct RecordingView: View {
    let mode: RecordingViewModel.Mode
    let onFinished: (JournalEntry?) -> Void
    let onClosed: () -> Void

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: RecordingViewModel?
    @State private var transcriber = SpeechTranscriber()
    @State private var pulse = false
    @State private var breathe: CGFloat = 1.0
    @State private var ringRotation: Double = 0

    var body: some View {
        ZStack {
            ReflectTheme.darkCanvas.ignoresSafeArea()
            RadialGradient(
                colors: [ReflectTheme.accent.opacity(pulse ? 0.08 : 0.03), .clear],
                center: .center, startRadius: 40, endRadius: 300
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: 0) {
                topBar.padding(.top, ReflectTheme.spacingSM)
                Spacer()
                transcriptArea.padding(.bottom, ReflectTheme.spacingXL)
                statusIndicator.padding(.bottom, ReflectTheme.spacingSM)
                WaveformBarsView(isActive: viewModel?.isRecording == true)
                    .padding(.horizontal, ReflectTheme.spacingXXL)
                    .padding(.bottom, ReflectTheme.spacingMD)
                recordingOrb
                    .scaleEffect(pulse ? 1.2 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pulse)
                    .padding(.bottom, ReflectTheme.spacingXXL)
                Spacer()
                stopButton.padding(.bottom, ReflectTheme.spacingXXL)
            }
        }
        .task { await initialize() }
        .onAppear {
            pulse = true
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { ringRotation = 360 }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { breathe = 1.15 }
        }
        .onDisappear { viewModel?.cancel() }
    }

    private func initialize() async {
        if viewModel == nil {
            let repo = services.makeRepository(context: modelContext)
            viewModel = RecordingViewModel(transcriber: transcriber, repository: repo, mode: mode)
        }
        await viewModel?.start()
    }

    private var topBar: some View {
        HStack {
            Button {
                viewModel?.cancel()
                onClosed()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 8, height: 8)
                    .opacity(pulse ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                Text(elapsedString)
                    .font(ReflectTheme.mono(15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(0.06)))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, ReflectTheme.spacingLG)
    }

    private var recordingOrb: some View {
        ZStack {
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                .foregroundStyle(ReflectTheme.accent.opacity(0.2))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(ringRotation))
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(ReflectTheme.accent.opacity(0.15 - Double(i) * 0.04), lineWidth: 1.5)
                    .frame(width: CGFloat(80 + i * 30), height: CGFloat(80 + i * 30))
                    .scaleEffect(breathe - CGFloat(i) * 0.03)
            }
            Circle()
                .fill(RadialGradient(
                    colors: [ReflectTheme.accent.opacity(0.3), ReflectTheme.accent.opacity(0.05), .clear],
                    center: .center, startRadius: 10, endRadius: 50))
                .frame(width: 100, height: 100).scaleEffect(breathe)
            Circle()
                .fill(ReflectTheme.accentGradient).frame(width: 60, height: 60)
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                .shadow(color: ReflectTheme.accent.opacity(0.4), radius: 16, y: 0)
            Image(systemName: phase == .processing ? "hourglass" : "mic.fill")
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
        }
    }

    private var statusIndicator: some View {
        Text(statusText)
            .font(ReflectTheme.rounded(14, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    private var transcriptArea: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if transcriber.transcript.isEmpty {
                    Text(phase == .processing ? "Transcribing…" : "Listening…")
                        .font(ReflectTheme.rounded(16))
                        .foregroundStyle(.white.opacity(0.25))
                        .italic()
                } else {
                    Text(transcriber.transcript)
                        .font(ReflectTheme.serif(17))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ReflectTheme.spacingXL)
        }
        .frame(maxHeight: 180)
        .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom))
    }

    private var stopButton: some View {
        Button {
            Task {
                let result = await viewModel?.finalize()
                onFinished(result ?? nil)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "stop.fill").font(.system(size: 12))
                Text(phase == .processing ? "Saving…" : "Stop & Reflect")
                    .font(ReflectTheme.rounded(17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: ReflectTheme.cornerRadiusXL)
                .fill(phase == .processing
                      ? AnyShapeStyle(Color.gray.opacity(0.3))
                      : AnyShapeStyle(ReflectTheme.accentGradient)))
            .overlay(RoundedRectangle(cornerRadius: ReflectTheme.cornerRadiusXL)
                .stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, ReflectTheme.spacingXL)
        }
        .disabled(phase == .processing || (!transcriber.isRecording && phase != .recording))
    }

    private var elapsedString: String {
        let s = viewModel?.elapsedSeconds ?? 0
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var phase: RecordingViewModel.Phase {
        viewModel?.phase ?? .awaitingPermission
    }

    private var statusText: String {
        switch phase {
        case .awaitingPermission: return "Requesting permission…"
        case .ready:              return "Speak freely"
        case .recording:          return "Recording • tap Stop & Reflect when done"
        case .processing:         return "Processing your thoughts…"
        case .error(let msg):     return msg
        }
    }
}
