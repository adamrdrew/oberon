import SwiftUI

struct StreamingMessageView: View {
    let text: String
    @State private var showCursor = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text(text)
                        .animation(.none, value: text)

                    Text(" |")
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
