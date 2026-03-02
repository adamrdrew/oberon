import Foundation
import FoundationModels
#if canImport(MusicKit)
import MusicKit
#endif

struct MusicProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        #if canImport(MusicKit)
        let hasAccess = await PermissionService.shared.requestMusicAccess()
        guard hasAccess else {
            return DomainResult(
                enrichmentText: "I need Apple Music permission to play music. Please grant access in Settings > Privacy > Media & Apple Music.",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        do {
            let session = LanguageModelSession(
                instructions: "Extract the music search query and media type from the user's request."
            )

            let response = try await session.respond(
                to: query,
                generating: MusicExtraction.self
            )

            let extraction = response.content
            let searchQuery = extraction.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !searchQuery.isEmpty else { return .empty }

            // Search Apple Music
            var request = MusicCatalogSearchRequest(term: searchQuery, types: [Song.self])
            let searchResponse = try await request.response()

            guard let song = searchResponse.songs.first else {
                return DomainResult(
                    enrichmentText: "Couldn't find '\(searchQuery)' on Apple Music.",
                    citations: [],
                    actions: [],
                    richContent: [],
                    suggestedReplies: []
                )
            }

            // Play the song
            let player = ApplicationMusicPlayer.shared
            player.queue = [song]
            try await player.play()

            let musicData = MusicData(
                title: song.title,
                artist: song.artistName,
                albumName: song.albumTitle,
                artworkURL: song.artwork?.url(width: 200, height: 200)?.absoluteString,
                mediaType: "song"
            )

            return DomainResult(
                enrichmentText: "Now playing: \(song.title) by \(song.artistName)",
                citations: [],
                actions: [],
                richContent: [.music(musicData)],
                suggestedReplies: SuggestedReply.forMusic()
            )
        } catch {
            return DomainResult(
                enrichmentText: "Failed to play music: \(error.localizedDescription)",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }
        #else
        return DomainResult(
            enrichmentText: "Music playback is not available on this platform.",
            citations: [],
            actions: [],
            richContent: [],
            suggestedReplies: []
        )
        #endif
    }
}
