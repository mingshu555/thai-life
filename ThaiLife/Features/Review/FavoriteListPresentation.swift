import Foundation

enum FavoriteListEntryKind: Equatable {
    case content(ContentItem)
    case menu(ThaiMenuCard)
}

struct FavoriteListEntry: Identifiable, Equatable {
    let kind: FavoriteListEntryKind
    let favoritedAt: Date

    var id: String {
        switch kind {
        case .content(let item): return item.id
        case .menu(let card): return card.id
        }
    }

    var content: ContentItem? {
        if case .content(let item) = kind { return item }
        return nil
    }

    var menuCard: ThaiMenuCard? {
        if case .menu(let card) = kind { return card }
        return nil
    }

    init(content: ContentItem, favoritedAt: Date) {
        self.kind = .content(content)
        self.favoritedAt = favoritedAt
    }

    init(kind: FavoriteListEntryKind, favoritedAt: Date) {
        self.kind = kind
        self.favoritedAt = favoritedAt
    }
}

struct FavoriteDateSection: Identifiable, Equatable {
    let date: Date
    let title: String
    let entries: [FavoriteListEntry]
    var id: Date { date }
}

enum FavoriteListPresentation {
    static func orderedEntries(records: [FavoriteSnapshot], content: [ContentItem], menuCards: [ThaiMenuCard] = []) -> [FavoriteListEntry] {
        let contentByID = Dictionary(uniqueKeysWithValues: content.map { ($0.id, $0) })
        let menuByID = Dictionary(uniqueKeysWithValues: menuCards.map { ($0.id, $0) })

        return records.compactMap { record in
            if let item = contentByID[record.contentID] {
                return FavoriteListEntry(kind: .content(item), favoritedAt: record.favoritedAt)
            } else if let card = menuByID[record.contentID] {
                return FavoriteListEntry(kind: .menu(card), favoritedAt: record.favoritedAt)
            } else {
                return nil
            }
        }.sorted {
            $0.favoritedAt != $1.favoritedAt ? $0.favoritedAt > $1.favoritedAt : $0.id < $1.id
        }
    }

    static func sections(
        records: [FavoriteSnapshot],
        content: [ContentItem],
        menuCards: [ThaiMenuCard] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [FavoriteDateSection] {
        let entries = orderedEntries(records: records, content: content, menuCards: menuCards)
        let groups = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.favoritedAt) }
        return groups.keys.sorted(by: >).map { date in
            FavoriteDateSection(date: date, title: dateTitle(for: date, now: now, calendar: calendar), entries: groups[date] ?? [])
        }
    }

    static func dateTitle(for date: Date, now: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        if calendar.isDate(date, inSameDayAs: now) { formatter.dateFormat = "M月d日"; return "今天 · \(formatter.string(from: date))" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { formatter.dateFormat = "M月d日"; return "昨天 · \(formatter.string(from: date))" }
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

