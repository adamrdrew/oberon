import SwiftUI

struct RichContentCardView: View {
    let content: RichContent

    var body: some View {
        switch content {
        case .weather(let data):
            WeatherCardView(data: data)
        }
    }
}
