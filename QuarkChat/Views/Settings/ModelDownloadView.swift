import SwiftUI

struct ModelDownloadView: View {
    @State private var mlxManager = MLXModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(OTheme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Qwen3-4B")
                        .font(OTheme.body)
                        .foregroundStyle(OTheme.primary)
                    Text(statusText)
                        .font(OTheme.pipelineLabel)
                        .foregroundStyle(OTheme.tertiary)
                }

                Spacer()

                actionButton
            }

            if case .downloading(let progress) = mlxManager.state {
                ProgressView(value: progress)
                    .tint(OTheme.accent)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: OTheme.cornerRadiusCard))
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch mlxManager.state {
        case .notDownloaded: "arrow.down.circle"
        case .downloading: "arrow.down.circle"
        case .downloaded: "checkmark.circle"
        case .loading: "gearshape.circle"
        case .loaded: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle"
        }
    }

    private var statusText: String {
        switch mlxManager.state {
        case .notDownloaded: "~2.3 GB download"
        case .downloading(let p): "Downloading... \(Int(p * 100))%"
        case .downloaded: "Downloaded, not loaded"
        case .loading: "Loading into memory..."
        case .loaded: "Ready"
        case .error(let msg): "Error: \(msg)"
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch mlxManager.state {
        case .notDownloaded:
            Button("Download") {
                Task { await mlxManager.downloadAndLoad() }
            }
            .buttonStyle(.glassProminent)

        case .downloading:
            ProgressView()
                .controlSize(.small)

        case .downloaded:
            Button("Load") {
                Task { try? await mlxManager.loadModel() }
            }
            .buttonStyle(.glassProminent)

        case .loading:
            ProgressView()
                .controlSize(.small)

        case .loaded:
            Button("Remove") {
                mlxManager.unloadModel()
            }
            .foregroundStyle(OTheme.signalRed)

        case .error:
            Button("Retry") {
                Task { await mlxManager.downloadAndLoad() }
            }
            .buttonStyle(.glassProminent)
        }
    }
}
