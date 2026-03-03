import SwiftUI

struct WelcomeRow: View {
    var title: String
    var text: String
    var systemImage: String
    var textWidth: CGFloat = 200

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(OTheme.accent)
                .padding(.top, 2)  // optical align with headline
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OTheme.label)
                    .foregroundStyle(OTheme.primary)

                Text(text)
                    .font(OTheme.bodySmall)
                    .foregroundStyle(OTheme.secondary)
            }
            .frame(width: textWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
