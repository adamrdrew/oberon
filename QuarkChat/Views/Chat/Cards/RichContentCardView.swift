import SwiftUI
import os

private let logger = Logger(subsystem: "com.adamdrew.oberon", category: "RichContentCard")

struct RichContentCardView: View {
    let content: RichContent
    var onImageTap: (([ViewableImage], Int) -> Void)?

    var body: some View {
        switch content {
        case .weather(let data):
            WeatherCardView(data: data)
        case .wikipedia(let data):
            WikipediaCardView(data: data, onImageTap: { index in
                logger.info("🖼️ RichContentCard: wiki image tap index=\(index), hasCallback=\(onImageTap != nil)")
                let viewables = data.images.map { ViewableImage(from: $0) }
                onImageTap?(viewables, index)
            })
        case .images(let data):
            ImageSearchCardView(data: data, onImageTap: { index in
                logger.info("🖼️ RichContentCard: image search tap index=\(index), hasCallback=\(onImageTap != nil)")
                let viewables = data.images.map { ViewableImage(from: $0) }
                onImageTap?(viewables, index)
            })
        case .videos(let data):
            VideoSearchCardView(data: data)
        case .linkPreview(let data):
            LinkPreviewCardView(data: data)
        }
    }
}
