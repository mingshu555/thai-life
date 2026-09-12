@testable import ThaiLife
import XCTest
import SwiftData

@MainActor
final class ReviewSessionViewModelTests: XCTestCase {
    var container: ModelContainer!
    var store: StudyStore!
    var viewModel: ReviewSessionViewModel!
    var appState: AppState!

    override func setUp() async throws {
        container = try AppContainer.makeModelContainer(inMemory: true)
        store = StudyStore(context: container.mainContext)
        viewModel = ReviewSessionViewModel()
        appState = AppState()
        appState.modelContainer = container
        appState.store = store
        appState.contentItems = [
            ContentItem.fixture(id: "card-001"),
            ContentItem.fixture(id: "card-002"),
        ]
    }

    func testUnflippedCardsCreateNoLogs() throws {
        viewModel.loadSession(route: .daily, appState: appState)
        viewModel.goBack(appState: appState)
        let logs = try store.logs(for: "card-001")
        XCTAssertEqual(logs.count, 0, "Unflipped card must not create review logs")
    }

    func testRatingCreatesExactlyOneLog() throws {
        // Pre-create a log so card is not "new"
        try store.appendReview(ReviewLogRecord(id: "pre-1", contentID: "card-001", direction: "thai→zh", rating: "good", reviewedAt: Date().addingTimeInterval(-86400)))
        viewModel.loadSession(route: .daily, appState: appState)
        let beforeCount = (try? store.logs(for: "card-001").count) ?? 0

        if viewModel.currentItem?.id == "card-001" {
            viewModel.flip()
            viewModel.rate("good", appState: appState)
            let afterCount = (try? store.logs(for: "card-001").count) ?? 0
            XCTAssertEqual(afterCount, beforeCount + 1, "Rating must create exactly one new review log")
        }
    }

    func testEmptySessionIsSafe() {
        appState.contentItems = []
        viewModel.loadSession(route: .daily, appState: appState)
        XCTAssertTrue(viewModel.queue.isEmpty)
    }
    func testFavoritesRebuildsFromCurrentIDsInsteadOfStaleDraft() throws {
        appState.contentItems = [ContentItem.fixture(id: "current-favorite"), ContentItem.fixture(id: "stale-favorite")]
        try store.toggleFavorite(contentID: "current-favorite")
        try store.saveDraft(queueIDs: ["stale-favorite"], cursor: 1, source: "favorites")
        viewModel.loadSession(route: .favorites, appState: appState)
        XCTAssertEqual(Set(viewModel.queue.map(\.contentID)), ["current-favorite"])
        XCTAssertEqual(viewModel.cursor, 0)
    }
    func testEmptyFavoritesResetCursorAfterAnActiveSession() throws {
        let item = ContentItem.fixture(id: "current-favorite")
        appState.contentItems = [item]
        try store.toggleFavorite(contentID: item.id)
        viewModel.loadSession(route: .favorites, appState: appState)
        viewModel.goToNext()
        try store.toggleFavorite(contentID: item.id)

        viewModel.loadSession(route: .favorites, appState: appState)

        XCTAssertTrue(viewModel.queue.isEmpty)
        XCTAssertEqual(viewModel.cursor, 0)
        XCTAssertNil(viewModel.currentItem)
    }

    func testFavoritesLoadFailureIsVisibleAndLeavesEmptySession() {
        enum TestFavoriteLoadError: Error { case failed }
        viewModel.loadSession(route: .favorites, appState: appState, favoriteIDsLoader: { _ in throw TestFavoriteLoadError.failed })
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertTrue(viewModel.queue.isEmpty)
        XCTAssertNil(viewModel.currentItem)
    }

    func testFavoritesIncludeCurrentIDsDespiteSchedulingFilters() throws {
        let future = ContentItem.fixture(id: "favorite-future")
        let blocked = ContentItem.fixture(id: "favorite-blocked", prerequisiteIDs: ["missing-prerequisite"])
        appState.contentItems = [future, blocked]
        try store.toggleFavorite(contentID: future.id)
        try store.toggleFavorite(contentID: blocked.id)
        try store.appendReview(ReviewLogRecord(id: "future-review", contentID: future.id, direction: "thai→zh", rating: "good", reviewedAt: Date()))
        viewModel.loadSession(route: .favorites, appState: appState)
        XCTAssertEqual(Set(viewModel.queue.map(\.contentID)), Set([future.id, blocked.id]))
    }
    func testFavoritesRespectMaxCardsPerSession() throws {
        let items = (0..<51).map { ContentItem.fixture(id: "favorite-\($0)") }
        appState.contentItems = items
        for item in items {
            try store.toggleFavorite(contentID: item.id)
        }
        viewModel.loadSession(route: .favorites, appState: appState)
        XCTAssertEqual(Set(viewModel.queue.map(\.contentID)).count, 50)
    }

    func testFavoritesKeepDialogueContinuations() throws {
        let dialogue = ContentItem(id: "favorite-dialogue", kind: .dialogue, category: .basics, tags: [], thai: "A: hello\nB: hi\nC: bye", romanization: "", meaningZhHans: "test", audioID: "audio-favorite-dialogue", sourceID: "test")
        appState.contentItems = [dialogue]
        try store.toggleFavorite(contentID: dialogue.id)
        viewModel.loadSession(route: .favorites, appState: appState)
        XCTAssertEqual(viewModel.queue.count, 3)
        viewModel.goToNext()
        XCTAssertTrue(viewModel.isCurrentContinuation)
    }

