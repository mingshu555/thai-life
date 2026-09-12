@testable import ThaiLife
import XCTest
import SwiftData

@MainActor
final class StudyQueueBuilderTests: XCTestCase {
    var container: ModelContainer!
    var store: StudyStore!

    override func setUp() async throws {
        container = try AppContainer.makeModelContainer(inMemory: true)
        store = StudyStore(context: container.mainContext)
    }

    func makeItem(_ id: String, category: ContentCategory = .basics, prereqs: [String] = [], related: [String] = []) -> ContentItem {
        var item = ContentItem.fixture(id: id, category: category, prerequisiteIDs: prereqs)
        return ContentItem(
            id: item.id, kind: item.kind, category: item.category, tags: item.tags,
            thai: item.thai, romanization: item.romanization, meaningZhHans: item.meaningZhHans,
            usageNote: item.usageNote, frequencyTier: item.frequencyTier, audioID: item.audioID,
            prerequisiteIDs: item.prerequisiteIDs, relatedIDs: related,
            example: item.example, segments: item.segments,
            sourceID: item.sourceID, contentVersion: item.contentVersion
        )
    }

    func makeState(_ id: String, state: StudyCardState, due: Date) -> FSRSScheduler.CardSchedulingInfo {
        FSRSScheduler.CardSchedulingInfo(
            contentID: id, state: state, due: due,
            stability: state == .review ? 10 : 0,
            difficulty: 0, elapsedDays: 0, reps: 1, lapses: 0
        )
    }

    func testDueCardsComeBeforeNewCards() {
        let now = Date()
        let items = [makeItem("due-a"), makeItem("due-b"), makeItem("new-c"), makeItem("new-d")]
        let states: [String: FSRSScheduler.CardSchedulingInfo] = [
            "due-a": makeState("due-a", state: .review, due: now.addingTimeInterval(-3600)),
            "due-b": makeState("due-b", state: .review, due: now.addingTimeInterval(-7200)),
            "new-c": makeState("new-c", state: .new, due: now),
            "new-d": makeState("new-d", state: .new, due: now),
        ]

        let queue = StudyQueueBuilder.makeQueue(now: now, content: items, cardStates: states, logs: [])

        let firstTwo = queue.prefix(2).map(\.contentID)
        XCTAssertTrue(firstTwo.contains("due-a") || firstTwo.contains("due-b"))
        // Due cards should appear before new cards
        let duePositions = queue.indices.filter { queue[$0].reason == "due" }
        let newPositions = queue.indices.filter { queue[$0].reason == "new" }
        if let maxDue = duePositions.max(), let minNew = newPositions.min() {
            XCTAssertLessThan(maxDue, minNew)
        }
    }

    func testBacklogReducesNewCardsToZero() {
        let now = Date()
        var items: [ContentItem] = []
        var states: [String: FSRSScheduler.CardSchedulingInfo] = [:]
        for i in 0..<60 {
            let id = "due-\(i)"
            items.append(makeItem(id))
            states[id] = makeState(id, state: .review, due: now.addingTimeInterval(-Double(i * 3600)))
        }
        for i in 0..<10 {
            let id = "new-\(i)"
            items.append(makeItem(id, category: .social))
            states[id] = makeState(id, state: .new, due: now)
        }
        let settings = StudyQueueBuilder.QueueSettings(dailyNewLimit: 10, backlogThreshold: 50, desiredRetention: 0.90, maxCardsPerSession: 100)
        let queue = StudyQueueBuilder.makeQueue(now: now, content: items, cardStates: states, logs: [], settings: settings)
        let newCards = queue.filter { $0.reason == "new" }
        XCTAssertEqual(newCards.count, 0)
    }

