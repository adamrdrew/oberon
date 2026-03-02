import Foundation
import FoundationModels

@Generable
struct MusicExtraction {
    @Guide(description: "Search query for music, e.g. 'jazz', 'Beatles Hey Jude'")
    var searchQuery: String

    @Guide(description: "Type of media to search for", .anyOf(["song", "album", "playlist"]))
    var mediaType: String
}
