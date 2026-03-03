import SwiftUI
import MarkdownUI

struct StreamingMessageView: View {
    let text: String
    @State private var showCursor = true

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Markdown(text)
                .markdownTheme(.oberon)
                .animation(.none, value: text)

            RoundedRectangle(cornerRadius: 1)
                .fill(OTheme.accent)
                .frame(width: 2, height: 16)
                .padding(.leading, 2)
                .opacity(showCursor ? 1 : 0.15)
                .animation(
                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: showCursor
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: OTheme.cornerRadiusBubble))
        .padding(.horizontal, OTheme.contentPadding)
        .onAppear { showCursor = false }
    }
}
