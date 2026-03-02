import SwiftUI

struct MusicCardView: View {
    let data: MusicData

    var body: some View {
        HStack(spacing: 12) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 50, height: 50)
                .overlay {
                    if let urlString = data.artworkURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .clipShape(.rect(cornerRadius: 8))
                    } else {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(data.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let album = data.albumName {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundStyle(.pink)
        }
        .padding(14)
        .glassEffect(.regular.tint(.pink.opacity(0.15)), in: .rect(cornerRadius: 16))
    }
}
