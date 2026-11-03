import Foundation

final class LyricsService {
    func fetch(title: String, artist: String, duration: Double) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]
        guard let url = components.url else { throw CatalogError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("BitChord-iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CatalogError.badResponse }
        let result = try JSONDecoder().decode(LRCLibResponse.self, from: data)
        guard let synced = result.syncedLyrics else { return [] }
        return synced.components(separatedBy: .newlines).compactMap { line in
            guard let match = line.range(of: #"^\[(\d+):(\d{2})\.(\d{2,3})\](.*)$"#, options: .regularExpression) else { return nil }
            let parts = String(line[match]).matches(for: #"\d+"#).compactMap(Double.init)
            guard parts.count >= 3 else { return nil }
            let millis = parts[0] * 60000 + parts[1] * 1000 + (parts[2] < 100 ? parts[2] * 10 : parts[2])
            let textStart = line[match].lastIndex(of: "]").map { line.index(after: $0) } ?? line.endIndex
            return LyricLine(time: millis / 1000, text: String(line[textStart...]).trimmingCharacters(in: .whitespaces))
        }
    }
}

private struct LRCLibResponse: Decodable {
    let syncedLyrics: String?
}

private extension String {
    func matches(for pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)
        return regex.matches(in: self, range: range).compactMap {
            guard let range = Range($0.range, in: self) else { return nil }
            return String(self[range])
        }
    }
}
