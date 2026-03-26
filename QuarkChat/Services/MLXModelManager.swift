import Foundation
import Observation
import MLX
import MLXLLM
import MLXLMCommon
#if canImport(UIKit)
import UIKit
#endif

@Observable
@MainActor
final class MLXModelManager {
    static let shared = MLXModelManager()

    enum ModelState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case loading
        case loaded
        case error(String)

        static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.notDownloaded, .notDownloaded),
                 (.downloaded, .downloaded),
                 (.loading, .loading),
                 (.loaded, .loaded):
                return true
            case (.downloading(let a), .downloading(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    /// Per-model state and containers, keyed by ModelBackendType.
    private(set) var states: [ModelBackendType: ModelState] = [
        .mlxBalanced: .notDownloaded,
        .mlx: .notDownloaded,
    ]
    private var containers: [ModelBackendType: ModelContainer] = [:]
    private var downloadedFlags: [ModelBackendType: Bool] = [
        .mlxBalanced: false,
        .mlx: false,
    ]
    private var loadTasks: [ModelBackendType: Task<ModelContainer, Error>] = [:]

    /// The currently active model type (set by ChatService when initializing a session).
    var activeModelType: ModelBackendType = .mlx

    /// Convenience accessors for the active model.
    var state: ModelState { states[activeModelType] ?? .notDownloaded }
    var container: ModelContainer? { containers[activeModelType] }
    var isDownloaded: Bool { downloadedFlags[activeModelType] ?? false }

    static let modelConfigurations: [ModelBackendType: ModelConfiguration] = [
        .mlxBalanced: LLMRegistry.qwen3_1_7b_4bit,
        .mlx: LLMRegistry.qwen3_4b_4bit,
    ]

    private init() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.evictFromMemory()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.evictFromMemory()
            }
        }
        #endif
    }

    // MARK: - Configuration

    static func modelConfiguration(for type: ModelBackendType) -> ModelConfiguration {
        modelConfigurations[type] ?? LLMRegistry.qwen3_4b_4bit
    }

    static func modelDisplayName(for type: ModelBackendType) -> String {
        switch type {
        case .mlxBalanced: "Qwen3-1.7B"
        case .mlx: "Qwen3-4B"
        default: "Unknown"
        }
    }

    static func modelDownloadSize(for type: ModelBackendType) -> String {
        switch type {
        case .mlxBalanced: "~1 GB"
        case .mlx: "~2.3 GB"
        default: ""
        }
    }

    // MARK: - State for specific model

    func state(for type: ModelBackendType) -> ModelState {
        states[type] ?? .notDownloaded
    }

    func isDownloaded(for type: ModelBackendType) -> Bool {
        downloadedFlags[type] ?? false
    }

    // MARK: - Download & Load

    func downloadAndLoad(for type: ModelBackendType? = nil) async {
        let modelType = type ?? activeModelType
        let currentState = states[modelType] ?? .notDownloaded

        guard currentState == .notDownloaded || currentState == .downloaded || {
            if case .error = currentState { return true }
            return false
        }() else { return }

        states[modelType] = .downloading(progress: 0)

        MLX.Memory.cacheLimit = 20 * 1024 * 1024

        let config = Self.modelConfiguration(for: modelType)

        do {
            let result = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.states[modelType] = .downloading(progress: progress.fractionCompleted)
                }
            }
            containers[modelType] = result
            downloadedFlags[modelType] = true
            states[modelType] = .loaded
        } catch {
            states[modelType] = .error(error.localizedDescription)
        }
    }

    func loadModel(for type: ModelBackendType? = nil) async throws -> ModelContainer {
        let modelType = type ?? activeModelType

        if let existing = containers[modelType] { return existing }

        if let loadTask = loadTasks[modelType] {
            return try await loadTask.value
        }

        states[modelType] = .loading

        MLX.Memory.cacheLimit = 20 * 1024 * 1024

        let config = Self.modelConfiguration(for: modelType)

        let task = Task<ModelContainer, Error> {
            try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    if progress.fractionCompleted < 1.0 {
                        self?.states[modelType] = .downloading(progress: progress.fractionCompleted)
                    }
                }
            }
        }
        loadTasks[modelType] = task

        do {
            let result = try await task.value
            containers[modelType] = result
            downloadedFlags[modelType] = true
            states[modelType] = .loaded
            loadTasks[modelType] = nil
            return result
        } catch {
            states[modelType] = .error(error.localizedDescription)
            loadTasks[modelType] = nil
            throw error
        }
    }

    // MARK: - Memory Management

    static let didEvictNotification = Notification.Name("MLXModelManagerDidEvict")

    /// Evict all models from GPU/RAM but keep files on disk.
    func evictFromMemory() {
        var didEvict = false
        for modelType in [ModelBackendType.mlxBalanced, .mlx] {
            if containers[modelType] != nil {
                containers[modelType] = nil
                loadTasks[modelType] = nil
                states[modelType] = (downloadedFlags[modelType] ?? false) ? .downloaded : .notDownloaded
                didEvict = true
            }
        }
        if didEvict {
            NotificationCenter.default.post(name: Self.didEvictNotification, object: nil)
            MLX.Memory.clearCache()
        }
    }

    /// Remove a specific model entirely (files + memory).
    func unloadModel(for type: ModelBackendType? = nil) {
        let modelType = type ?? activeModelType
        containers[modelType] = nil
        loadTasks[modelType] = nil
        downloadedFlags[modelType] = false
        MLX.Memory.clearCache()
        states[modelType] = .notDownloaded
    }

    func flushCache() {
        MLX.Memory.clearCache()
    }
}
