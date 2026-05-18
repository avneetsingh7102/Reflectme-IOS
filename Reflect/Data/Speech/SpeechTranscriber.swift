import Foundation
import AVFoundation
import Speech
import Observation

/// Thin wrapper around `SFSpeechRecognizer` + `AVAudioEngine` exposing an
/// `@Observable` view-model-friendly surface.
///
/// On-device recognition only — no audio is uploaded. The transcript field
/// updates in real time as Apple's recognizer yields partial results.
@MainActor
@Observable
final class SpeechTranscriber: NSObject, SFSpeechRecognizerDelegate {

    enum AuthorizationOutcome {
        case granted
        case microphoneDenied
        case speechDenied
    }

    private(set) var transcript: String = ""
    private(set) var isRecording: Bool = false
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        recognizer?.delegate = self
    }

    func requestPermissions() async -> AuthorizationOutcome {
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard micGranted else { return .microphoneDenied }

        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        return speechGranted ? .granted : .speechDenied
    }

    func startRecording() throws {
        guard let recognizer else { return }
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.teardownEngine() }
                }
                if error != nil { self.teardownEngine() }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        transcript = ""
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
    }

    private func teardownEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}
