import SwiftUI

struct ErrorMessageView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolEffect(.pulse)
                .foregroundStyle(OTheme.signalRed)

            Text(message)
                .font(OTheme.errorBody)
                .foregroundStyle(OTheme.secondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(OTheme.signalRed), in: .rect(cornerRadius: OTheme.cornerRadiusBubble))
        .padding(.horizontal, OTheme.contentPadding)
        .transition(.blurReplace)
    }
}
