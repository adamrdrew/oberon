import SwiftUI

struct SuggestedRepliesView: View {
    let replies: [SuggestedReply]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(replies.indices, id: \.self) { index in
                    SuggestedReplyButton(
                        reply: replies[index],
                        delay: Double(index) * 0.05,
                        onTap: onTap
                    )
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 4)
    }
}

private struct SuggestedReplyButton: View {
    let reply: SuggestedReply
    let delay: Double
    let onTap: (String) -> Void

    @State private var appeared = false

    var body: some View {
        Button {
            onTap(reply.text)
        } label: {
            Text(reply.text)
                .font(.subheadline)
        }
        .buttonStyle(.glass)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.spring(duration: 0.35, bounce: 0.2).delay(delay), value: appeared)
        .onAppear {
            appeared = true
        }
    }
}
