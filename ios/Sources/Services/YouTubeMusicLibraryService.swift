import Foundation
import Combine

enum YouTubeMusicLibraryError: LocalizedError {
    case notSignedIn
    case invalidResponse
    case noFeedsAvailable

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in to YouTube Music to sync your library."
        case .invalidResponse: return "YouTube Music returned an unreadable library response."
        case .noFeedsAvailable: return "YouTube Music could not load any library sections. Your saved library has been kept on this device."
        }
    }
}

enum YouTubeMusicLibraryKind: String, Codable {
    case playlist
    case album
    case artist
}

struct YouTubeMusicLibraryCollection: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let kind: YouTubeMusicLibraryKind

    var destinationURL: URL? {
        switch kind {
        case .playlist:
            let playlistID = id.hasPrefix("VL") ? String(id.dropFirst(2)) : id
            var components = URLComponents(string: "https://music.youtube.com/playlist")
            components?.queryItems = [URLQueryItem(name: "list", value: playlistID)]
            return components?.url
        case .album, .artist:
            return URL(string: "https://music.youtube.com/browse/\(id)")
        }
    }
}

struct YouTubeMusicLibrarySnapshot: Codable {
    var likedTracks: [Track] = []
    var savedTracks: [Track] = []
    var recentlyPlayed: [Track] = []
    var playlists: [YouTubeMusicLibraryCollection] = []
    var albums: [YouTubeMusicLibraryCollection] = []
    var artists: [YouTubeMusicLibraryCollection] = []
    var syncedAt: Date?
}

private struct YouTubeMusicLibraryFeed {
    var tracks: [Track] = []
    var collections: [YouTubeMusicLibraryCollection] = []
    var continuation: String?
}

final class YouTubeMusicLibraryService {
    private let authStore: YouTubeMusicAuthStore
    private let session: URLSession
    private let endpoint = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false")!

    init(authStore: YouTubeMusicAuthStore, session: URLSession = .shared) {
        self.authStore = authStore
        self.session = session
    }

    func fetchSnapshot() async throws -> YouTubeMusicLibrarySnapshot {
        guard authStore.isSignedIn, authStore.account != nil else {
            throw YouTubeMusicLibraryError.notSignedIn
        }

        async let liked = safeFeed("VLLM", kind: nil)
        async let saved = safeFeed("FEmusic_liked_videos", kind: nil)
        async let history = safeFeed("FEmusic_history", kind: nil)
        async let playlists = safeFeed("FEmusic_liked_playlists", kind: .playlist)
        async let albums = safeFeed("FEmusic_liked_albums", kind: .album)
        async let artists = safeFeed("FEmusic_library_corpus_track_artists", kind: .artist)

        let results = await (liked, saved, history, playlists, albums, artists)
        let available = [results.0, results.1, results.2, results.3, results.4, results.5].compactMap { $0 }
        guard !available.isEmpty else { throw YouTubeMusicLibraryError.noFeedsAvailable }

        return YouTubeMusicLibrarySnapshot(
            likedTracks: results.0?.tracks ?? [],
            savedTracks: results.1?.tracks ?? [],
            recentlyPlayed: results.2?.tracks ?? [],
            playlists: results.3?.collections ?? [],
            albums: results.4?.collections ?? [],
            artists: results.5?.collections ?? [],
            syncedAt: Date()
        )
    }

    private func safeFeed(_ browseID: String, kind: YouTubeMusicLibraryKind?) async -> YouTubeMusicLibraryFeed? {
        try? await fetchFeed(browseID, kind: kind)
    }

