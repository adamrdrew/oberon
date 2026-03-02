import SwiftUI

struct SuggestedRepliesView: View {
    let replies: [SuggestedReply]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(replies) { reply in
                    Button {
                        onTap(reply.text)
                    } label: {
                        Text(reply.text)
                            .font(.subheadline)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 4)
    }
}
