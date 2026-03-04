import SwiftUI

struct VideoSearchCardView: View {
    let data: VideoSearchData

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilesAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(OTheme.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Videos")
                        .font(OTheme.conversationTitle)

                    Text(data.query)
                        .font(OTheme.caption)
                        .foregroundStyle(OTheme.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            // Horizontal scroll of video tiles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(data.videos.enumerated()), id: \.element.id) { index, video in
                        videoTile(video, index: index)
                    }
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

    @ViewBuilder
    private func videoTile(_ video: VideoSearchData.VideoResult, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thumbnail with duration badge
            ZStack(alignment: .bottomTrailing) {
                RemoteImageView(url: video.thumbnailURL)
                    .frame(width: 220, height: 124)
                    .clipped()
                    .clipShape(.rect(cornerRadius: OTheme.cornerRadiusSmall))

                if !video.duration.isEmpty {
                    Text(video.duration)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75), in: .rect(cornerRadius: 3))
                        .padding(6)
                }
            }

            // Title
            Text(video.title)
                .font(OTheme.caption)
                .foregroundStyle(OTheme.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 220, alignment: .leading)

            // Uploader + publisher
            HStack(spacing: 4) {
                if !video.uploader.isEmpty {
                    Text(video.uploader)
                        .lineLimit(1)
                }
                if !video.publisher.isEmpty {
                    Text("· \(video.publisher)")
                        .lineLimit(1)
                }
            }
            .font(OTheme.timestamp)
            .foregroundStyle(OTheme.tertiary)
            .frame(width: 220, alignment: .leading)

            // View count
            if let viewCount = video.viewCount, viewCount > 0 {
                Text(formatViewCount(viewCount))
                    .font(OTheme.timestamp)
                    .foregroundStyle(OTheme.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: video.videoURL) {
                openURL(url)
            }
        }
        .opacity(tilesAppeared ? 1 : 0)
        .scaleEffect(tilesAppeared ? 1 : 0.85)
        .animation(
            reduceMotion
                ? .none
                : .spring(duration: 0.35, bounce: 0.2).delay(Double(index) * 0.07),
            value: tilesAppeared
        )
    }

    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return "\(count / 1_000_000)M views"
        } else if count >= 1_000 {
            return "\(count / 1_000)K views"
        } else {
            return "\(count) views"
        }
    }
}
