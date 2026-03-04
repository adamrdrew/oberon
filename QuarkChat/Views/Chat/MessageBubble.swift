import SwiftUI
import MarkdownUI

struct MessageBubble: View {
    let message: Message
    var userColor: Color = OTheme.navy
    var onActionExecute: ((RichAction) -> Void)?
    var onImageViewerPresent: (([ViewableImage], Int) -> Void)?
    var onSpeakToggle: ((Message) -> Void)?
    var onCopy: ((Message) -> Void)?
    var isSpeaking: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var isUser: Bool { message.role == "user" }

    /// Only animate user messages created within the last 2 seconds.
    /// Assistant messages already have their streaming entrance — animating them
    /// when the StreamingMessageView is swapped for the final bubble looks buggy.
    private var shouldAnimate: Bool {
        isUser && !reduceMotion && message.createdAt.timeIntervalSinceNow > -2
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 20) {
                if !isUser && !message.pipelineSteps.isEmpty {
                    PipelineStatusView(steps: message.pipelineSteps, isCompact: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Group {
                    if isUser {
                        Text(message.content)
                            .font(OTheme.body)
                    } else {
                        Markdown(message.content)
                            .markdownTheme(.oberon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(
                    isUser ? .regular.tint(userColor) : .regular,
                    in: .rect(cornerRadius: OTheme.cornerRadiusBubble)
                )

                // Rich content cards
                if !isUser && !message.richContent.isEmpty {
                    VStack(spacing: 30) {
                        ForEach(message.richContent) { content in
                            RichContentCardView(content: content, onImageTap: onImageViewerPresent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !isUser && !message.citations.isEmpty {
                    CitationLinksView(citations: message.citations)
                }

                if !isUser && !message.actions.isEmpty {
                    ActionButtonsView(actions: message.actions) { action in
                        onActionExecute?(action)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Utility row: TTS + Copy for assistant messages
                if !isUser && message.isComplete {
                    HStack(spacing: 12) {
                        Button {
                            onSpeakToggle?(message)
                        } label: {
                            Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(OTheme.caption)
                                .symbolEffect(.variableColor, isActive: isSpeaking)
                        }
                        .buttonStyle(.glass)

                        Button {
                            onCopy?(message)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(OTheme.caption)
                        }
                        .buttonStyle(.glass)
                    }
                }

                Text(message.createdAt, style: .time)
                    .font(OTheme.timestamp)
                    .foregroundStyle(OTheme.tertiary)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: isUser ? nil : .infinity, alignment: .leading)
        }
        .padding(.horizontal, OTheme.contentPadding)
        .opacity(shouldAnimate ? (hasAppeared ? 1 : 0) : 1)
        .offset(x: shouldAnimate ? (hasAppeared ? 0 : (isUser ? 30 : -30)) : 0)
        .animation(
            shouldAnimate ? .spring(duration: 0.4, bounce: 0.25) : .none,
            value: hasAppeared
        )
        .onAppear {
            if shouldAnimate && !hasAppeared {
                hasAppeared = true
            }
        }
    }
}

