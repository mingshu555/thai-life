import Foundation
import SwiftUI

struct CategoryMastery: Hashable {
    let category: ContentCategory
    let mastery: Double
}

@MainActor
final class ProgressViewModel: ObservableObject {
    struct ProgressSnapshot {
        var historicalCorrectRate: Double = 0
        var estimatedRecall: Double = 0
        var targetRetention: Double = 0.90
        var dailyLoad: [Int] = []
        var categoryMastery: [CategoryMastery] = []
        var weakDirections: [String] = []
        var confusedPairs: [String] = []
        var confusedPairIDs: [[String]] = []

        static let empty = ProgressSnapshot()
    }

    @Published var snapshot = ProgressSnapshot.empty

    func refresh(appState: AppState) {
        guard let store = appState.store else { return }

        do {
            let logs = try store.allLogs()
            let settings = try store.settings()
            let now = Date()

            // Historical answer rate: non-again ratings / all persisted reviews.
            let total = logs.count
            let failed = logs.filter { $0.rating == "again" }.count
            let historicalCorrectRate = total > 0 ? 1.0 - Double(failed) / Double(total) : 0

            // Compute category mastery from replayed card states
            let cardStates = FSRSScheduler.replay(
                logs: logs,
                contentIDs: appState.contentItems.map(\.id),
                now: now,
                parameters: FSRSScheduler.defaultParameters(desiredRetention: settings.desiredRetention)
            )

            // FSRS estimated recall is the mean retrievability of learned cards.
            // New cards have no stability and are excluded from this metric.
            let fsrs = FSRS(parameters: FSRSScheduler.defaultParameters(desiredRetention: settings.desiredRetention))
            let learnedStates = cardStates.values.filter { $0.reps > 0 && $0.stability > 0 }
            let estimatedRecall: Double
            if learnedStates.isEmpty {
                estimatedRecall = 0
            } else {
                estimatedRecall = learnedStates
                    .map { state in
                        fsrs.forgettingCurve(
                            elapsedDays: state.elapsedDays,
                            stability: state.stability
                        )
                    }
                    .reduce(0, +) / Double(learnedStates.count)
            }

            var catStats: [ContentCategory: (mastered: Int, total: Int)] = [:]
            let itemsByID = Dictionary(uniqueKeysWithValues: appState.contentItems.map { ($0.id, $0) })

            for (cid, state) in cardStates {
                guard let item = itemsByID[cid] else { continue }
                var s = catStats[item.category] ?? (0, 0)
                s.total += 1
                if state.reps > 0 && state.lapses == 0 && state.stability > 1 {
                    s.mastered += 1
                }
                catStats[item.category] = s
            }

            let categoryMastery = ContentCategory.allCases.map { cat in
                let stats = catStats[cat] ?? (0, 0)
                let mastery = stats.total > 0 ? Double(stats.mastered) / Double(stats.total) : 0
                return CategoryMastery(category: cat, mastery: mastery)
            }

            // 30-day load forecast: count cards due each day
            var dailyLoad = Array(repeating: 0, count: 30)
            let cal = Calendar.current
            for (_, state) in cardStates {
                if state.state == .review || state.state == .relearning {
                    let daysUntilDue = cal.dateComponents([.day], from: now, to: state.due).day ?? 999
                    if daysUntilDue >= 0 && daysUntilDue < 30 {
                        dailyLoad[daysUntilDue] += 1
                    }
                }
            }

            // Weak directions from log analysis
            var directionStats: [String: (total: Int, again: Int)] = [:]
            for log in logs {
                var s = directionStats[log.direction] ?? (0, 0)
                s.total += 1
                if log.rating == "again" { s.again += 1 }
                directionStats[log.direction] = s
            }
            var weakDirs: [String] = []
            let dirDisplay = ["thai→zh":"泰→中", "zh→thai":"中→泰"]
            for (dir, display) in dirDisplay {
                if let s = directionStats[dir], s.total >= 3 {
                    if Double(s.again) / Double(s.total) > 0.25 {
                        weakDirs.append(display)
                    }
                }
            }

            // Confused pairs: store (display, [contentIDs])
            let contentIDSet = Set(itemsByID.keys)
            var confusedPairs: [(String, [String])] = []
            for item in appState.contentItems {
                for relID in item.relatedIDs {
                    guard contentIDSet.contains(relID) else { continue }
                    let itemLogs = logs.filter { $0.contentID == item.id }
                    let relLogs = logs.filter { $0.contentID == relID }
                    let itemAgain = Double(itemLogs.filter { $0.rating == "again" }.count) / max(1, Double(itemLogs.count))
                    let relAgain = Double(relLogs.filter { $0.rating == "again" }.count) / max(1, Double(relLogs.count))
                    if itemAgain > 0.3 && relAgain > 0.3 && item.id < relID {
                        let itemName = itemsByID[item.id]?.thai ?? item.id
                        let relName = itemsByID[relID]?.thai ?? relID
                        confusedPairs.append(("\(itemName) ↔ \(relName)", [item.id, relID]))
                    }
                }
            }

            snapshot = ProgressSnapshot(
                historicalCorrectRate: historicalCorrectRate,
                estimatedRecall: estimatedRecall,
                targetRetention: settings.desiredRetention,
                dailyLoad: dailyLoad,
                categoryMastery: categoryMastery,
                weakDirections: weakDirs,
                confusedPairs: confusedPairs.prefix(5).map { $0.0 },
                confusedPairIDs: confusedPairs.prefix(5).map { $0.1 }
            )
        } catch {
            snapshot = .empty
        }
    }
}
