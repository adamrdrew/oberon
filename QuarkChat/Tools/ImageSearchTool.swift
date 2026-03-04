import Foundation
import FoundationModels

struct ImageSearchTool: Tool {
    let name = "image_search"
    let description = "Search for images on a topic. Use when the user asks to see pictures, photos, or images of something."

    private let imageService = ImageSearchService()

    @Generable
    struct Arguments {
        @Guide(description: "What to search images for")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let step = PipelineStep(category: .imageSearch, label: "Searching for images")
        await ToolResultStore.shared.addPipelineStep(step)

        let results = await imageService.search(query: arguments.query, maxResults: 8)

        if results.isEmpty {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "No images found for '\(arguments.query)'."
        }

        let imageData = ImageSearchData(query: arguments.query, images: results)
        await ToolResultStore.shared.addRichContent([.images(imageData)])
        await ToolResultStore.shared.addSuggestedReplies(SuggestedReply.forImageSearch())
        await ToolResultStore.shared.completePipelineStep(id: step.id)

        return "Found \(results.count) images for '\(arguments.query)'."
    }
}
