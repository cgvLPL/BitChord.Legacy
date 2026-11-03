import XCTest
@testable import BitChord

final class QueueStoreTests: XCTestCase {
    func testQueueAdvancesAndRemovesCurrentTrack() {
        let queue = QueueStore()
        let first = Track(id: "one", title: "One", artist: "Artist", album: "Album", artworkURL: nil, streamURL: nil)
        let second = Track(id: "two", title: "Two", artist: "Artist", album: "Album", artworkURL: nil, streamURL: nil)
        queue.set([first, second])
        XCTAssertEqual(queue.current?.id, "one")
        XCTAssertEqual(queue.next()?.id, "two")
        XCTAssertEqual(queue.current?.id, "two")
    }

    func testQueueMoveKeepsCurrentIndexAligned() {
        let queue = QueueStore()
        let a = Track(id: "a", title: "A", artist: "Artist", album: "Album", artworkURL: nil, streamURL: nil)
        let b = Track(id: "b", title: "B", artist: "Artist", album: "Album", artworkURL: nil, streamURL: nil)
        let c = Track(id: "c", title: "C", artist: "Artist", album: "Album", artworkURL: nil, streamURL: nil)
        queue.set([a, b, c], startingAt: 1)
        queue.move(from: 2, to: 0)
        XCTAssertEqual(queue.current?.id, "b")
    }
}
