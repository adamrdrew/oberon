import SwiftUI

struct ErrorMessageView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolEffect(.pulse)
                .foregroundStyle(QTheme.quarkSignalRed)

            Text(message)
                .font(QTheme.errorBody)
                .foregroundStyle(QTheme.quarkSecondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(QTheme.quarkSignalRed), in: .rect(cornerRadius: QTheme.cornerRadiusBubble))
        .padding(.horizontal, QTheme.contentPadding)
        .transition(.blurReplace)
    }
}
