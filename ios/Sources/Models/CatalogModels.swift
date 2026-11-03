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
    var trackIDs: [String]
    var createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.trackIDs = []
        self.createdAt = Date()
    }
}
