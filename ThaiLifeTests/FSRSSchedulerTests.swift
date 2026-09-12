@testable import ThaiLife
import XCTest
import SwiftData

@MainActor
final class FSRSSchedulerTests: XCTestCase {
    var container: ModelContainer!
    var store: StudyStore!

    override func setUp() async throws {
        container = try AppContainer.makeModelContainer(inMemory: true)
        store = StudyStore(context: container.mainContext)
    }

    func testNewCardHasNewState() {
        let states = FSRSScheduler.replay(logs: [], contentIDs: ["test-1"], now: Date())
        XCTAssertEqual(states["test-1"]?.state, .new)
    }

    func testReviewedCardHasReviewState() throws {
        let now = Date()
        let log = ReviewLogRecord(id: "uuid-001", contentID: "card-1", direction: "thai→zh", rating: "good", reviewedAt: now.addingTimeInterval(-86400))
        try store.appendReview(log)
        let allLogs = try store.allLogs()
        let states = FSRSScheduler.replay(logs: allLogs, contentIDs: ["card-1"], now: now)
        // A card reviewed 1 day ago with "good" should not be "new"
        XCTAssertNotEqual(states["card-1"]?.state, .new)
    }

    func testAgainRatingCountsAsLapse() throws {
        let now = Date()
        let log1 = ReviewLogRecord(id: "uuid-001", contentID: "card-1", direction: "thai→zh", rating: "good", reviewedAt: now.addingTimeInterval(-86400 * 10))
        let log2 = ReviewLogRecord(id: "uuid-002", contentID: "card-1", direction: "thai→zh", rating: "good", reviewedAt: now.addingTimeInterval(-86400 * 5))
        let log3 = ReviewLogRecord(id: "uuid-003", contentID: "card-1", direction: "thai→zh", rating: "again", reviewedAt: now.addingTimeInterval(-3600))
        try store.appendReview(log1)
        try store.appendReview(log2)
        try store.appendReview(log3)
        let allLogs = try store.allLogs()
        let states = FSRSScheduler.replay(logs: allLogs, contentIDs: ["card-1"], now: now)
        XCTAssertEqual(states["card-1"]?.lapses, 1)
    }

    func testDeterministicReplay() throws {
        let now = Date()
        let logs = [
            ReviewLogRecord(id: "uuid-001", contentID: "card-a", direction: "thai→zh", rating: "good", reviewedAt: now.addingTimeInterval(-7200)),
            ReviewLogRecord(id: "uuid-002", contentID: "card-a", direction: "zh→thai", rating: "easy", reviewedAt: now.addingTimeInterval(-3600)),
        ]
        for log in logs { try store.appendReview(log) }
        let allLogs = try store.allLogs()
        let s1 = FSRSScheduler.replay(logs: allLogs, contentIDs: ["card-a"], now: now)
        let s2 = FSRSScheduler.replay(logs: allLogs, contentIDs: ["card-a"], now: now)
        XCTAssertEqual(s1["card-a"]?.due.timeIntervalSince1970 ?? 0,
                       s2["card-a"]?.due.timeIntervalSince1970 ?? 1, accuracy: 0.001)
    }

    func testSameTimestampDeterministic() {
        let now = Date()
        let ts = now.addingTimeInterval(-3600)
        let logs = [
            ReviewLogRecord(id: "uuid-aaa", contentID: "card-1", direction: "thai→zh", rating: "good", reviewedAt: ts),
            ReviewLogRecord(id: "uuid-bbb", contentID: "card-1", direction: "zh→thai", rating: "easy", reviewedAt: ts),
        ]
        // Sort by (reviewedAt, id) guarantees determinism
        let s1 = FSRSScheduler.replay(logs: logs, contentIDs: ["card-1"], now: now)
        let s2 = FSRSScheduler.replay(logs: logs, contentIDs: ["card-1"], now: now)
        XCTAssertEqual(s1["card-1"]?.due.timeIntervalSince1970 ?? 0,
                       s2["card-1"]?.due.timeIntervalSince1970 ?? 1, accuracy: 0.001)
    }
}

extension FSRSSchedulerTests {
    func testDefaultParametersUseRequestedRetentionAndFSRS6Weights() {
        let parameters = FSRSScheduler.defaultParameters(desiredRetention: 0.82)

        XCTAssertEqual(parameters.requestRetention, 0.82, accuracy: 0.0001)
        XCTAssertEqual(parameters.w.count, 21)
        XCTAssertEqual(FSRSAlgorithmVersion.detect(parameters.w), .v6)
    }
}
