import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    var speechService: SpeechService?
    var onVoiceSend: ((String) -> Void)?
    var isVoiceMode: Bool = false
    var voiceModeStatus: VoiceModeStatus = .listening
    var onToggleVoiceMode: (() -> Void)?

    @FocusState private var isFocused: Bool

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if isVoiceMode {
            voiceModeBar
        } else {
            normalInputBar
        }
    }

    // MARK: - Voice Mode Bar

    @ViewBuilder
    private var voiceModeBar: some View {
        HStack(spacing: 12) {
            // Pulsing audio level circle
            ZStack {
                if let speechService, voiceModeStatus == .listening {
                    Circle()
                        .fill(OTheme.accent.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .scaleEffect(1 + CGFloat(speechService.audioLevel) * 0.5)
                        .animation(.easeOut(duration: 0.1), value: speechService.audioLevel)
                }

                Circle()
                    .fill(voiceModeIndicatorColor)
                    .frame(width: 12, height: 12)
                    .scaleEffect(voiceModeStatus == .listening ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: voiceModeStatus)
            }
            .frame(width: 36, height: 36)

            // Status text
            Text(voiceModeStatusText)
                .font(OTheme.body)
                .foregroundStyle(OTheme.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // End button
            Button {
                onToggleVoiceMode?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24, design: .monospaced))
                    .foregroundStyle(OTheme.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: OTheme.cornerRadiusInput))
        .padding(.horizontal, OTheme.contentPadding)
        .padding(.bottom, 8)
    }

    private var voiceModeIndicatorColor: Color {
        switch voiceModeStatus {
        case .listening: OTheme.accent
        case .thinking: .orange
        case .speaking: .green
        }
    }

    private var voiceModeStatusText: String {
        switch voiceModeStatus {
        case .listening:
            if let speechService, !speechService.transcribedText.isEmpty {
                return speechService.transcribedText
            }
            return "Listening..."
        case .thinking:
            return "Thinking..."
        case .speaking:
            return "Speaking..."
        }
    }

    // MARK: - Normal Input Bar

    @ViewBuilder
    private var normalInputBar: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $text, axis: .vertical)
                .font(OTheme.body)
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(isGenerating)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .onSubmit {
                    if !isGenerating && !isEmpty {
                        Haptics.tap()
                        onSend()
                        #if os(iOS)
                        isFocused = false
                        #endif
                    }
                }

            if isGenerating {
                // Stop button
                Button {
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 22, design: .monospaced))
                        .foregroundStyle(OTheme.signalRed)
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(.trailing, 8)
            } else if let speechService, isEmpty {
                // Mic button — enters voice mode
                Button {
                    onToggleVoiceMode?()
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 22, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(.trailing, 8)
            } else {
                // Send button
                Button {
                    Haptics.tap()
                    onSend()
                    #if os(iOS)
                    isFocused = false
                    #endif
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, design: .monospaced))
                        .foregroundStyle(OTheme.accent)
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(isEmpty)
                .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 4)
        .glassEffect(in: .rect(cornerRadius: OTheme.cornerRadiusInput))
        .padding(.horizontal, OTheme.contentPadding)
        .padding(.bottom, 8)
        #if os(macOS)
        .onChange(of: isGenerating) { wasGenerating, nowGenerating in
            if wasGenerating && !nowGenerating {
                isFocused = true
            }
        }
        #endif
    }
}
