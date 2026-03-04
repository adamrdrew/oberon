import SwiftUI
import os

private let logger = Logger(subsystem: "com.adamdrew.oberon", category: "RemoteImage")

/// Image loader that sends proper HTTP headers.
/// AsyncImage sends bare requests that CDNs (Bing, etc.) can reject.
struct RemoteImageView: View {
    let url: String
    var contentMode: ContentMode = .fill

    @State private var phase: LoadPhase = .loading

    private enum LoadPhase {
        case loading
        case success(Image)
        case failure
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                Rectangle()
                    .fill(OTheme.surface.opacity(0.15))
                    .overlay { ProgressView() }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                if contentMode == .fill {
                    // Card thumbnail failure
                    Rectangle()
                        .fill(OTheme.surface.opacity(0.3))
                        .overlay {
                            Image(systemName: "photo")
                                .font(OTheme.caption)
                                .foregroundStyle(OTheme.tertiary)
                        }
                } else {
                    // Viewer failure
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Failed to load")
                            .font(OTheme.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        phase = .loading

        guard let imageURL = URL(string: url) else {
            logger.warning("Invalid image URL: \(url)")
            phase = .failure
            return
        }

        var request = URLRequest(url: imageURL)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                logger.warning("Image HTTP \(httpResponse.statusCode) for: \(url)")
                phase = .failure
                return
            }

            #if os(macOS)
            if let nsImage = NSImage(data: data) {
                phase = .success(Image(nsImage: nsImage))
            } else {
                logger.warning("Failed to decode image data for: \(url)")
                phase = .failure
            }
            #else
            if let uiImage = UIImage(data: data) {
                phase = .success(Image(uiImage: uiImage))
            } else {
                logger.warning("Failed to decode image data for: \(url)")
                phase = .failure
            }
            #endif
        } catch {
            logger.warning("Image load error for \(url): \(error.localizedDescription)")
            phase = .failure
        }
    }
}
