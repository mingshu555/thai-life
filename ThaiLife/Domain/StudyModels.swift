import Foundation
import SwiftData

// MARK: - Review Log Record

@Model
final class ReviewLogRecord {
    var id: String = ""          // UUID string
    var contentID: String = ""
    var direction: String = ""   // "thai→zh", "zh→thai"
    var rating: String = ""      // "again", "hard", "good", "easy"
    var reviewedAt: Date = Date()
    var responseSeconds: Double = 0
    var schemaVersion: Int = 1

    init(
        id: String = UUID().uuidString,
        contentID: String,
        direction: String,
        rating: String,
        reviewedAt: Date = Date(),
        responseSeconds: Double = 0,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.contentID = contentID
        self.direction = direction
        self.rating = rating
        self.reviewedAt = reviewedAt
        self.responseSeconds = responseSeconds
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Favorite Record

struct FavoriteSnapshot: Identifiable, Equatable, Sendable {
    let contentID: String
    let favoritedAt: Date
    var id: String { contentID }
}

@Model
final class FavoriteRecord {
    var contentID: String = ""
    var favoritedAt: Date = Date()

    init(contentID: String, favoritedAt: Date = Date()) {
        self.contentID = contentID
        self.favoritedAt = favoritedAt
    }
}

// MARK: - Session Draft Record

@Model
final class SessionDraftRecord {
    var id: String = ""          // UUID string, one draft total
    var queueIDs: [String] = []  // Ordered content IDs in queue
    var cursor: Int = 0         // Current position in queue
    var source: String = ""      // "daily", "unit:<unitID>", "weakness", "favorites"
    var updatedAt: Date = Date()

    init(
        id: String = "session-draft",
        queueIDs: [String] = [],
        cursor: Int = 0,
        source: String = "daily",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.queueIDs = queueIDs
        self.cursor = cursor
        self.source = source
        self.updatedAt = updatedAt
    }
}

// MARK: - User Settings Record

@Model
final class UserSettingsRecord {
    var id: String = ""          // singleton: "user-settings"
    var desiredRetention: Double = 0.90
    var slowPlaybackEnabled: Bool = false
    var dailyNewLimitOverride: Int? = nil

    init(
        id: String = "user-settings",
        desiredRetention: Double = 0.90,
        slowPlaybackEnabled: Bool = false,
        dailyNewLimitOverride: Int? = nil
    ) {
        self.id = id
        self.desiredRetention = desiredRetention
        self.slowPlaybackEnabled = slowPlaybackEnabled
        self.dailyNewLimitOverride = dailyNewLimitOverride
    }
}

// MARK: - Transient scheduling types (computed from logs; CardState/Rating come from swift-fsrs)

/// String-based state for persistence/serialization boundary
enum StudyCardState: String, Codable, Sendable {
    case new, learning, review, relearning
}

struct ScheduledCard: Identifiable, Sendable {
    let id: String
    let contentID: String
    let due: Date
    let state: StudyCardState

    init(contentID: String, due: Date, state: StudyCardState) {
        self.id = contentID
        self.contentID = contentID
        self.due = due
        self.state = state
    }
}
