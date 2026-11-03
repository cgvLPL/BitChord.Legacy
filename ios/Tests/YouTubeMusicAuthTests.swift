import XCTest
@testable import BitChord

final class YouTubeMusicAuthTests: XCTestCase {
    func testNormalizesDelegatedDataSyncID() {
        XCTAssertEqual(YouTubeMusicAuthStore.normalizeDataSyncID("12345||UCbrand"), "UCbrand")
    }

    func testKeepsPlainPersonalDataSyncID() {
        XCTAssertEqual(YouTubeMusicAuthStore.normalizeDataSyncID("12345"), "12345")
    }

    func testEmptyDelegatedDataSyncIDDoesNotInventAnIdentity() {
        XCTAssertNil(YouTubeMusicAuthStore.normalizeDataSyncID("12345||"))
        XCTAssertNil(YouTubeMusicAuthStore.normalizeDataSyncID(nil))
        XCTAssertNil(YouTubeMusicAuthStore.normalizeDataSyncID(" "))
    }
}
