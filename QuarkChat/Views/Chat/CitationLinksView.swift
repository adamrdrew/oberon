import SwiftUI

struct CitationLinksView: View {
    let citations: [Citation]

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(citations.indices, id: \.self) { index in
                let citation = citations[index]
                Button {
                    if let url = URL(string: citation.url) {
                        openURL(url)
                    }
                } label: {
                    Label {
                        Text(displayHost(citation.url))
                            .font(QTheme.citation)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "link")
                            .font(QTheme.citation)
                    }
                    .foregroundStyle(QTheme.quarkTeal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 2)
    }

    private func displayHost(_ urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host() else {
            return urlString
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
