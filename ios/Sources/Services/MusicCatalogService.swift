import Foundation

enum CatalogError: LocalizedError {
    case invalidURL
    case badResponse
    case noPlayableStream
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The source URL is invalid."
        case .badResponse: return "The music service returned an unexpected response."
        case .noPlayableStream: return "This result has no direct audio stream. Configure a compatible source or open it in YouTube Music."
        case .server(let message): return message
        }
    }
}

protocol MusicCatalogService {
    func search(_ query: String) async throws -> [Track]
}

final class YouTubeMusicCatalog: MusicCatalogService {
    private let session: URLSession
    private let endpoint = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false")!

    init(session: URLSession = .shared) { self.session = session }

    func search(_ query: String) async throws -> [Track] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        let payload: [String: Any] = [
            "context": ["client": [
                "clientName": "WEB_REMIX",
                "clientVersion": "1.20250616.01.00",
                "hl": Locale.current.languageCode ?? "en",
                "gl": Locale.current.regionCode ?? "US"
            ]],
            "query": query
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CatalogError.badResponse }
        let json = try JSONSerialization.jsonObject(with: data)
        var found: [Track] = []
        collectTracks(in: json, into: &found)
        var seen = Set<String>()
        return found.filter { seen.insert($0.id).inserted }.prefix(30).map { $0 }
    }

    private func collectTracks(in value: Any, into tracks: inout [Track]) {
        if let dictionary = value as? [String: Any] {
            if let renderer = dictionary["musicResponsiveListItemRenderer"] as? [String: Any],
               let track = parse(renderer) { tracks.append(track) }
            for child in dictionary.values { collectTracks(in: child, into: &tracks) }
        } else if let array = value as? [Any] {
            for child in array { collectTracks(in: child, into: &tracks) }
        }
    }

    private func parse(_ renderer: [String: Any]) -> Track? {
        let flex = renderer["flexColumns"] as? [[String: Any]] ?? []
        let title = flex.first.flatMap { column -> String? in
            let runs = ((column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
            return runs?.compactMap { $0["text"] as? String }.joined()
        }
        guard let title = title, !title.isEmpty, let id = findVideoID(in: renderer) else { return nil }
        var artist = "Unknown artist"
        if flex.count > 1 {
            let runs = ((flex[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
            artist = runs?.compactMap { $0["text"] as? String }.joined(separator: " ") ?? artist
        }
        let thumbnails = ((renderer["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any])?["thumbnail"] as? [String: Any]
        let thumbList = thumbnails?["thumbnails"] as? [[String: Any]]
        let artwork = (thumbList?.last?["url"] as? String).flatMap(URL.init(string:))
        return Track(id: id, title: title, artist: artist, album: "YouTube Music",
                     artworkURL: artwork, streamURL: nil, provider: "youtube", providerID: id)
    }

    private func findVideoID(in value: Any) -> String? {
        if let dictionary = value as? [String: Any] {
            if let id = dictionary["videoId"] as? String { return id }
            for child in dictionary.values {
                if let id = findVideoID(in: child) { return id }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let id = findVideoID(in: child) { return id }
            }
        }
        return nil
    }
}

final class AddonCatalog: MusicCatalogService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURLString: String, session: URLSession = .shared) throws {
        guard let url = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https" || url.scheme == "http", url.host != nil else {
            throw CatalogError.invalidURL
        }
        self.baseURL = url
        self.session = session
    }

    func search(_ query: String) async throws -> [Track] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false) else {
            throw CatalogError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { throw CatalogError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CatalogError.badResponse
        }
        let rows = object["tracks"] as? [[String: Any]] ?? []
        var tracks: [Track] = []
        for row in rows.prefix(30) {
            guard let id = row["id"] as? String, let title = row["title"] as? String else { continue }
            let artist = row["artist"] as? String ?? "Unknown artist"
            let album = row["album"] as? String ?? ""
            let artwork = ((row["artworkURL"] as? String) ?? (row["albumArtworkURL"] as? String)).flatMap(URL.init(string:))
            let stream = (row["streamURL"] as? String).flatMap(URL.init(string:))
            tracks.append(Track(id: "addon:\(id)", title: title, artist: artist, album: album,
                                artworkURL: artwork, streamURL: stream, provider: "addon", providerID: id))
        }
        return tracks
    }

    func streamURL(trackID: String) async throws -> URL? {
        let url = baseURL.appendingPathComponent("stream").appendingPathComponent(trackID)
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawURL = object["url"] as? String else { return nil }
        return URL(string: rawURL)
    }
}
