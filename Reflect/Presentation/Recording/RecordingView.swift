import SwiftUI
@preconcurrency import SwiftData

/// Voice-capture surface. Two states only — listening and processing.
///
/// Per design: dark blue canvas (no neutral dark), live transcript fading at
/// top + bottom via a mask, a centred glowing `PulsingRing` lower-third, and
/// a small mustard cue line ("LISTENING · TAP TO FINISH"). No timer, no
/// waveform, no mic icon — the ring is the only affordance. A tiny X in the
/// top-left lets the user cancel.
struct RecordingView: View {
    let mode: RecordingViewModel.Mode
    let onFinished: (JournalEntry?) -> Void
    let onClosed: () -> Void

    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: RecordingViewModel?
    @State private var transcriber = SpeechTranscriber()

    var body: some View {
        ZStack {
            ReflectTheme.blue700.ignoresSafeArea()

            // Subtle radial glow at the centre echoing the ring
            RadialGradient(
                colors: [ReflectTheme.primary.opacity(0.08), .clear],
                center: .center, startRadius: 40, endRadius: 320
            )
            .ignoresSafeArea()

            transcriptLayer
            ringBlock
            cancelButton
        }
        .task { await initialize() }
        .onDisappear { viewModel?.cancel() }
    }

    // MARK: - Layers

    private var cancelButton: some View {
        VStack {
            HStack {
                Button {
                    viewModel?.cancel()
                    onClosed()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.70))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        )
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    /// Live transcript area — sits in the upper third, fades top/bottom.
    @ViewBuilder
    private var transcriptLayer: some View {
        let isProcessing = (viewModel?.phase ?? .awaitingPermission) == .processing
        VStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 13) {
                    if isProcessing {
                        Text("“\(transcriber.transcript)”")
                            .font(ReflectTheme.serif(18))
                            .italic()
                            .foregroundStyle(Color(white: 0.95).opacity(0.75))
                            .multilineTextAlignment(.center)
                    } else {
                        Text(displayedTranscript)
                            .font(ReflectTheme.serif(18))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
            }
            .frame(maxHeight: 260)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .black, location: 0.30),
                        .init(color: .black, location: 0.78),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .padding(.top, 80)
            Spacer()
        }
    }

    private var ringBlock: some View {
        VStack {
            Spacer()
            VStack(spacing: 22) {
                if (viewModel?.phase ?? .awaitingPermission) == .processing {
                    PulsingRing(mode: .processing, size: 96, onLightBackground: false)
                } else {
                    PulsingRing(mode: .listening, size: 85, onLightBackground: false) {
                        finish()
                    }
                }
                Text(cueText)
                    .font(ReflectTheme.rounded(11.5, weight: .bold))
                    .foregroundStyle(ReflectTheme.mustard300.opacity(0.85))
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 88)
        }
    }

    // MARK: - Logic

    private func initialize() async {
        if viewModel == nil {
            let repo = services.makeRepository(context: modelContext)
            viewModel = RecordingViewModel(transcriber: transcriber, repository: repo, mode: mode)
        }
        await viewModel?.start()
    }

    private func finish() {
        Task {
            let result = await viewModel?.finalize()
            onFinished(result ?? nil)
        }
    }

    private var displayedTranscript: String {
        if transcriber.transcript.isEmpty {
            return "Listening…"
        }
        return transcriber.transcript
    }

    private var cueText: String {
        switch viewModel?.phase ?? .awaitingPermission {
        case .awaitingPermission: return "Requesting permission…"
        case .ready:              return "Speak freely"
        case .recording:          return "Listening · tap to finish"
        case .processing:         return "Processing your thoughts…"
        case .error(let msg):     return msg
        }
    }
}
