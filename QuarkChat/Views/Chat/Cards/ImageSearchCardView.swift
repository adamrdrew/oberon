import SwiftUI
import os

private let logger = Logger(subsystem: "com.adamdrew.oberon", category: "ImageSearchCard")

struct ImageSearchCardView: View {
    let data: ImageSearchData
    var onImageTap: ((Int) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilesAppeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(OTheme.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Images")
                        .font(OTheme.conversationTitle)

                    Text(data.query)
                        .font(OTheme.caption)
                        .foregroundStyle(OTheme.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            // 2-column image grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(data.images.enumerated()), id: \.element.id) { index, image in
                    RemoteImageView(url: image.thumbnail)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                        .clipped()
                        .clipShape(.rect(cornerRadius: OTheme.cornerRadiusSmall))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        logger.info("🖼️ Image tile tapped: index=\(index), hasCallback=\(onImageTap != nil)")
                        onImageTap?(index)
                    }
                    .opacity(tilesAppeared ? 1 : 0)
                    .scaleEffect(tilesAppeared ? 1 : 0.85)
                    .animation(
                        reduceMotion
                            ? .none
                            : .spring(duration: 0.35, bounce: 0.2).delay(Double(index) * 0.05),
                        value: tilesAppeared
                    )
                }
            }
        }
        .padding(14)
        .clipShape(.rect(cornerRadius: OTheme.cornerRadiusCard))
        .glassEffect(
            .regular.tint(OTheme.accent.opacity(0.05)),
            in: .rect(cornerRadius: OTheme.cornerRadiusCard)
        )
        .onAppear {
            if !tilesAppeared {
                tilesAppeared = true
            }
        }
    }
}