    func testPrerequisitesBlockCard() {
        let now = Date()
        let items = [makeItem("pre-1"), makeItem("dep", prereqs: ["pre-1"])]
        let states: [String: FSRSScheduler.CardSchedulingInfo] = [
            "pre-1": makeState("pre-1", state: .new, due: now),
            "dep": makeState("dep", state: .new, due: now),
        ]
        let queue = StudyQueueBuilder.makeQueue(now: now, content: items, cardStates: states, logs: [])
        let ids = queue.map(\.contentID)
        XCTAssertTrue(ids.contains("pre-1"))
        XCTAssertFalse(ids.contains("dep"))
    }

    func testMaxCardsPerSession() {
        let now = Date()
        var items: [ContentItem] = []
        var states: [String: FSRSScheduler.CardSchedulingInfo] = [:]
        for i in 0..<60 {
            let id = "card-\(i)"
            items.append(makeItem(id, category: .basics))
            states[id] = makeState(id, state: .review, due: now.addingTimeInterval(-3600))
        }
        let settings = StudyQueueBuilder.QueueSettings(dailyNewLimit: 0, backlogThreshold: 100, desiredRetention: 0.90, maxCardsPerSession: 50)
        let queue = StudyQueueBuilder.makeQueue(now: now, content: items, cardStates: states, logs: [], settings: settings)
        XCTAssertLessThanOrEqual(queue.count, 50)
    }
    func testFavoritesPolicyIncludesFutureDueAndUnmetPrerequisite() {
        let now = Date()
        let future = makeItem("favorite-future")
        let blocked = makeItem("favorite-blocked", prereqs: ["missing-prerequisite"])
        let items = [future, blocked]
        let states = [
            future.id: makeState(future.id, state: .review, due: now.addingTimeInterval(3600)),
            blocked.id: makeState(blocked.id, state: .new, due: now)
        ]
        let queue = StudyQueueBuilder.makeQueue(now: now, content: items, cardStates: states, logs: [], policy: .favorites, routeContentIDs: Set(items.map(\.id)))
        XCTAssertEqual(Set(queue.map(\.contentID)), Set(items.map(\.id)))
    }

    func testFavoritesPolicyKeepsMaxCardsPerSessionLimit() {
        let now = Date()
        let items = (0..<51).map { makeItem("favorite-\($0)") }
        let states = Dictionary(uniqueKeysWithValues: items.map { ($0.id, makeState($0.id, state: .new, due: now)) })
        let settings = StudyQueueBuilder.QueueSettings(dailyNewLimit: 1, backlogThreshold: 100, desiredRetention: 0.90, maxCardsPerSession: 50)
        let queue = StudyQueueBuilder.makeQueue(now: now, content: items, cardStates: states, logs: [], settings: settings, policy: .favorites, routeContentIDs: Set(items.map(\.id)))
        XCTAssertEqual(Set(queue.map(\.contentID)).count, 50)
    }