    func testCourseBrowseRouteDoesNotHaveDraftSource() {
        let route = ReviewSessionRoute.courseBrowse(category: .basics, startContentID: "basics-word-003")
        XCTAssertNil(route.draftSource)
        XCTAssertTrue(route.isCourseBrowser)
    }

    func testCourseBrowseStartsAtRequestedItemAndKeepsCategoryOrder() {
        appState.contentItems = [
            ContentItem.fixture(id: "basics-word-001", category: .basics),
            ContentItem.fixture(id: "basics-word-002", category: .basics),
            ContentItem.fixture(id: "basics-word-003", category: .basics),
            ContentItem.fixture(id: "food-word-001", category: .foodDining),
        ]

        let route = ReviewSessionRoute.courseBrowse(category: .basics, startContentID: "basics-word-002")
        viewModel.loadSession(route: route, appState: appState)

        XCTAssertEqual(viewModel.queue.count, 3)
        XCTAssertEqual(viewModel.queue.map(\.contentID), ["basics-word-001", "basics-word-002", "basics-word-003"])
        XCTAssertEqual(viewModel.cursor, 1)
        XCTAssertEqual(viewModel.currentItem?.id, "basics-word-002")
    }

    func testCourseBrowseNavigationDoesNotWriteReviewLogOrDraft() throws {
        appState.contentItems = [
            ContentItem.fixture(id: "basics-word-001", category: .basics),
            ContentItem.fixture(id: "basics-word-002", category: .basics),
        ]
        let route = ReviewSessionRoute.courseBrowse(category: .basics, startContentID: "basics-word-001")
        viewModel.loadSession(route: route, appState: appState)

        viewModel.goToNext()
        XCTAssertEqual(viewModel.cursor, 1)

        viewModel.goBack(appState: appState)
        let logs = try store.allLogs()
        XCTAssertTrue(logs.isEmpty, "Course browse must not write review logs")

        let draft = try store.restoreDraft()
        XCTAssertNil(draft, "Course browse must not write or touch drafts")
    }

    func testCourseBrowseKeepsFullCategoryCountInsteadOfDailyNewLimit() {
        var items: [ContentItem] = []
        for i in 1...15 {
            let id = String(format: "basics-word-%03d", i)
            items.append(ContentItem.fixture(id: id, category: .basics))
        }
        appState.contentItems = items

        let route = ReviewSessionRoute.courseBrowse(category: .basics, startContentID: "basics-word-001")
        viewModel.loadSession(route: route, appState: appState)

        XCTAssertEqual(viewModel.queue.count, 15, "Course browse must include all category items, not limited by daily new limit")
    }

    func testCourseBrowseWithInvalidStartContentIDShowsEmptyState() {
        appState.contentItems = [
            ContentItem.fixture(id: "basics-word-001", category: .basics),
            ContentItem.fixture(id: "basics-word-002", category: .basics),
        ]
        let route = ReviewSessionRoute.courseBrowse(category: .basics, startContentID: "invalid-id-999")
        viewModel.loadSession(route: route, appState: appState)

        XCTAssertTrue(viewModel.queue.isEmpty, "Queue must be empty when startContentID is invalid")
        XCTAssertNil(viewModel.currentItem, "currentItem must be nil when startContentID is invalid")
    }

    func testCourseBrowseAtLastCardGoToNextStaysOnLastCard() {
        appState.contentItems = [
            ContentItem.fixture(id: "basics-word-001", category: .basics),
            ContentItem.fixture(id: "basics-word-002", category: .basics),
        ]
        let route = ReviewSessionRoute.courseBrowse(category: .basics, startContentID: "basics-word-002")
        viewModel.loadSession(route: route, appState: appState)

        XCTAssertEqual(viewModel.cursor, 1)
        XCTAssertEqual(viewModel.currentItem?.id, "basics-word-002")
        XCTAssertFalse(viewModel.hasNext, "hasNext must be false at last card")

        // Calling goToNext at last card in browse mode must keep cursor at last card
        viewModel.goToNext()
        XCTAssertEqual(viewModel.cursor, 1, "Cursor must remain at last card in course browse mode")
        XCTAssertEqual(viewModel.currentItem?.id, "basics-word-002", "currentItem must remain last item in course browse mode")
    }
    func testFavoriteBrowseUsesFavoriteOrderStartsSelectedAndWritesNoLogOrDraft() throws {
        appState.contentItems = [ContentItem.fixture(id: "old"), ContentItem.fixture(id: "selected"), ContentItem.fixture(id: "new")]
        let now = Date()
        viewModel.loadSession(
            route: .favoriteBrowse(startContentID: "selected"),
            appState: appState,
            favoriteSnapshotsLoader: { _ in [
                FavoriteSnapshot(contentID: "old", favoritedAt: now.addingTimeInterval(-2)),
                FavoriteSnapshot(contentID: "selected", favoritedAt: now.addingTimeInterval(-1)),
                FavoriteSnapshot(contentID: "new", favoritedAt: now)
            ] }
        )
        XCTAssertEqual(viewModel.queue.map(\.contentID), ["new", "selected", "old"])
        XCTAssertEqual(viewModel.currentItem?.id, "selected")
        viewModel.rate("good", appState: appState)
        viewModel.goBack(appState: appState)
        XCTAssertTrue(try store.allLogs().isEmpty)
        XCTAssertNil(try store.restoreDraft())
    }

}
