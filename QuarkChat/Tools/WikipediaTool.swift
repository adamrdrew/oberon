import Foundation
import FoundationModels

struct WikipediaTool: Tool {
    let name = "wikipedia"
    let description = "Look up a topic on Wikipedia to show the user a rich article card with images and details."

    private let wikiService = WikipediaService()

    @Generable
    struct Arguments {
        @Guide(description: "The topic to look up on Wikipedia")
        var topic: String
    }

    func call(arguments: Arguments) async throws -> String {
        if await ToolResultStore.shared.hasToolPerformed("wikipedia") {
            return "Wikipedia lookup already completed. Use the results provided."
        }
        await ToolResultStore.shared.markToolPerformed("wikipedia")

        let step = PipelineStep(category: .wikipedia, label: "Looking up on Wikipedia")
        await ToolResultStore.shared.addPipelineStep(step)

        guard let data = await wikiService.fetchArticleData(title: arguments.topic) else {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "No Wikipedia article found for '\(arguments.topic)'."
        }

        await ToolResultStore.shared.addRichContent([.wikipedia(data)])
        await ToolResultStore.shared.addSuggestedReplies(SuggestedReply.forWikipedia())
        await ToolResultStore.shared.completePipelineStep(id: step.id)

        let extract = String(data.extract.prefix(200))
        return "\(data.title): \(data.description ?? ""). \(extract)"
    }
}