    private func fetchFeed(_ browseID: String, kind: YouTubeMusicLibraryKind?) async throws -> YouTubeMusicLibraryFeed {
        var response = try await browse(["browseId": browseID])
        var output = YouTubeMusicLibraryFeed()
        var seenTokens = Set<String>()
        var page = 0

        while page < 25 {
            let parsed = parse(response, kind: kind)
            output.tracks.append(contentsOf: parsed.tracks)
            output.collections.append(contentsOf: parsed.collections)
            guard let token = parsed.continuation, seenTokens.insert(token).inserted else { break }
            page += 1
            response = try await browse(["continuation": token], continuation: token)
        }

        output.tracks = unique(output.tracks, by: \.id)
        output.collections = unique(output.collections, by: \.id)
        return output
    }

    private func browse(_ fields: [String: String], continuation: String? = nil) async throws -> Any {
        guard let account = authStore.account, account.loggedIn else {
            throw YouTubeMusicLibraryError.notSignedIn
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(account.clientVersion ?? "1.20250101.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        authStore.applyAuthentication(to: &request)

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "prettyPrint", value: "false"),
                                  URLQueryItem(name: "hl", value: Locale.current.languageCode ?? "en")]
        if let continuation = continuation {
            components?.queryItems?.append(contentsOf: [
                URLQueryItem(name: "ctoken", value: continuation),
                URLQueryItem(name: "continuation", value: continuation),
                URLQueryItem(name: "type", value: "next")
            ])
        }
        if let url = components?.url { request.url = url }

        let client: [String: Any] = [
            "clientName": "WEB_REMIX",
            "clientVersion": account.clientVersion ?? "1.20250101.01.00",
            "hl": Locale.current.languageCode ?? "en",
            "gl": Locale.current.regionCode ?? "US",
            "visitorData": account.visitorData as Any? ?? NSNull()
        ]
        var user: [String: Any] = ["lockedSafetyMode": false]
        if let dataSyncID = account.dataSyncID, !dataSyncID.isEmpty {
            user["onBehalfOfUser"] = dataSyncID
        }
        let context: [String: Any] = [
            "client": client.filter { !($0.value is NSNull) },
            "user": user,
            "request": ["useSsl": true]
        ]
        var payload: [String: Any] = ["context": context]
        fields.forEach { payload[$0.key] = $0.value }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw YouTubeMusicLibraryError.invalidResponse }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw CatalogError.server("YouTube Music rejected this session. Reconnect your Google account and sync again.")
            }
            throw CatalogError.server("YouTube Music library request failed (HTTP \(http.statusCode)).")
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func parse(_ value: Any, kind: YouTubeMusicLibraryKind?) -> YouTubeMusicLibraryFeed {
        var feed = YouTubeMusicLibraryFeed()
        walk(value) { dictionary in
            if let renderer = dictionary["musicResponsiveListItemRenderer"] as? [String: Any],
               let track = parseTrack(renderer) {
                feed.tracks.append(track)
            }
            if let renderer = dictionary["musicTwoRowItemRenderer"] as? [String: Any],
               let collection = parseCollection(renderer, kind: kind) {
                feed.collections.append(collection)
            }
        }
        feed.continuation = continuationToken(in: value)
        return feed
    }

    private func parseTrack(_ renderer: [String: Any]) -> Track? {
        let columns = renderer["flexColumns"] as? [[String: Any]] ?? []
        guard let title = columns.first.flatMap({ column -> String? in
            guard let flex = column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any] else { return nil }
            return textValue(flex["text"])
        }), !title.isEmpty, let videoID = findString("videoId", in: renderer) else { return nil }

        let artist = columns.count > 1
            ? ((columns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]).flatMap { textValue($0["text"]) } ?? "Unknown artist")
            : "Unknown artist"
        let album = columns.count > 2
            ? ((columns[2]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]).flatMap { textValue($0["text"]) } ?? "")
            : ""
        return Track(id: videoID, title: title, artist: artist, album: album,
                     artworkURL: thumbnailURL(in: renderer), streamURL: nil,
                     provider: "youtube", providerID: videoID)
    }

    private func parseCollection(_ renderer: [String: Any], kind: YouTubeMusicLibraryKind?) -> YouTubeMusicLibraryCollection? {
        guard let kind = kind,
              let title = textValue(renderer["title"]), !title.isEmpty,
              let browseID = findBrowseID(in: renderer) else { return nil }
        let subtitle = textValue(renderer["subtitle"]) ?? textValue(renderer["subtitleText"]) ?? ""
        return YouTubeMusicLibraryCollection(id: browseID, title: title, subtitle: subtitle,
                                             artworkURL: thumbnailURL(in: renderer), kind: kind)
    }

    private func textValue(_ value: Any?) -> String? {
        guard let object = value as? [String: Any] else { return nil }
        if let simple = object["simpleText"] as? String { return simple }
        if let runs = object["runs"] as? [[String: Any]] {
            let result = runs.compactMap { $0["text"] as? String }.joined()
            return result.isEmpty ? nil : result
        }
        return nil
    }

    private func thumbnailURL(in value: Any) -> URL? {
        var found: URL?
        walk(value) { dictionary in
            guard found == nil, let thumbnails = dictionary["thumbnails"] as? [[String: Any]] else { return }
            for thumbnail in thumbnails.reversed() {
                if let raw = thumbnail["url"] as? String, let url = URL(string: raw) {
                    found = url
                    break
                }
            }
        }
        return found
    }

    private func findBrowseID(in value: Any) -> String? {
        var found: String?
        walk(value) { dictionary in
            guard found == nil,
                  let endpoint = dictionary["browseEndpoint"] as? [String: Any],
                  let browseID = endpoint["browseId"] as? String else { return }
            found = browseID
        }
        return found
    }

    private func findString(_ key: String, in value: Any) -> String? {
        var found: String?
        walk(value) { dictionary in
            if found == nil { found = dictionary[key] as? String }
        }
        return found
    }

    private func continuationToken(in value: Any) -> String? {
        var found: String?
        walk(value) { dictionary in
            guard found == nil else { return }
            if let item = dictionary["continuationItemRenderer"] as? [String: Any],
               let endpoint = item["continuationEndpoint"] as? [String: Any],
               let command = endpoint["continuationCommand"] as? [String: Any],
               let token = command["token"] as? String {
                found = token
                return
            }
            for key in ["nextContinuationData", "reloadContinuationData"] {
                if let data = dictionary[key] as? [String: Any], let token = data["continuation"] as? String {
                    found = token
                    return
                }
            }
        }
        return found
    }

    private func walk(_ value: Any, visit: ([String: Any]) -> Void) {
        if let dictionary = value as? [String: Any] {
            visit(dictionary)
            dictionary.values.forEach { walk($0, visit: visit) }
        } else if let array = value as? [Any] {
            array.forEach { walk($0, visit: visit) }
        }
    }

    private func unique<T>(_ values: [T], by key: (T) -> String) -> [T] {
        var seen = Set<String>()
        return values.filter { seen.insert(key($0)).inserted }
    }
}

@MainActor
final class YouTubeMusicLibraryStore: ObservableObject {
    @Published private(set) var snapshot: YouTubeMusicLibrarySnapshot
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?
    private let storageKey = "bitchord.youtube-music-library.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(YouTubeMusicLibrarySnapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = YouTubeMusicLibrarySnapshot()
        }
    }

    func refreshIfNeeded(authStore: YouTubeMusicAuthStore) async {
        guard authStore.isSignedIn else { return }
        if let syncedAt = snapshot.syncedAt, Date().timeIntervalSince(syncedAt) < 300 { return }
        await refresh(authStore: authStore)
    }

    func refresh(authStore: YouTubeMusicAuthStore) async {
        guard !isSyncing, authStore.isSignedIn else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            let fresh = try await YouTubeMusicLibraryService(authStore: authStore).fetchSnapshot()
            snapshot = fresh
            if let data = try? JSONEncoder().encode(fresh) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        snapshot = YouTubeMusicLibrarySnapshot()
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
