import Foundation
import Observation
import Speech
import AVFoundation

@Observable
@MainActor
final class SpeechService {
    var transcribedText: String = ""
    var isRecording: Bool = false
    var audioLevel: Float = 0

    /// Called when speech recognition finalizes (silence detected). Passes transcribed text.
    var onSpeechFinalized: ((String) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)

    /// Silence detection: fires finalization when text stops changing
    private var silenceTimer: Task<Void, Never>?
    private let silenceTimeout: Duration = .milliseconds(1500)

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startRecording() async {
        guard !isRecording else { return }

        let authorized = await requestPermission()
        guard authorized else { return }

        // Configure audio session
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }
        #endif

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.silenceTimer?.cancel()
                        let text = result.bestTranscription.formattedString
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.onSpeechFinalized?(text)
                        }
                        self.stopRecordingInternal()
                        return
                    }

                    // Voice mode: reset silence timer on each partial result
                    if self.onSpeechFinalized != nil {
                        self.resetSilenceTimer()
                    }
                }
                if error != nil {
                    self.silenceTimer?.cancel()
                    self.stopRecordingInternal()
                }
            }
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)

            // Calculate audio level
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            if let data = channelData, frameLength > 0 {
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += abs(data[i])
                }
                let average = sum / Float(frameLength)
                Task { @MainActor in
                    self?.audioLevel = min(average * 10, 1.0)
                }
            }
        }

        do {
            engine.prepare()
            try engine.start()
            audioEngine = engine
            recognitionRequest = request
            isRecording = true
            transcribedText = ""
        } catch {
            stopRecordingInternal()
        }
    }

    func stopRecording() -> String {
        let text = transcribedText
        stopRecordingInternal()
        return text
    }

    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: self?.silenceTimeout ?? .milliseconds(1500))
            guard !Task.isCancelled, let self, self.isRecording else { return }
            let text = self.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                self.onSpeechFinalized?(text)
            }
            self.stopRecordingInternal()
        }
    }

    private func stopRecordingInternal() {
        silenceTimer?.cancel()
        silenceTimer = nil

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.reset() // Release audio hardware so TTS can use it

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        audioLevel = 0

        // Deactivate audio session so TTS can play
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
