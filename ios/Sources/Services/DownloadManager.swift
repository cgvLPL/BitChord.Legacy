import Foundation
import Combine

final class DownloadManager: ObservableObject {
    @Published private(set) var downloadedFiles: [URL] = []
    @Published private(set) var activeDownloads: Set<String> = []

    private let fileManager = FileManager.default

    init() { refresh() }

    func download(_ track: Track) async throws {
        guard let url = track.streamURL else { throw CatalogError.noPlayableStream }
        await MainActor.run { self.activeDownloads.insert(track.id) }
        defer { Task { @MainActor in self.activeDownloads.remove(track.id) } }
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CatalogError.badResponse
        }
        let fileExtension = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let destination = downloadsDirectory().appendingPathComponent(safeFilename(track.title) + "." + fileExtension)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: temporaryURL, to: destination)
        await MainActor.run { self.refresh() }
    }

    func track(for file: URL) -> Track {
        Track(id: file.absoluteString, title: file.deletingPathExtension().lastPathComponent,
              artist: "Downloaded", album: "Offline library", artworkURL: nil,
              streamURL: file, provider: "local", providerID: nil)
    }

    func delete(_ file: URL) {
        try? fileManager.removeItem(at: file)
        refresh()
    }

    func refresh() {
        let directory = downloadsDirectory()
        downloadedFiles = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    private func downloadsDirectory() -> URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("BitChord Downloads", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func safeFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        return value.components(separatedBy: invalid).joined(separator: "-")
    }
}
