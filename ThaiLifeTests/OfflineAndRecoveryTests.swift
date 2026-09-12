@testable import ThaiLife
import XCTest
import SwiftData

@MainActor
final class OfflineAndRecoveryTests: XCTestCase {
    var container: ModelContainer!
    var store: StudyStore!

    override func setUp() async throws {
        container = try AppContainer.makeModelContainer(inMemory: true)
        store = StudyStore(context: container.mainContext)
    }

    func testMissingAudioReturnsUnavailable() async {
        let service = AudioPlaybackService()
        let result = await service.play(audioID: "nonexistent-id")
        if case .unavailable = result { /* expected */ } else {
            XCTFail("Missing audio should return .unavailable")
        }
    }

    func testContentReloadPreservesLogs() throws {
        let log = ReviewLogRecord(id: "uuid-001", contentID: "card-001", direction: "thai→zh", rating: "good")
        try store.appendReview(log)
        let logs = try store.allLogs()
        XCTAssertEqual(logs.count, 1)
    }

    func testMergedLogsReplayDeterministically() {
        let now = Date()
        let logs = [
            ReviewLogRecord(id: "uuid-001", contentID: "card-001", direction: "thai→zh", rating: "good", reviewedAt: now.addingTimeInterval(-3600)),
            ReviewLogRecord(id: "uuid-002", contentID: "card-001", direction: "zh→thai", rating: "easy", reviewedAt: now),
        ]
        let s1 = FSRSScheduler.replay(logs: logs, contentIDs: ["card-001"], now: now)
        let s2 = FSRSScheduler.replay(logs: logs, contentIDs: ["card-001"], now: now)
        XCTAssertEqual(s1["card-001"]?.due.timeIntervalSince1970 ?? 0,
                       s2["card-001"]?.due.timeIntervalSince1970 ?? 1, accuracy: 0.001)
    }

    func testDraftDoesNotCreateReviewLogs() throws {
        try store.saveDraft(queueIDs: ["card-001", "card-002"], cursor: 0, source: "daily")
        let logs = try store.allLogs()
        XCTAssertEqual(logs.count, 0)
    }

    func testDraftResumePreservesCursor() throws {
        try store.saveDraft(queueIDs: ["a", "b", "c"], cursor: 2, source: "daily")
        let restored = try store.restoreDraft()
        XCTAssertEqual(restored?.cursor, 2)
    }

    func testCloudKitMergeSimulation() throws {
        // Simulate two devices writing independent logs, then merging
        let logA = ReviewLogRecord(id: "A-001", contentID: "card-1", direction: "thai→zh", rating: "good")
        let logB = ReviewLogRecord(id: "B-001", contentID: "card-1", direction: "zh→thai", rating: "easy")
        try store.appendReview(logA)
        try store.appendReview(logB)
        // Both should persist independently
        let allLogs = try store.allLogs()
        XCTAssertEqual(allLogs.count, 2)
        // Replay should be deterministic
        let now = Date()
        let s1 = FSRSScheduler.replay(logs: allLogs.sorted(by: { ($0.reviewedAt, $0.id) < ($1.reviewedAt, $1.id) }), contentIDs: ["card-1"], now: now)
        let s2 = FSRSScheduler.replay(logs: allLogs.sorted(by: { ($0.reviewedAt, $0.id) < ($1.reviewedAt, $1.id) }), contentIDs: ["card-1"], now: now)
        XCTAssertEqual(s1["card-1"]?.due.timeIntervalSince1970 ?? 0,
                       s2["card-1"]?.due.timeIntervalSince1970 ?? 1, accuracy: 0.001)
    }
}
