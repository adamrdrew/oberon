import SwiftUI

struct LinkPreviewCardView: View {
    let data: LinkPreviewData

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // OG Image
            if let imageURL = data.imageURL, !imageURL.isEmpty {
                RemoteImageView(url: imageURL)
                    .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 160)
                    .clipped()
                    .clipShape(.rect(cornerRadius: OTheme.cornerRadiusSmall))
            }

            // Domain + site name
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(OTheme.accent)

                Text(data.siteName ?? data.domain)
                    .font(OTheme.timestamp)
                    .foregroundStyle(OTheme.secondary)
                    .lineLimit(1)

                Spacer()
            }

            // Title
            if let title = data.title, !title.isEmpty {
                Text(title)
                    .font(OTheme.conversationTitle)
                    .foregroundStyle(OTheme.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            // Description
            if let description = data.description, !description.isEmpty {
                Text(description)
                    .font(OTheme.bodySmall)
                    .foregroundStyle(OTheme.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            // Open in Safari
            HStack {
                Spacer()
                Button {
                    if let url = URL(string: data.url) {
                        openURL(url)
                    }
                } label: {
                    Label("Open Page", systemImage: "safari")
                        .font(OTheme.label)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(14)
        .clipShape(.rect(cornerRadius: OTheme.cornerRadiusCard))
        .glassEffect(
            .regular.tint(OTheme.accent.opacity(0.08)),
            in: .rect(cornerRadius: OTheme.cornerRadiusCard)
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .animation(
            reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.15),
            value: appeared
        )
        .onAppear {
            if !appeared { appeared = true }
        }
    }
}