    func testFavoritesPolicyPreservesDialogueContinuations() {
        let now = Date()
        let dialogue = ContentItem(id: "favorite-dialogue", kind: .dialogue, category: .basics, tags: [], thai: "A: hello\nB: hi\nC: bye", romanization: "", meaningZhHans: "test", audioID: "audio-favorite-dialogue", sourceID: "test")
        let state = makeState(dialogue.id, state: .new, due: now)
        let queue = StudyQueueBuilder.makeQueue(now: now, content: [dialogue], cardStates: [dialogue.id: state], logs: [], policy: .favorites, routeContentIDs: [dialogue.id])
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue.filter { $0.reason == "continuation" }.count, 2)
        XCTAssertTrue(queue[0].needsContinuation)
    }


    func testDailyPlanUsesRemainingCalendarDayQuota() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12))!
        let today = calendar.date(byAdding: .hour, value: -2, to: now)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let logs = (0..<3).map { index in
            ReviewLogRecord(
                id: "today-\(index)",
                contentID: "today-\(index)",
                direction: "thai→zh",
                rating: "good",
                reviewedAt: today
            )
        } + [
            ReviewLogRecord(id: "old", contentID: "old", direction: "thai→zh", rating: "good", reviewedAt: yesterday)
        ]
        let items = (0..<5).map { makeItem("new-\($0)") }
        let states = Dictionary(uniqueKeysWithValues: items.map {
            ($0.id, makeState($0.id, state: .new, due: now))
        })
        let settings = StudyQueueBuilder.QueueSettings(
            dailyNewLimit: 5,
            backlogThreshold: 50,
            desiredRetention: 0.90,
            maxCardsPerSession: 50
        )

        let plan = StudyQueueBuilder.makeDailyPlan(
            now: now, content: items, cardStates: states, logs: logs, settings: settings
        )

        XCTAssertEqual(StudyQueueBuilder.newCardsStudiedToday(logs: logs, now: now, calendar: calendar), 3)
        XCTAssertEqual(plan.newLimit, 2)
        XCTAssertEqual(plan.queue.filter { $0.reason == "new" }.count, 2)
    }

    func testDailyPlanBlocksFutureScheduledCards() {
        let now = Date()
        let future = makeItem("future")
        let new = makeItem("new")
        let states = [
            future.id: makeState(future.id, state: .review, due: now.addingTimeInterval(3600)),
            new.id: makeState(new.id, state: .new, due: now)
        ]

        let plan = StudyQueueBuilder.makeDailyPlan(
            now: now,
            content: [future, new],
            cardStates: states,
            logs: [],
            settings: .default
        )

        XCTAssertFalse(plan.queue.contains { $0.contentID == future.id })
        XCTAssertEqual(plan.queue.filter { $0.reason == "new" }.count, 1)
    }

    func testWeakestDirectionDetection() throws {
        let logs = [
            ReviewLogRecord(id: "u1", contentID: "card-1", direction: "thai→zh", rating: "again"),
            ReviewLogRecord(id: "u2", contentID: "card-1", direction: "thai→zh", rating: "again"),
            ReviewLogRecord(id: "u3", contentID: "card-1", direction: "zh→thai", rating: "good"),
        ]
        let weakest = StudyQueueBuilder.weakestDirection(for: "card-1", logs: logs)
        XCTAssertEqual(weakest, "thai→zh")
    }

    func testDialogueInsertsContinuationCards() {
        let now = Date()
        let dialogue = ContentItem(
            id: "dial-001", kind: .dialogue, category: .basics, tags: [],
            thai: "A: hello\nB: hi\nC: bye",
            romanization: "", meaningZhHans: "test", audioID: "audio-test",
            sourceID: "test"
        )
        let items = [dialogue]
        let states: [String: FSRSScheduler.CardSchedulingInfo] = [
            "dial-001": FSRSScheduler.CardSchedulingInfo(contentID: "dial-001", state: .new, due: now, stability: 0, difficulty: 0, elapsedDays: 0, reps: 0, lapses: 0)
        ]

        let queue = StudyQueueBuilder.makeQueue(now: now, content: items, cardStates: states, logs: [])
        // Should have 1 main card + 2 continuation cards (turns 1 and 2)
        let contCards = queue.filter { $0.reason == "continuation" }
        XCTAssertEqual(contCards.count, 2, "3-turn dialogue should produce 2 continuation cards")
        XCTAssertEqual(queue.count, 3, "3-turn dialogue should produce 3 total cards")
        // First card is main (not continuation) but marked as needing continuation
        XCTAssertEqual(queue[0].reason, "new")
        XCTAssertTrue(queue[0].needsContinuation, "First card of dialogue should be marked as needing continuation")
    }
}

final class QueueSettingsTests: XCTestCase {
    func testUserSettingsMapToQueueSettings() {
        let userSettings = UserSettingsRecord(
            desiredRetention: 0.84,
            dailyNewLimitOverride: 7
        )

        let settings = StudyQueueBuilder.QueueSettings(userSettings: userSettings)

        XCTAssertEqual(settings.desiredRetention, 0.84, accuracy: 0.0001)
        XCTAssertEqual(settings.dailyNewLimit, 7)
        XCTAssertEqual(settings.backlogThreshold, 50)
        XCTAssertEqual(settings.maxCardsPerSession, 50)
    }
}
