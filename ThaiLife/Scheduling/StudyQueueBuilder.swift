import Foundation

/// Builds the daily study queue respecting FSRS scheduling, prerequisites,
/// category interleaving, related-item spacing, and backlog management.
enum StudyQueueBuilder {
    enum QueuePolicy: Equatable {
        case scheduled
        case favorites
    }

    struct QueueSettings {
        let dailyNewLimit: Int
        let backlogThreshold: Int
        let desiredRetention: Double
        let maxCardsPerSession: Int

        static let `default` = QueueSettings(
            dailyNewLimit: 10,
            backlogThreshold: 50,
            desiredRetention: 0.90,
            maxCardsPerSession: 50
        )

        init(
            dailyNewLimit: Int,
            backlogThreshold: Int,
            desiredRetention: Double,
            maxCardsPerSession: Int
        ) {
            self.dailyNewLimit = dailyNewLimit
            self.backlogThreshold = backlogThreshold
            self.desiredRetention = desiredRetention
            self.maxCardsPerSession = maxCardsPerSession
        }

        init(userSettings: UserSettingsRecord) {
            self.init(
                dailyNewLimit: userSettings.dailyNewLimitOverride ?? Self.default.dailyNewLimit,
                backlogThreshold: Self.default.backlogThreshold,
                desiredRetention: userSettings.desiredRetention,
                maxCardsPerSession: Self.default.maxCardsPerSession
            )
        }
    }

    struct QueueItem: Identifiable {
        let id: String
        let contentID: String
        let state: StudyCardState
        let due: Date
        let reason: String  // "due", "relearning", "new"
        let needsContinuation: Bool

        var isDue: Bool { state == .review && due <= Date() }
        var isNew: Bool { state == .new }

        init(id: String, contentID: String, state: StudyCardState, due: Date, reason: String, needsContinuation: Bool = false) {
            self.id = id
            self.contentID = contentID
            self.state = state
            self.due = due
            self.reason = reason
            self.needsContinuation = needsContinuation
        }
    }

    /// Builds the daily plan from the same queue rules used by the review session.
    /// The plan reports the cards that are actually eligible today, rather than
    /// treating the configured new-card limit as if it were the queue size.
    struct DailyPlan {
        let dueCount: Int
        let eligibleNewCount: Int
        let newLimit: Int
        let queue: [QueueItem]
    }

    static func makeDailyPlan(
        now: Date,
        content: [ContentItem],
        cardStates: [String: FSRSScheduler.CardSchedulingInfo],
        logs: [ReviewLogRecord],
        settings: QueueSettings = .default
    ) -> DailyPlan {
        let unlimitedSettings = QueueSettings(
            dailyNewLimit: Int.max,
            backlogThreshold: settings.backlogThreshold,
            desiredRetention: settings.desiredRetention,
            maxCardsPerSession: Int.max
        )
        let dueQueue = makeQueue(
            now: now, content: content, cardStates: cardStates, logs: logs,
            settings: QueueSettings(
                dailyNewLimit: 0,
                backlogThreshold: settings.backlogThreshold,
                desiredRetention: settings.desiredRetention,
                maxCardsPerSession: Int.max
            )
        )
        let dueCount = dueQueue.filter { $0.reason == "due" || $0.reason == "relearning" }.count
        let eligibleNewCount = makeQueue(
            now: now, content: content, cardStates: cardStates, logs: logs,
            settings: unlimitedSettings
        ).filter { $0.reason == "new" }.count
        let remainingQuota = max(0, settings.dailyNewLimit - newCardsStudiedToday(logs: logs, now: now))
        let newLimit = dueCount >= settings.backlogThreshold
            ? 0
            : min(remainingQuota, eligibleNewCount)
        let queue = makeQueue(
            now: now, content: content, cardStates: cardStates, logs: logs,
            settings: QueueSettings(
                dailyNewLimit: newLimit,
                backlogThreshold: settings.backlogThreshold,
                desiredRetention: settings.desiredRetention,
                maxCardsPerSession: settings.maxCardsPerSession
            )
        )
        return DailyPlan(
            dueCount: dueCount,
            eligibleNewCount: eligibleNewCount,
            newLimit: newLimit,
            queue: queue
        )
    }

    /// Number of cards whose first review happened on the current calendar day.
    /// This makes the daily new-card limit a real day-based quota without adding
    /// another mutable counter that could drift from the review log.
    static func newCardsStudiedToday(logs: [ReviewLogRecord], now: Date, calendar: Calendar = .current) -> Int {
        let startOfDay = calendar.startOfDay(for: now)
        let firstReviewByCard = Dictionary(grouping: logs, by: \.contentID).compactMapValues { cardLogs in
            cardLogs.map(\.reviewedAt).min()
        }
        return firstReviewByCard.values.filter { calendar.isDate($0, inSameDayAs: startOfDay) }.count
    }

