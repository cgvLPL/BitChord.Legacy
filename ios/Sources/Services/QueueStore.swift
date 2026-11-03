import Foundation
import Combine

final class QueueStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var currentIndex: Int = 0

    var current: Track? { tracks.indices.contains(currentIndex) ? tracks[currentIndex] : nil }

    func set(_ items: [Track], startingAt index: Int = 0) {
        tracks = items
        currentIndex = min(max(index, 0), max(items.count - 1, 0))
    }

    func append(_ track: Track) { tracks.append(track) }

    func next() -> Track? {
        guard currentIndex + 1 < tracks.count else { return nil }
        currentIndex += 1
        return current
    }

    func previous() -> Track? {
        guard currentIndex > 0 else { return nil }
        currentIndex -= 1
        return current
    }

    func remove(at index: Int) {
        guard tracks.indices.contains(index) else { return }
        tracks.remove(at: index)
        if tracks.isEmpty { currentIndex = 0 }
        else if index < currentIndex { currentIndex -= 1 }
        else { currentIndex = min(currentIndex, tracks.count - 1) }
    }

    func move(from source: Int, to destination: Int) {
        guard tracks.indices.contains(source), tracks.indices.contains(destination), source != destination else { return }
        let item = tracks.remove(at: source)
        tracks.insert(item, at: destination)
        if currentIndex == source { currentIndex = destination }
        else if source < currentIndex && destination >= currentIndex { currentIndex -= 1 }
        else if source > currentIndex && destination <= currentIndex { currentIndex += 1 }
    }
}
