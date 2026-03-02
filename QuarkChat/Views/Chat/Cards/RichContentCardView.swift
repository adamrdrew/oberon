import SwiftUI

struct RichContentCardView: View {
    let content: RichContent

    var body: some View {
        switch content {
        case .weather(let data):
            WeatherCardView(data: data)
        case .contact(let data):
            ContactCardView(data: data)
        case .event(let data):
            EventCardView(data: data)
        case .reminder(let data):
            ReminderCardView(data: data)
        case .timer(let data):
            TimerCardView(data: data)
        case .music(let data):
            MusicCardView(data: data)
        case .linkPreview(let data):
            LinkPreviewCardView(data: data)
        case .list(let data):
            ListCardView(data: data)
        case .translation(let data):
            TranslationCardView(data: data)
        case .unitConversion(let data):
            UnitConversionCardView(data: data)
        }
    }
}
