import Foundation

struct CatalogSearchResponse {
    let tracks: [Track]
    let providerName: String
}

struct LyricLine: Identifiable, Decodable {
    var id: Int { Int(time * 1000) }
    let time: Double
    let text: String
}

struct Playlist: Identifiable, Codable {
    var id: UUID
    var name: String
    var tracks: [Track]
    var createdAt: Date

    var trackIDs: [String] { tracks.map { $0.id } }

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.tracks = []
        self.createdAt = Date()
    }
}
