import Foundation
import SwiftData

@MainActor
final class StudyStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// All SwiftData model types for the schema.
    static var modelTypes: [any PersistentModel.Type] {
        [ReviewLogRecord.self, FavoriteRecord.self, SessionDraftRecord.self, UserSettingsRecord.self]
    }

    // MARK: - Review Logs

    func appendReview(_ review: ReviewLogRecord) throws {
        // Deduplicate by ID
        let existing = try fetchReview(byID: review.id)
        if existing != nil { return }
        context.insert(review)
        try context.save()
    }

    func logs(for contentID: String) throws -> [ReviewLogRecord] {
        let predicate = #Predicate<ReviewLogRecord> { $0.contentID == contentID }
        let descriptor = FetchDescriptor<ReviewLogRecord>(predicate: predicate, sortBy: [SortDescriptor(\.reviewedAt), SortDescriptor(\.id)])
        return try context.fetch(descriptor)
    }

    func allLogs() throws -> [ReviewLogRecord] {
        let descriptor = FetchDescriptor<ReviewLogRecord>(sortBy: [SortDescriptor(\.reviewedAt), SortDescriptor(\.id)])
        return try context.fetch(descriptor)
    }

    private func fetchReview(byID id: String) throws -> ReviewLogRecord? {
        let predicate = #Predicate<ReviewLogRecord> { $0.id == id }
        let descriptor = FetchDescriptor<ReviewLogRecord>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    // MARK: - Favorites

    func toggleFavorite(contentID: String) throws {
        let predicate = #Predicate<FavoriteRecord> { $0.contentID == contentID }
        let descriptor = FetchDescriptor<FavoriteRecord>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
        } else {
            context.insert(FavoriteRecord(contentID: contentID))
        }
        try context.save()
    }

    func isFavorite(contentID: String) throws -> Bool {
        let predicate = #Predicate<FavoriteRecord> { $0.contentID == contentID }
        let descriptor = FetchDescriptor<FavoriteRecord>(predicate: predicate)
        return try context.fetch(descriptor).first != nil
    }

    func allFavorites() throws -> [FavoriteSnapshot] {
        let descriptor = FetchDescriptor<FavoriteRecord>(sortBy: [
            SortDescriptor(\.favoritedAt, order: .reverse),
            SortDescriptor(\.contentID)
        ])
        return try context.fetch(descriptor).map { FavoriteSnapshot(contentID: $0.contentID, favoritedAt: $0.favoritedAt) }
    }

    func allFavoriteIDs() throws -> [String] {
        try allFavorites().map(\.contentID)
    }

    // MARK: - Session Draft

    func saveDraft(queueIDs: [String], cursor: Int, source: String) throws {
        let id = "session-draft"
        let predicate = #Predicate<SessionDraftRecord> { $0.id == id }
        let descriptor = FetchDescriptor<SessionDraftRecord>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.queueIDs = queueIDs
            existing.cursor = cursor
            existing.source = source
            existing.updatedAt = Date()
        } else {
            context.insert(SessionDraftRecord(id: id, queueIDs: queueIDs, cursor: cursor, source: source))
        }
        try context.save()
    }

    func restoreDraft() throws -> SessionDraftRecord? {
        let predicate = #Predicate<SessionDraftRecord> { $0.id == "session-draft" }
        let descriptor = FetchDescriptor<SessionDraftRecord>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    func clearDraft() throws {
        let predicate = #Predicate<SessionDraftRecord> { $0.id == "session-draft" }
        let descriptor = FetchDescriptor<SessionDraftRecord>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    // MARK: - Settings

    func settings() throws -> UserSettingsRecord {
        let predicate = #Predicate<UserSettingsRecord> { $0.id == "user-settings" }
        let descriptor = FetchDescriptor<UserSettingsRecord>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let defaults = UserSettingsRecord()
        context.insert(defaults)
        try context.save()
        return defaults
    }

    func updateSettings(desiredRetention: Double? = nil, slowPlaybackEnabled: Bool? = nil, dailyNewLimitOverride: Int?? = nil) throws {
        let s = try settings()
        if let dr = desiredRetention { s.desiredRetention = dr }
        if let sp = slowPlaybackEnabled { s.slowPlaybackEnabled = sp }
        if let dl = dailyNewLimitOverride { s.dailyNewLimitOverride = dl }
        try context.save()
    }
}