    /// Build study queue from content items + replay state.
    static func makeQueue(
        now: Date,
        content: [ContentItem],
        cardStates: [String: FSRSScheduler.CardSchedulingInfo],
        logs: [ReviewLogRecord],
        settings: QueueSettings = .default,
        policy: QueuePolicy = .scheduled,
        routeContentIDs: Set<String>? = nil
    ) -> [QueueItem] {
        let contentMap = Dictionary(uniqueKeysWithValues: content.map { ($0.id, $0) })
        let reviewedIDs = Set(logs.map(\.contentID))

        // Filter to route-specific content if provided (for weakness/favorites/unit routes)
        let applicableIDs: Set<String> = routeContentIDs ?? Set(content.map(\.id))

        // Partition items
        var dueCards: [QueueItem] = []
        var relearningCards: [QueueItem] = []
        var newCards: [QueueItem] = []

        for item in content {
            guard applicableIDs.contains(item.id) else { continue }

            let stateInfo = cardStates[item.id] ?? FSRSScheduler.CardSchedulingInfo(
                contentID: item.id, state: .new, due: now,
                stability: 0, difficulty: 0, elapsedDays: 0, reps: 0, lapses: 0
            )

            if policy == .scheduled,
               (stateInfo.state == .review || stateInfo.state == .learning || stateInfo.state == .relearning),
               stateInfo.due > now {
                continue
            }

            if policy == .scheduled,
               !arePrerequisitesMet(item: item, reviewedIDs: reviewedIDs, cardStates: cardStates) {
                continue
            }

            // Separate related items: ensure minimum spacing
            switch stateInfo.state {
            case .review:
                dueCards.append(QueueItem(id: item.id, contentID: item.id, state: .review, due: stateInfo.due, reason: "due"))
            case .relearning:
                relearningCards.append(QueueItem(id: item.id, contentID: item.id, state: .relearning, due: stateInfo.due, reason: "relearning"))
            case .new:
                newCards.append(QueueItem(id: item.id, contentID: item.id, state: .new, due: now, reason: "new"))
            case .learning:
                relearningCards.append(QueueItem(id: item.id, contentID: item.id, state: .relearning, due: stateInfo.due, reason: "relearning"))
            }
        }

        // Backlog management
        let effectiveNewLimit = dueCards.count >= settings.backlogThreshold ? 0 : settings.dailyNewLimit

        // Sort due cards by due date (oldest first = most overdue)
        dueCards.sort { $0.due < $1.due }
        relearningCards.sort { $0.due < $1.due }

        let limitedNew = policy == .favorites
            ? newCards.shuffled()
            : Array(newCards.shuffled().prefix(effectiveNewLimit))
        // Build final queue: due → relearning → new (with category interleaving)
        var interleaved: [QueueItem] = []
        interleaved.append(contentsOf: dueCards)
        interleaved.append(contentsOf: relearningCards)

        // Interleave new cards avoiding adjacent same-category and related items
        if !limitedNew.isEmpty {
            var remaining = limitedNew
            var lastCategory: ContentCategory?
            var lastRelated: Set<String> = []

            while !remaining.isEmpty {
                // Find best next card: different category, not recently related
                if let idx = remaining.firstIndex(where: { card in
                    let cat = contentMap[card.contentID]?.category
                    let rels = Set(contentMap[card.contentID]?.relatedIDs ?? [])
                    return cat != lastCategory && rels.isDisjoint(with: lastRelated)
                }) {
                    let card = remaining.remove(at: idx)
                    interleaved.append(card)
                    lastCategory = contentMap[card.contentID]?.category
                    lastRelated = Set(contentMap[card.contentID]?.relatedIDs ?? [])
                } else if let idx = remaining.firstIndex(where: { card in
                    contentMap[card.contentID]?.category != lastCategory
                }) {
                    let card = remaining.remove(at: idx)
                    interleaved.append(card)
                    lastCategory = contentMap[card.contentID]?.category
                    lastRelated = Set(contentMap[card.contentID]?.relatedIDs ?? [])
                } else {
                    // Fallback: just append remaining
                    interleaved.append(contentsOf: remaining)
                    remaining.removeAll()
                }
            }
        }

        // Cap at maxCardsPerSession
        if interleaved.count > settings.maxCardsPerSession {
            interleaved = Array(interleaved.prefix(settings.maxCardsPerSession))
        }

        // Insert continuation cards for dialogue items (one per turn beyond first)
        var withCont: [QueueItem] = []
        for qi in interleaved {
            let ci = contentMap[qi.contentID]
            let needsCont = ci?.kind == .dialogue
            withCont.append(QueueItem(
                id: qi.id, contentID: qi.contentID, state: qi.state,
                due: qi.due, reason: qi.reason, needsContinuation: needsCont
            ))
            if needsCont, let dialogue = ci {
                // Count dialogue turns and add continuation for each beyond first
                let turns = dialogue.thai.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                for turnIdx in 1..<turns.count {
                    withCont.append(QueueItem(
                        id: "\(qi.id)-cont\(turnIdx)", contentID: qi.contentID, state: qi.state,
                        due: qi.due, reason: "continuation", needsContinuation: false
                    ))
                }
            }
        }
        return withCont
    }

    /// Weakest direction detection: find the direction with highest "again" rate for a content ID.
    static func weakestDirection(for contentID: String, logs: [ReviewLogRecord]) -> String? {
        let cardLogs = logs.filter { $0.contentID == contentID }
        guard !cardLogs.isEmpty else { return nil }

        var stats: [String: (total: Int, again: Int)] = [:]
        for log in cardLogs {
            var s = stats[log.direction] ?? (0, 0)
            s.total += 1
            if log.rating == "again" { s.again += 1 }
            stats[log.direction] = s
        }

        let allDirections = ["thai→zh", "zh→thai"]
        var worst: String?
        var worstRate = -1.0

        for dir in allDirections {
            if let s = stats[dir], s.total > 0 {
                let rate = Double(s.again) / Double(s.total)
                if rate > worstRate {
                    worstRate = rate
                    worst = dir
                }
            } else {
                // Untested direction = weakest
                if worstRate < 0 {
                    worst = dir
                    worstRate = 0
                }
            }
        }

        return worst
    }

    // MARK: - Private

    private static func arePrerequisitesMet(
        item: ContentItem,
        reviewedIDs: Set<String>,
        cardStates: [String: FSRSScheduler.CardSchedulingInfo]
    ) -> Bool {
        for preID in item.prerequisiteIDs {
            guard reviewedIDs.contains(preID) else { return false }
            if let state = cardStates[preID], state.state == .relearning {
                return false
            }
        }
        return true
    }
}
