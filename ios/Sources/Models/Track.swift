import Foundation

struct Track: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let streamURL: URL?
    var provider: String = "local"
    var providerID: String? = nil

    static let previews: [Track] = [
        Track(id: "demo-1", title: "Night Drive", artist: "BitChord Demo", album: "Reference Library", artworkURL: nil, streamURL: nil),
        Track(id: "demo-2", title: "Blue Hour", artist: "BitChord Demo", album: "Reference Library", artworkURL: nil, streamURL: nil),
        Track(id: "demo-3", title: "Afterglow", artist: "BitChord Demo", album: "Reference Library", artworkURL: nil, streamURL: nil)
    ]
}
