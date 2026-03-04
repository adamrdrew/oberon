import SwiftUI

struct RichContentCardView: View {
    let content: RichContent
    var onImageTap: (([ViewableImage], Int) -> Void)?

    var body: some View {
        switch content {
        case .weather(let data):
            WeatherCardView(data: data)
        case .wikipedia(let data):
            WikipediaCardView(data: data, onImageTap: { index in
                let viewables = data.images.map { ViewableImage(from: $0) }
                onImageTap?(viewables, index)
            })
        case .images(let data):
            ImageSearchCardView(data: data, onImageTap: { index in
                let viewables = data.images.map { ViewableImage(from: $0) }
                onImageTap?(viewables, index)
            })
        }
    }
}
