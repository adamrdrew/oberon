import SwiftUI

struct WikipediaCardView: View {
    let data: WikipediaData

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + description
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "book.pages")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(QTheme.quarkSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(QTheme.conversationTitle)

                    if let description = data.description {
                        Text(description)
                            .font(QTheme.caption)
                            .foregroundStyle(QTheme.quarkSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // Image tiles
            if !data.images.isEmpty {
                HStack(spacing: 6) {
                    ForEach(data.images) { image in
                        Button {
                            if let url = URL(string: image.filePageURL), !image.filePageURL.isEmpty {
                                openURL(url)
                            }
                        } label: {
                            AsyncImage(url: URL(string: image.imageURL)) { phase in
                                switch phase {
                                case .success(let img):
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    Rectangle()
                                        .fill(QTheme.quarkSurface.opacity(0.3))
                                        .overlay {
                                            Image(systemName: "photo")
                                                .font(QTheme.caption)
                                                .foregroundStyle(QTheme.quarkTertiary)
                                        }
                                case .empty:
                                    Rectangle()
                                        .fill(QTheme.quarkSurface.opacity(0.15))
                                        .overlay { ProgressView() }
                                @unknown default:
                                    Color.clear
                                }
                            }
                            .frame(height: 80)
                            .frame(maxWidth: .infinity)
                            .clipShape(.rect(cornerRadius: QTheme.cornerRadiusSmall))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Excerpt
            Text(data.extract)
                .font(QTheme.bodySmall)
                .foregroundStyle(QTheme.quarkPrimary)
                .lineLimit(4)

            // Read Article button
            HStack {
                Spacer()
                Button {
                    if let url = URL(string: data.articleURL) {
                        openURL(url)
                    }
                } label: {
                    Label("Read Article", systemImage: "safari")
                        .font(QTheme.label)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(QTheme.quarkNavy.opacity(0.1)), in: .rect(cornerRadius: QTheme.cornerRadiusCard))
    }
}
