import SwiftUI
import MarkdownUI

struct MessageBubble: View {
    let message: Message
    var userColor: Color = .blue

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Group {
                    if isUser {
                        Text(message.content)
                    } else {
                        Markdown(message.content)
                            .markdownTheme(.quarkChat)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(
                    isUser ? .regular.tint(userColor) : .regular,
                    in: .rect(cornerRadius: 18)
                )

                if !isUser && !message.citations.isEmpty {
                    CitationLinksView(citations: message.citations)
                }

                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
    }
}

extension Theme {
    static let quarkChat = Theme()
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(.blue)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .font(.system(.callout, design: .monospaced))
                    .padding(12)
            }
            .background(.quaternary, in: .rect(cornerRadius: 8))
            .markdownMargin(top: 8, bottom: 8)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 8)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.1))
        }
}
