import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    var speechService: SpeechService?
    var onVoiceSend: ((String) -> Void)?

    @FocusState private var isFocused: Bool

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $text, axis: .vertical)
                .font(QTheme.body)
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(isGenerating)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .onSubmit {
                    if !isGenerating && !isEmpty {
                        onSend()
                    }
                }

            if isGenerating {
                // Stop button
                Button {
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 22, design: .monospaced))
                        .foregroundStyle(QTheme.quarkSignalRed)
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(.trailing, 8)
            } else if let speechService, isEmpty {
                // Mic button — shows when input is empty and speech is available
                Button {
                    if speechService.isRecording {
                        let transcribed = speechService.stopRecording()
                        if !transcribed.isEmpty {
                            onVoiceSend?(transcribed)
                        }
                    } else {
                        Task { await speechService.startRecording() }
                    }
                } label: {
                    ZStack {
                        if speechService.isRecording {
                            Circle()
                                .fill(QTheme.quarkSignalRed.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .scaleEffect(1 + CGFloat(speechService.audioLevel) * 0.5)
                                .animation(.easeOut(duration: 0.1), value: speechService.audioLevel)
                        }

                        Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 22, design: .monospaced))
                            .foregroundStyle(speechService.isRecording ? QTheme.quarkSignalRed : .primary)
                            .symbolEffect(.variableColor, isActive: speechService.isRecording)
                    }
                }
                .padding(.trailing, 8)
            } else {
                // Send button
                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, design: .monospaced))
                        .foregroundStyle(QTheme.quarkAccent)
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(isEmpty)
                .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 4)
        .glassEffect(in: .rect(cornerRadius: QTheme.cornerRadiusInput))
        .padding(.horizontal, QTheme.contentPadding)
        .padding(.bottom, 8)
        .onChange(of: isGenerating) { wasGenerating, nowGenerating in
            if wasGenerating && !nowGenerating {
                isFocused = true
            }
        }
        // Show live transcription below
        .overlay(alignment: .top) {
            if let speechService, speechService.isRecording, !speechService.transcribedText.isEmpty {
                Text(speechService.transcribedText)
                    .font(QTheme.timestamp)
                    .foregroundStyle(QTheme.quarkSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .glassEffect(in: .rect(cornerRadius: QTheme.cornerRadiusSmall))
                    .offset(y: -36)
                    .transition(.opacity)
            }
        }
    }
}
