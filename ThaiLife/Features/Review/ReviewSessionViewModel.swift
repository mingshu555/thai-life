import Foundation
import SwiftUI

@MainActor
final class ReviewSessionViewModel: ObservableObject {
    @Published var queue: [StudyQueueBuilder.QueueItem] = []
    @Published var cursor: Int = 0
    @Published var isFlipped: Bool = false
    @Published var currentItem: ContentItem?
    @Published var currentDirection: String = "thai→zh"
    @Published var isCurrentContinuation: Bool = false
    @Published var continuationPart: Int = 0
    @Published var loadError: String?

    private var items: [ContentItem] = []
    private var cardStates: [String: FSRSScheduler.CardSchedulingInfo] = [:]
    private var allLogs: [ReviewLogRecord] = []
    private var sessionStartTime = Date()
    private var cardStartTime = Date()
    private var currentRoute: ReviewSessionRoute = .daily

    func loadSession(
        route: ReviewSessionRoute,
        appState: AppState,
        favoriteIDsLoader: @MainActor (StudyStore) throws -> [String] = { try $0.allFavoriteIDs() },
        favoriteSnapshotsLoader: @MainActor (StudyStore) throws -> [FavoriteSnapshot] = { try $0.allFavorites() }
    ) {
        loadError = nil
        currentRoute = route
        items = appState.contentItems

        if case .courseBrowse(let category, let startContentID) = route {
            let categoryItems = items.filter { $0.category == category }
            guard !categoryItems.isEmpty,
                  let startIndex = categoryItems.firstIndex(where: { $0.id == startContentID }) else {
                self.queue = []
                self.cursor = 0
                self.currentItem = nil
                return
            }
            let now = Date()
            self.queue = categoryItems.map { item in
                StudyQueueBuilder.QueueItem(
                    id: item.id,
                    contentID: item.id,
                    state: .new,
                    due: now,
                    reason: "browse"
                )
            }
            self.cursor = startIndex
            updateCurrentItem()
            return
        }

        guard let store = appState.store else {
            loadError = "学习数据服务暂不可用"
            queue = []
            cursor = 0
            currentItem = nil
            return
        }

        if case .favoriteBrowse(let startContentID) = route {
            do {
                let favoriteItems = FavoriteListPresentation.orderedEntries(records: try favoriteSnapshotsLoader(store), content: items).compactMap(\.content)
                guard let startIndex = favoriteItems.firstIndex(where: { $0.id == startContentID }) else {
                    queue = []; cursor = 0; currentItem = nil; return
                }
                let now = Date()
                queue = favoriteItems.map { item in
                    StudyQueueBuilder.QueueItem(id: item.id, contentID: item.id, state: .new, due: now, reason: "browse")
                }
                cursor = startIndex
                updateCurrentItem()
            } catch {
                loadError = error.localizedDescription; queue = []; cursor = 0; currentItem = nil
            }
            return
        }

        do {
            let logs = try store.allLogs()
            allLogs = logs
            let now = Date()
            let contentIDs = items.map(\.id)
            let settings = try store.settings()
            let fsrsParameters = FSRSScheduler.defaultParameters(desiredRetention: settings.desiredRetention)

            cardStates = FSRSScheduler.replay(
                logs: logs,
                contentIDs: contentIDs,
                now: now,
                parameters: fsrsParameters
            )

            let calendar = Calendar.current
            let canRestoreDraft: (SessionDraftRecord) -> Bool = { draft in
                guard route.acceptsDraftSource(draft.source), !draft.queueIDs.isEmpty else { return false }
                if route == .daily {
                    return calendar.isDate(draft.updatedAt, inSameDayAs: now)
                }
                return true
            }
            if route != .favorites,
               let draft = try store.restoreDraft(),
               canRestoreDraft(draft) {
                let draftItems = draft.queueIDs.compactMap { id in items.first(where: { $0.id == id }) }
                if !draftItems.isEmpty {
                    self.queue = draft.queueIDs.compactMap { contentID in
                        guard items.contains(where: { $0.id == contentID }) else { return nil }
                        let state = cardStates[contentID]
                        return StudyQueueBuilder.QueueItem(
                            id: contentID, contentID: contentID,
                            state: state?.state ?? .new,
                            due: state?.due ?? now,
                            reason: state?.state == .review && (state?.due ?? now) <= now ? "due" : "new"
                        )
                    }
                    self.cursor = draft.cursor
                    updateCurrentItem()
                    return
                }
            }

            let routeContentIDs: Set<String>?
            let policy: StudyQueueBuilder.QueuePolicy
            switch route {
            case .daily:
                routeContentIDs = nil
                policy = .scheduled
            case .unit(let catRaw):
                let catItems = items.filter { $0.category.rawValue == catRaw }
                routeContentIDs = Set(catItems.map(\.id))
                policy = .scheduled
            case .weakness:
                var weakIDs = Set<String>()
                for item in items {
                    if let weakest = StudyQueueBuilder.weakestDirection(for: item.id, logs: logs),
                       weakest != "" {
                        let itemLogs = logs.filter { $0.contentID == item.id && $0.direction == weakest }
                        let againCount = itemLogs.filter { $0.rating == "again" }.count
                        if itemLogs.count >= 3 && Double(againCount) / Double(itemLogs.count) > 0.25 {
                            weakIDs.insert(item.id)
                        }
                    }
                }
                routeContentIDs = weakIDs
                policy = .scheduled
            case .favorites:
                routeContentIDs = Set(try favoriteIDsLoader(store))
                policy = .favorites
            case .confusedPairs(let ids):
                routeContentIDs = Set(ids)
                policy = .scheduled
            case .courseBrowse(let category, _):
                let catItems = items.filter { $0.category == category }
                routeContentIDs = Set(catItems.map(\.id))
                policy = .scheduled
            case .favoriteBrowse:
                routeContentIDs = []
                policy = .scheduled
            }

            if let rids = routeContentIDs, rids.isEmpty {
                self.queue = []
                self.cursor = 0
                updateCurrentItem()
                return
            }

            let baseSettings = StudyQueueBuilder.QueueSettings(userSettings: settings)
            let queueItems: [StudyQueueBuilder.QueueItem]
            if route == .daily {
                queueItems = StudyQueueBuilder.makeDailyPlan(
                    now: now,
                    content: items,
                    cardStates: cardStates,
                    logs: logs,
                    settings: baseSettings
                ).queue
            } else {
                queueItems = StudyQueueBuilder.makeQueue(
                    now: now,
                    content: items,
                    cardStates: cardStates,
                    logs: logs,
                    settings: baseSettings,
                    policy: policy,
                    routeContentIDs: routeContentIDs
                )
            }

            self.queue = queueItems
            self.cursor = 0
            updateCurrentItem()
        } catch {
            loadError = error.localizedDescription
            queue = []
            cursor = 0
            currentItem = nil
        }
    }

