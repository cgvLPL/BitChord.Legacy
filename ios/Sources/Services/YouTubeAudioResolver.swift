import Foundation
import YouTubeKit

/// Resolves a YouTube video ID to a native-playable audio-only stream.
/// The remote fallback is deliberately not enabled; extraction runs locally on-device.
final class YouTubeAudioResolver {
    func resolve(videoID: String) async throws -> URL {
        let youtube = YouTube(videoID: videoID, methods: [.local])
        let streams = try await youtube.streams
        guard let stream = streams
            .filterAudioOnly()
            .filter({ $0.fileExtension == .m4a && $0.isNativelyPlayable })
            .highestAudioBitrateStream() else {
            throw CatalogError.noPlayableStream
        }
        try await stream.waitUntilAvailable()
        return stream.url
    }
}
