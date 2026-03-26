import SwiftUI

struct ModelDownloadView: View {
    let modelType: ModelBackendType
    @State private var mlxManager = MLXModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(OTheme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(MLXModelManager.modelDisplayName(for: modelType))
                        .font(OTheme.body)
                        .foregroundStyle(OTheme.primary)
                    Text(statusText)
                        .font(OTheme.pipelineLabel)
                        .foregroundStyle(OTheme.tertiary)
                }

                Spacer()

                actionButton
            }

            if case .downloading(let progress) = mlxManager.state(for: modelType) {
                ProgressView(value: progress)
                    .tint(OTheme.accent)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: OTheme.cornerRadiusCard))
    }

    // MARK: - Computed Properties

    private var currentState: MLXModelManager.ModelState {
        mlxManager.state(for: modelType)
    }

    private var iconName: String {
        switch currentState {
        case .notDownloaded: "arrow.down.circle"
        case .downloading: "arrow.down.circle"
        case .downloaded: "checkmark.circle"
        case .loading: "gearshape.circle"
        case .loaded: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle"
        }
    }

    private var statusText: String {
        switch currentState {
        case .notDownloaded: MLXModelManager.modelDownloadSize(for: modelType) + " download"
        case .downloading(let p): "Downloading... \(Int(p * 100))%"
        case .downloaded: "Downloaded, not loaded"
        case .loading: "Loading into memory..."
        case .loaded: "Ready"
        case .error(let msg): "Error: \(msg)"
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch currentState {
        case .notDownloaded:
            Button("Download") {
                Task { await mlxManager.downloadAndLoad(for: modelType) }
            }
            .buttonStyle(.glassProminent)

        case .downloading:
            ProgressView()
                .controlSize(.small)

        case .downloaded:
            Button("Load") {
                Task { try? await mlxManager.loadModel(for: modelType) }
            }
            .buttonStyle(.glassProminent)

        case .loading:
            ProgressView()
                .controlSize(.small)

        case .loaded:
            Button("Remove") {
                mlxManager.unloadModel(for: modelType)
            }
            .foregroundStyle(OTheme.signalRed)

        case .error:
            Button("Retry") {
                Task { await mlxManager.downloadAndLoad(for: modelType) }
            }
            .buttonStyle(.glassProminent)
        }
    }
}
