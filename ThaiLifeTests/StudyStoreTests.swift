@testable import ThaiLife
import XCTest
import SwiftData

@MainActor
final class StudyStoreTests: XCTestCase {
    var container: ModelContainer!
    var store: StudyStore!

    override func setUp() async throws {
        container = try AppContainer.makeModelContainer(inMemory: true)
        store = StudyStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        container = nil
        store = nil
    }

    func testAppendingSameReviewIDTwiceCreatesOneLogicalReview() throws {
        let review = ReviewLogRecord(id: "test-uuid-001", contentID: "basics-word-001", direction: "thai→zh", rating: "good")
        try store.appendReview(review)
        try store.appendReview(review)
        let logs = try store.logs(for: "basics-word-001")
        XCTAssertEqual(logs.count, 1)
    }

    func testLogsAreChronological() throws {
        let now = Date()
        let r1 = ReviewLogRecord(id: "uuid-001", contentID: "card-001", direction: "thai→zh", rating: "good", reviewedAt: now.addingTimeInterval(-3600))
        let r2 = ReviewLogRecord(id: "uuid-002", contentID: "card-001", direction: "zh→thai", rating: "easy", reviewedAt: now)
        try store.appendReview(r1)
        try store.appendReview(r2)
        let logs = try store.logs(for: "card-001")
        XCTAssertEqual(logs.count, 2)
        XCTAssertTrue(logs[0].reviewedAt < logs[1].reviewedAt)
    }

    func testToggleFavoriteCreatesAndRemoves() throws {
        XCTAssertFalse(try store.isFavorite(contentID: "id-1"))
        try store.toggleFavorite(contentID: "id-1")
        XCTAssertTrue(try store.isFavorite(contentID: "id-1"))
        try store.toggleFavorite(contentID: "id-1")
        XCTAssertFalse(try store.isFavorite(contentID: "id-1"))
    }

    func testSaveAndRestoreDraft() throws {
        try store.saveDraft(queueIDs: ["a","b","c"], cursor: 1, source: "daily")
        let draft = try store.restoreDraft()
        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.cursor, 1)
    }

    func testSettingsDefaultsToRetention90() throws {
        let s = try store.settings()
        XCTAssertEqual(s.desiredRetention, 0.90)
    }

    func testUpdateSettingsChangesRetention() throws {
        try store.updateSettings(desiredRetention: 0.85)
        let s = try store.settings()
        XCTAssertEqual(s.desiredRetention, 0.85)
    }

    func testDraftDoesNotCreateReviewLogs() throws {
        try store.saveDraft(queueIDs: ["card-001"], cursor: 0, source: "daily")
        let logs = try store.allLogs()
        XCTAssertEqual(logs.count, 0)
    }

    func testSameTimestampSortsById() throws {
        let ts = Date()
        let logB = ReviewLogRecord(id: "uuid-bbb", contentID: "card-1", direction: "thai→zh", rating: "good", reviewedAt: ts)
        let logA = ReviewLogRecord(id: "uuid-aaa", contentID: "card-1", direction: "zh→thai", rating: "easy", reviewedAt: ts)
        try store.appendReview(logB)
        try store.appendReview(logA)
        let logs = try store.logs(for: "card-1")
        XCTAssertEqual(logs.count, 2)
        // Same timestamp — should be ordered by id
        XCTAssertEqual(logs[0].id, "uuid-aaa", "Same-timestamp logs sort by id asc")
        XCTAssertEqual(logs[1].id, "uuid-bbb")
    }
}
@testable import ThaiLife
import XCTest

final class ReviewSessionRouteTests: XCTestCase {
    func testDraftSourceIsScopedToRoute() {
        XCTAssertTrue(ReviewSessionRoute.daily.acceptsDraftSource("daily"))
        XCTAssertFalse(ReviewSessionRoute.daily.acceptsDraftSource("unit:basics"))
        XCTAssertTrue(ReviewSessionRoute.unit("basics").acceptsDraftSource("unit:basics"))
        XCTAssertFalse(ReviewSessionRoute.unit("basics").acceptsDraftSource("daily"))
        XCTAssertFalse(ReviewSessionRoute.unit("social").acceptsDraftSource("unit:basics"))
    }
}
