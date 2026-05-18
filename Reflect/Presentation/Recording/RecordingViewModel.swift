import Foundation
import Observation

/// Drives `RecordingView`: orchestrates permissions, the speech transcriber,
/// elapsed timer, and finalising the recording into the repository (new
/// session, appended transcript, or per-node voice note).
@MainActor
@Observable
final class RecordingViewModel {
    enum Mode {
        case newSession
        case appendingTo(JournalEntry)
        case voiceNoteFor(SDNode)
    }

    enum Phase: Equatable {
        case awaitingPermission
        case ready
        case recording
        case processing
        case error(String)
    }

    private(set) var phase: Phase = .awaitingPermission
    private(set) var elapsedSeconds: Int = 0

    let transcriber: SpeechTranscriber
    let mode: Mode
    private let repository: any JournalRepository
    private var timerTask: Task<Void, Never>?

    init(transcriber: SpeechTranscriber, repository: any JournalRepository, mode: Mode) {
        self.transcriber = transcriber
        self.repository = repository
        self.mode = mode
    }

    var transcript: String { transcriber.transcript }
    var isRecording: Bool { transcriber.isRecording }

    func start() async {
        let outcome = await transcriber.requestPermissions()
        switch outcome {
        case .granted:
            do {
                try transcriber.startRecording()
                phase = .recording
                startTimer()
            } catch {
                phase = .error("Couldn't start the mic: \(error.localizedDescription)")
            }
        case .microphoneDenied:
            phase = .error("Microphone access is off. Enable it in Settings to record.")
        case .speechDenied:
            phase = .error("Speech recognition is off. Enable it in Settings to record.")
        }
    }

    /// Stops the recording and persists the result. Returns the entry the
    /// caller should navigate to (nil if there's nothing to navigate to, e.g.
    /// a voice-note attached to an already-on-screen node).
    func finalize() async -> JournalEntry? {
        stopTimer()
        transcriber.stopRecording()
        phase = .processing

        let final = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty else {
            phase = .error("Nothing was recorded — try again.")
            return nil
        }

        do {
            switch mode {
            case .voiceNoteFor(let node):
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let stamped = "[\(formatter.string(from: Date()))] \(final)"
                try repository.appendVoiceNote(stamped, to: node)
                return nil

            case .appendingTo(let entry):
                try repository.appendTranscript(final, to: entry)
                return entry

            case .newSession:
                let entry = try repository.createEntry(rawTranscript: final)
                print("📒 finalize() → created entry id=\(entry.id)")
                return entry
            }
        } catch {
            print("❌ finalize() save failed: \(error.localizedDescription)")
            phase = .error("Couldn't save your entry: \(error.localizedDescription)")
            return nil
        }
    }

    func cancel() {
        stopTimer()
        transcriber.stopRecording()
    }

    private func startTimer() {
        stopTimer()
        elapsedSeconds = 0
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
