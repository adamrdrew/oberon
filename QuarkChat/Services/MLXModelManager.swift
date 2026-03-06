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

    private(set) var state: ModelState = .notDownloaded
    private(set) var container: ModelContainer?

    /// Whether the model files are cached on disk (can reload without downloading).
    private(set) var isDownloaded: Bool = false

    static let modelConfiguration = LLMRegistry.qwen3_4b_4bit

    private var loadTask: Task<ModelContainer, Error>?

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

    // MARK: - Download & Load

    /// Download model files and load into memory in one step.
    /// Progress is reported through state changes.
    func downloadAndLoad() async {
        guard state == .notDownloaded || state == .downloaded || {
            if case .error = state { return true }
            return false
        }() else { return }

        state = .downloading(progress: 0)

        MLX.Memory.cacheLimit = 20 * 1024 * 1024

        do {
            let result = try await LLMModelFactory.shared.loadContainer(
                configuration: Self.modelConfiguration
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state = .downloading(progress: progress.fractionCompleted)
                }
            }
            container = result
            isDownloaded = true
            state = .loaded
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Load model into memory (assumes files already cached from prior download).
    func loadModel() async throws -> ModelContainer {
        if let container { return container }

        if let loadTask {
            return try await loadTask.value
        }

        state = .loading

        MLX.Memory.cacheLimit = 20 * 1024 * 1024

        let task = Task<ModelContainer, Error> {
            try await LLMModelFactory.shared.loadContainer(
                configuration: Self.modelConfiguration
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    // Show download progress if downloading for the first time
                    if progress.fractionCompleted < 1.0 {
                        self?.state = .downloading(progress: progress.fractionCompleted)
                    }
                }
            }
        }
        loadTask = task

        do {
            let result = try await task.value
            container = result
            isDownloaded = true
            state = .loaded
            loadTask = nil
            return result
        } catch {
            state = .error(error.localizedDescription)
            loadTask = nil
            throw error
        }
    }

    // MARK: - Memory Management

    /// Notification posted when the model is evicted from memory.
    /// Backends should observe this to release their sessions.
    static let didEvictNotification = Notification.Name("MLXModelManagerDidEvict")

    /// Evict model from GPU/RAM but keep files on disk.
    /// Used on iOS background transition and memory warnings.
    func evictFromMemory() {
        guard container != nil else { return }
        container = nil
        loadTask = nil
        NotificationCenter.default.post(name: Self.didEvictNotification, object: nil)
        MLX.Memory.clearCache()
        state = isDownloaded ? .downloaded : .notDownloaded
    }

    /// Remove model entirely (files + memory). Used by the "Remove" button.
    func unloadModel() {
        container = nil
        loadTask = nil
        isDownloaded = false
        MLX.Memory.clearCache()
        state = .notDownloaded
    }

    /// Flush GPU cache after generation to reduce memory footprint between turns.
    func flushCache() {
        MLX.Memory.clearCache()
    }
}