    var hasPrevious: Bool {
        cursor > 0
    }

    var hasNext: Bool {
        cursor < queue.count - 1
    }

    func goToPrevious() {
        guard cursor > 0 else { return }
        isFlipped = false
        cursor -= 1
        updateCurrentItem()
        cardStartTime = Date()
    }

    func goToNext() {
        guard cursor < queue.count else { return }
        if currentRoute.isCardBrowser {
            if cursor < queue.count - 1 {
                isFlipped = false
                cursor += 1
                updateCurrentItem()
                cardStartTime = Date()
            }
            return
        }
        isFlipped = false
        cursor += 1
        if cursor >= queue.count {
            currentItem = nil
        } else {
            updateCurrentItem()
            cardStartTime = Date()
        }
    }

    func flip() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isFlipped.toggle()
        }
    }

    func rate(_ rating: String, appState: AppState) {
        guard !currentRoute.isCardBrowser, let store = appState.store, let item = currentItem else { return }
        // Continuation cards: auto-advance without creating review log
        if isCurrentContinuation {
            advanceToNext(store: store)
            return
        }

        let responseTime = Date().timeIntervalSince(cardStartTime)
        let direction = determineDirection(for: item)

        let log = ReviewLogRecord(
            id: UUID().uuidString,
            contentID: item.id,
            direction: direction,
            rating: rating,
            reviewedAt: Date(),
            responseSeconds: responseTime
        )

        try? store.appendReview(log)

        isFlipped = false
        cursor += 1

        if cursor >= queue.count {
            try? store.clearDraft()
            queue = []
            currentItem = nil
        } else {
            updateCurrentItem()
            cardStartTime = Date()
        }
    }

    func goBack(appState: AppState) {
        guard !currentRoute.isCardBrowser, let store = appState.store else { return }
        let queueIDs = queue.map(\.contentID)
        if let source = currentRoute.draftSource {
            try? store.saveDraft(queueIDs: queueIDs, cursor: cursor, source: source)
        }
    }

    func playAudio(appState: AppState) {
        guard let item = currentItem else { return }
        _ = appState.audioService.play(audioID: item.audioID, thaiText: item.thai)
    }

    func playSegment(_ segment: PhraseSegment, appState: AppState) {
        _ = appState.audioService.playSegment(segment)
    }

    func playExampleAudio(appState: AppState) {
        guard let item = currentItem,
              let example = item.example,
              !example.isEmpty else { return }
        _ = appState.audioService.playSentence(audioID: item.audioID + "-example", text: example)
    }

    private func advanceToNext(store: StudyStore) {
        isFlipped = false
        cursor += 1
        if cursor >= queue.count {
            try? store.clearDraft()
            // Don't clear queue/currentItem here — let the view detect completion
            // Set cursor past end so view knows session is done
            currentItem = nil
        } else {
            updateCurrentItem()
            cardStartTime = Date()
        }
    }

    private func updateCurrentItem() {
        guard cursor < queue.count else {
            currentItem = nil
            return
        }
        let qi = queue[cursor]
        currentItem = items.first(where: { $0.id == qi.contentID })
        isCurrentContinuation = qi.reason == "continuation"
        // Determine which part: look back to count previous continuations of same contentID
        if isCurrentContinuation {
            var part = 1
            var idx = cursor - 1
            while idx >= 0 && queue[idx].contentID == qi.contentID {
                if queue[idx].reason == "continuation" { part += 1 }
                else { break }
                idx -= 1
            }
            continuationPart = part
        } else {
            continuationPart = 0
        }
        if let item = currentItem {
            currentDirection = determineDirection(for: item)
        }
        cardStartTime = Date()
    }

    private func determineDirection(for item: ContentItem) -> String {
        // Use weakest direction from StudyQueueBuilder
        if let weakest = StudyQueueBuilder.weakestDirection(for: item.id, logs: allLogs) {
            return weakest
        }
        let cardLogs = allLogs.filter { $0.contentID == item.id }
        let lastDirection = cardLogs.last?.direction
        if lastDirection == "thai→zh" { return "zh→thai" }
        return "thai→zh"
    }
}
