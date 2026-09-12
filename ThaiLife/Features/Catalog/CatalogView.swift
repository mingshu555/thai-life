import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var appState: AppState
    @State private var categoryStats: [ContentCategory: (mastered: Int, total: Int, due: Int)] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: ThaiMenuListView().environmentObject(appState)) {
                        HStack(spacing: 12) {
                            Text("🍽️").font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("泰国常见菜单").font(.headline).foregroundColor(ThaiLifeTheme.deepGreen)
                                Text("一道菜一张卡片 · 背面词语拆解").font(.caption).foregroundColor(ThaiLifeTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink(destination: LooplessSignageReferenceView().environmentObject(appState)) {
                        HStack(spacing: 12) {
                            Text("🔤").font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("泰国招牌无头字对照")
                                    .font(.headline)
                                    .foregroundColor(ThaiLifeTheme.deepGreen)
                                Text("高频字形 · 易混提醒 · 真实场景")
                                    .font(.caption)
                                    .foregroundColor(ThaiLifeTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink(destination: WordFamilyBrowserView()) {
                        HStack(spacing: 12) {
                            Text("🧩")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("词根高频词族卡片")
                                    .font(.headline)
                                    .foregroundColor(ThaiLifeTheme.deepGreen)
                                Text("前缀词根关联（ไม่, น้ำ, รถ, ห้อง...）")
                                    .font(.caption)
                                    .foregroundColor(ThaiLifeTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(ContentRepository.loadWordFamilies().count) 词族")
                                .font(.caption.bold())
                                .foregroundColor(ThaiLifeTheme.deepGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ThaiLifeTheme.paleGreen.opacity(0.3))
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink(destination: UnitDetailView(category: .coreFunction).environmentObject(appState)) {
                        HStack(spacing: 12) {
                            Text("🔑")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("核心功能词")
                                    .font(.headline)
                                    .foregroundColor(ThaiLifeTheme.deepGreen)
                                Text("超高频功能词 · 例句深度拆解")
                                    .font(.caption)
                                    .foregroundColor(ThaiLifeTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(appState.contentItems.filter { $0.category == .coreFunction }.count) 词")
                                .font(.caption.bold())
                                .foregroundColor(ThaiLifeTheme.deepGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ThaiLifeTheme.paleGreen.opacity(0.3))
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("专项扩展")
                }

                Section {
                    ForEach(ContentCategory.classifiedCourseCases, id: \.self) { category in
                        NavigationLink(destination: UnitDetailView(category: category)) {
                            let stats = categoryStats[category] ?? (0, 0, 0)
                            CategoryRow(
                                category: category,
                                mastered: stats.mastered,
                                total: stats.total,
                                due: stats.due
                            )
                        }
                    }
                } header: {
                    Text("分类课程")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("课程")
            .background(ThaiLifeTheme.warmWhite)
            .onAppear { computeStats() }
        }
    }


    private func computeStats() {
        guard let store = appState.store else { return }
        do {
            let logs = try store.allLogs()
            let settings = try store.settings()
            let now = Date()
            let cardStates = FSRSScheduler.replay(
                logs: logs,
                contentIDs: appState.contentItems.map(\.id),
                now: now,
                parameters: FSRSScheduler.defaultParameters(desiredRetention: settings.desiredRetention)
            )
            let itemsByCat = Dictionary(grouping: appState.contentItems, by: \.category)

            var stats: [ContentCategory: (Int, Int, Int)] = [:]
            for (cat, catItems) in itemsByCat {
                let total = catItems.count
                let mastered = catItems.filter { item in
                    if let state = cardStates[item.id] {
                        return state.reps > 0 && state.lapses == 0 && state.stability > 1
                    }
                    return false
                }.count
                let due = catItems.filter { item in
                    if let state = cardStates[item.id] {
                        return (state.state == .review || state.state == .relearning) && state.due <= now
                    }
                    return false
                }.count
                stats[cat] = (mastered, total, due)
            }
            categoryStats = stats
        } catch {
            categoryStats = [:]
        }
    }
}

struct CategoryRow: View {
    let category: ContentCategory
    let mastered: Int
    let total: Int
    let due: Int

    var body: some View {
        HStack {
            Text("\(category.emoji)")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayNameZhHans)
                    .font(.headline)
                    .foregroundColor(ThaiLifeTheme.textPrimary)
                Text("掌握 \(mastered)/\(total)")
                    .font(.caption)
                    .foregroundColor(ThaiLifeTheme.textSecondary)
            }
            Spacer()
            if due > 0 {
                Text("\(due)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ThaiLifeTheme.ratingAgain)
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 4)
    }
}
