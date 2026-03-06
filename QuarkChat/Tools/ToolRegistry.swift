import Foundation

/// Maps tool names to executor closures so MLX can call the same tool logic
/// that Foundation Models calls through `@Generable`.
actor ToolRegistry {
    static let shared = ToolRegistry()

    private var executors: [String: @Sendable ([String: Any]) async throws -> String] = [:]

    func register(name: String, executor: @Sendable @escaping ([String: Any]) async throws -> String) {
        executors[name] = executor
    }

    func execute(name: String, arguments: [String: Any]) async throws -> String {
        guard let executor = executors[name] else {
            return "Unknown tool: \(name)"
        }
        return try await executor(arguments)
    }

    func clear() {
        executors.removeAll()
    }
}
