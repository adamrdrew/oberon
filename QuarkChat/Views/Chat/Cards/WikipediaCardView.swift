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
                    .foregroundStyle(OTheme.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(OTheme.conversationTitle)

                    if let description = data.description {
                        Text(description)
                            .font(OTheme.caption)
                            .foregroundStyle(OTheme.secondary)
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
                                        .fill(OTheme.surface.opacity(0.3))
                                        .overlay {
                                            Image(systemName: "photo")
                                                .font(OTheme.caption)
                                                .foregroundStyle(OTheme.tertiary)
                                        }
                                case .empty:
                                    Rectangle()
                                        .fill(OTheme.surface.opacity(0.15))
                                        .overlay { ProgressView() }
                                @unknown default:
                                    Color.clear
                                }
                            }
                            .frame(height: 80)
                            .frame(maxWidth: .infinity)
                            .clipShape(.rect(cornerRadius: OTheme.cornerRadiusSmall))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Excerpt
            Text(data.extract)
                .font(OTheme.bodySmall)
                .foregroundStyle(OTheme.primary)
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
                        .font(OTheme.label)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(OTheme.navy.opacity(0.1)), in: .rect(cornerRadius: OTheme.cornerRadiusCard))
    }
}
