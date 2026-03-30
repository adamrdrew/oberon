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
        guard !isRecording else {
            #if DEBUG
            print("[Speech] startRecording: already recording, skipping")
            #endif
            return
        }

        let authorized = await requestPermission()
        guard authorized else {
            #if DEBUG
            print("[Speech] startRecording: speech recognition not authorized")
            #endif
            return
        }

        // Microphone is a separate permission from speech recognition.
        // On iOS this is covered by AVAudioSession, but on macOS it must be explicit.
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard micAllowed else {
            #if DEBUG
            print("[Speech] startRecording: microphone permission denied")
            #endif
            return
        }
        #if DEBUG
        print("[Speech] startRecording: authorized (speech + mic)")
        #endif

        AudioSessionHelper.activatePlaybackSession()

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            #if DEBUG
            print("[Speech] startRecording: recognizer unavailable (recognizer=\(speechRecognizer != nil), available=\(speechRecognizer?.isAvailable ?? false))")
            #endif
            return
        }
        #if DEBUG
        print("[Speech] startRecording: recognizer available, locale=\(recognizer.locale)")
        #endif

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                    #if DEBUG
                    print("[Speech] partial: \"\(result.bestTranscription.formattedString)\" isFinal=\(result.isFinal)")
                    #endif

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
                if let error {
                    #if DEBUG
                    print("[Speech] recognition error: \(error)")
                    #endif
                    self.silenceTimer?.cancel()
                    self.stopRecordingInternal()
                }
            }
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        #if DEBUG
        print("[Speech] inputNode format: sampleRate=\(recordingFormat.sampleRate) channels=\(recordingFormat.channelCount)")
        #endif

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // Guard zero-size buffers (happen during engine shutdown)
            guard buffer.frameLength > 0 else { return }
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
            #if DEBUG
            print("[Speech] startRecording: engine started successfully")
            #endif
        } catch {
            #if DEBUG
            print("[Speech] startRecording: engine start failed: \(error)")
            #endif
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
        // Guard against double-stop (silence timer, isFinal, and user stop can all race)
        guard audioEngine != nil else { return }

        silenceTimer?.cancel()
        silenceTimer = nil

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.reset()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        audioLevel = 0
    }
}
