import SwiftUI
import MarkdownUI

struct StreamingMessageView: View {
    let text: String
    @State private var showCursor = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Markdown(text)
                        .markdownTheme(.quarkChat)
                        .animation(.none, value: text)

                    Text(" |")
                        .fontWeight(.light)
                        .opacity(showCursor ? 1 : 0)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                            value: showCursor
                        )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(in: .rect(cornerRadius: 18))
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 12)
        .onAppear { showCursor = false }
    }
}
