import Foundation
import SwiftUI

@MainActor
final class TodayViewModel: ObservableObject {
    struct TodaySnapshot {
        var dueCount: Int = 0
        var newLimit: Int = 0
        var estimatedMinutes: Int = 0
        var targetRetention: Double = 0.90
        var weakDirections: [String] = []
        var confusedPairs: [String] = []

        static let empty = TodaySnapshot()
    }

    @Published var snapshot = TodaySnapshot.empty
    @Published var showReview = false
    @Published var reviewRoute: ReviewSessionRoute = .daily

    private var cardStates: [String: FSRSScheduler.CardSchedulingInfo] = [:]

    func refresh(appState: AppState) {
        guard let store = appState.store else { return }

        do {
            let logs = try store.allLogs()
            let settings = try store.settings()
            let now = Date()
            let items = appState.contentItems

            cardStates = FSRSScheduler.replay(
                logs: logs,
                contentIDs: items.map(\.id),
                now: now,
                parameters: FSRSScheduler.defaultParameters(desiredRetention: settings.desiredRetention)
            )

            let queueSettings = StudyQueueBuilder.QueueSettings(userSettings: settings)
            let plan = StudyQueueBuilder.makeDailyPlan(
                now: now,
                content: items,
                cardStates: cardStates,
                logs: logs,
                settings: queueSettings
            )
            let averageResponseSeconds = logs
                .map(\.responseSeconds)
                .filter { $0 > 0 && $0.isFinite }
                .reduce(into: (total: 0.0, count: 0)) { result, seconds in
                    result.total += seconds
                    result.count += 1
                }
            let secondsPerCard = averageResponseSeconds.count > 0
                ? averageResponseSeconds.total / Double(averageResponseSeconds.count)
                : 15.0
            let estimatedSeconds = Double(plan.queue.count) * secondsPerCard
            let estimatedMinutes = max(1, Int(ceil(estimatedSeconds / 60.0)))

            // Weak direction detection
            var directionStats: [String: (total: Int, again: Int)] = [:]
            for log in logs {
                var s = directionStats[log.direction] ?? (0, 0)
                s.total += 1
                if log.rating == "again" { s.again += 1 }
                directionStats[log.direction] = s
            }
            var weakDirections: [String] = []
            let dirNames = ["thai→zh": "泰→中", "zh→thai": "中→泰"]
            for (dir, name) in dirNames {
                if let s = directionStats[dir], s.total >= 3 {
                    let rate = Double(s.again) / Double(s.total)
                    if rate > 0.25 { weakDirections.append(name) }
                }
            }

            snapshot = TodaySnapshot(
                dueCount: plan.dueCount,
                newLimit: plan.newLimit,
                estimatedMinutes: estimatedMinutes,
                targetRetention: settings.desiredRetention,
                weakDirections: weakDirections,
                confusedPairs: []
            )
        } catch {
            snapshot = .empty
        }
    }

    func startReview() {
        reviewRoute = .daily
        showReview = true
    }

    func startWeaknessReview() {
        reviewRoute = .weakness
        showReview = true
    }
}
