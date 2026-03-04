import Foundation
import FoundationModels

struct VideoSearchTool: Tool {
    let name = "video_search"
    let description = "Search for videos. Use when the user asks to find or watch videos about something."

    private let videoService = VideoSearchService()

    @Generable
    struct Arguments {
        @Guide(description: "What to search videos for")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        if await ToolResultStore.shared.hasToolPerformed("video_search") {
            return "Video search already completed. Use the results provided."
        }
        await ToolResultStore.shared.markToolPerformed("video_search")

        let step = PipelineStep(category: .videoSearch, label: "Searching for videos")
        await ToolResultStore.shared.addPipelineStep(step)

        let results = await videoService.search(query: arguments.query, maxResults: 6)

        if results.isEmpty {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "No videos found for '\(arguments.query)'."
        }

        let videoData = VideoSearchData(query: arguments.query, videos: results)
        await ToolResultStore.shared.addRichContent([.videos(videoData)])
        await ToolResultStore.shared.addSuggestedReplies(SuggestedReply.forVideoSearch())
        await ToolResultStore.shared.completePipelineStep(id: step.id)

        return "Found \(results.count) videos for '\(arguments.query)'."
    }
}
