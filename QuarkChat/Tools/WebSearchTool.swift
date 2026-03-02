import Foundation
import FoundationModels

struct WebSearchTool: Tool {
    let name = "web_search"
    let description = "Search the web for current info"

    private let searchService = WebSearchService()

    @Generable
    struct Arguments {
        @Guide(description: "Search query")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let results = await searchService.search(query: arguments.query, maxResults: 3)

        if results.isEmpty {
            return "No results found for '\(arguments.query)'. Try a different search."
        }

        return results.enumerated().map { index, result in
            "\(index + 1). \(result.title)\n\(result.snippet)"
        }.joined(separator: "\n\n")
    }
}
