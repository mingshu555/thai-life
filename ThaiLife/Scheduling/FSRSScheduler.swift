import Foundation
// FSRS sources embedded at ThaiLife/FSRS/

/// Wraps open-spaced-repetition/swift-fsrs (6.x) for Thai Life.
/// Replays immutable ReviewLogRecord history to compute per-card scheduling state.
enum FSRSScheduler {

    /// FSRS-6 defaults with a caller-provided target retention.
    static func defaultParameters(desiredRetention: Double = 0.90) -> FSRSParameters {
        FSRSParameters(
            requestRetention: desiredRetention,
            maximumInterval: 36500.0,
            w: FSRSDefaults.defaultWv6
        )
    }

    /// Computed scheduling info for a single card after replay.
    struct CardSchedulingInfo {
        let contentID: String
        let state: StudyCardState
        let due: Date
        let stability: Double
        let difficulty: Double
        let elapsedDays: Double
        let reps: Int
        let lapses: Int
    }

    // MARK: - Replay

    /// Replay all review logs to compute the current scheduling state for every card.
    /// - Parameters:
    ///   - logs: All review logs, sorted by (reviewedAt, id) for determinism
    ///   - contentIDs: All content IDs that can be scheduled
    ///   - now: Current date/time
    ///   - parameters: FSRS-6 parameters
    /// - Returns: Dictionary mapping contentID → CardSchedulingInfo
    static func replay(
        logs: [ReviewLogRecord],
        contentIDs: [String],
        now: Date,
        parameters: FSRSParameters? = nil
    ) -> [String: CardSchedulingInfo] {
        let params = parameters ?? defaultParameters()
        let fsrs = FSRS(parameters: params)
        let calendar = Calendar.current

        // Sort logs deterministically: reviewedAt asc, then UUID asc
        let sortedLogs = logs.sorted { a, b in
            if a.reviewedAt != b.reviewedAt {
                return a.reviewedAt < b.reviewedAt
            }
            return a.id < b.id
        }

        // Group by contentID (preserving sorted order within each group)
        var groupedLogs: [String: [ReviewLogRecord]] = [:]
        for log in sortedLogs {
            groupedLogs[log.contentID, default: []].append(log)
        }

        var cardStates: [String: CardSchedulingInfo] = [:]

        for contentID in contentIDs {
            let cardLogs = groupedLogs[contentID] ?? []

            if cardLogs.isEmpty {
                // New card — never reviewed
                cardStates[contentID] = CardSchedulingInfo(
                    contentID: contentID,
                    state: .new,
                    due: now,
                    stability: 0,
                    difficulty: 0,
                    elapsedDays: 0,
                    reps: 0,
                    lapses: 0
                )
                continue
            }

            // Replay each review through the FSRS scheduler
            var card = FSRSDefaults().createEmptyCard(now: now)
            var lastReviewDate: Date?

            for log in cardLogs {
                guard let rating = mapToFSRSRating(log.rating) else { continue }
                let reviewDate = log.reviewedAt

                do {
                    let item = try fsrs.next(card: card, now: reviewDate, grade: rating)
                    card = item.card
                } catch {
                    // On error, keep previous card state
                }
                lastReviewDate = reviewDate
            }

            // Compute elapsed days since last review
            let elapsedSinceLast = lastReviewDate.map {
                max(0, Double(calendar.dateComponents([.day], from: $0, to: now).day ?? 0))
            } ?? 0

            let studyState: StudyCardState = {
                switch card.state {
                case .new: return .new
                case .learning: return .learning
                case .review:
                    return card.due <= now ? .review : .review
                case .relearning: return .relearning
                }
            }()

            cardStates[contentID] = CardSchedulingInfo(
                contentID: contentID,
                state: studyState,
                due: card.due,
                stability: card.stability,
                difficulty: card.difficulty,
                elapsedDays: elapsedSinceLast,
                reps: card.reps,
                lapses: card.lapses
            )
        }

        return cardStates
    }

    // MARK: - Single-card schedule

    /// Schedule the next review for a card given a rating.
    static func schedule(
        card: Card,
        rating: Rating,
        now: Date,
        parameters: FSRSParameters? = nil,
        desiredRetention: Double = 0.90
    ) -> CardSchedulingInfo {
        let params = parameters ?? defaultParameters(desiredRetention: desiredRetention)
        let fsrs = FSRS(parameters: params)

        do {
            let item = try fsrs.next(card: card, now: now, grade: rating)
            let nextCard = item.card
            return CardSchedulingInfo(
                contentID: "",
                state: rating == .again ? .relearning : .review,
                due: nextCard.due,
                stability: nextCard.stability,
                difficulty: nextCard.difficulty,
                elapsedDays: 0,
                reps: nextCard.reps,
                lapses: nextCard.lapses
            )
        } catch {
            return CardSchedulingInfo(
                contentID: "",
                state: .new,
                due: now,
                stability: 0,
                difficulty: 0,
                elapsedDays: 0,
                reps: 0,
                lapses: 0
            )
        }
    }

    // MARK: - Helpers

    private static func mapToFSRSRating(_ rating: String) -> Rating? {
        switch rating {
        case "again": return .again
        case "hard": return .hard
        case "good": return .good
        case "easy": return .easy
        default: return nil
        }
    }
}
