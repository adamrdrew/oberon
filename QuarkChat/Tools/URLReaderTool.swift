import Foundation
import FoundationModels

struct URLReaderTool: Tool {
    let name = "read_url"
    let description = "Read and summarize a web page. Use when the user shares a URL or link and asks about its content."

    private let webService = WebSearchService()

    @Generable
    struct Arguments {
        @Guide(description: "The URL to read")
        var url: String
    }

    func call(arguments: Arguments) async throws -> String {
        if await ToolResultStore.shared.hasToolPerformed("read_url") {
            return "Page already read. Use the summary provided."
        }
        await ToolResultStore.shared.markToolPerformed("read_url")

        let step = PipelineStep(category: .urlExtraction, label: "Reading page")
        await ToolResultStore.shared.addPipelineStep(step)

        let normalizedURL = arguments.url.hasPrefix("http") ? arguments.url : "https://\(arguments.url)"

        guard let metadata = await webService.fetchWithMetadata(url: normalizedURL) else {
            await ToolResultStore.shared.failPipelineStep(id: step.id)
            return "Could not read the page at '\(arguments.url)'."
        }

        let domain = URL(string: normalizedURL)?.host() ?? normalizedURL

        let previewData = LinkPreviewData(
            url: normalizedURL,
            domain: domain,
            title: metadata.title,
            description: metadata.description,
            imageURL: metadata.imageURL,
            siteName: metadata.siteName,
            summary: metadata.summary
        )

        await ToolResultStore.shared.addRichContent([.linkPreview(previewData)])

        let citation = Citation(title: metadata.title ?? domain, url: normalizedURL)
        await ToolResultStore.shared.addCitations([citation])

        await ToolResultStore.shared.addSuggestedReplies(SuggestedReply.forURLReader())
        await ToolResultStore.shared.completePipelineStep(id: step.id)

        let prefix = metadata.title.map { "Title: \($0). " } ?? ""
        return "\(prefix)Summary: \(metadata.summary)"
    }
}
