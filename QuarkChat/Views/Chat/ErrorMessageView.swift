import SwiftUI

struct ErrorMessageView: View {
    let message: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolEffect(.pulse)
                    .foregroundStyle(.orange)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.tint(.orange), in: .rect(cornerRadius: 18))

            Spacer()
        }
        .padding(.horizontal, 12)
        .transition(.blurReplace)
    }
}
