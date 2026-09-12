import SwiftUI

struct ProgressView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Recall Rate
                    VStack(alignment: .leading, spacing: 12) {
                        Text("记忆表现")
                            .font(.headline)
                            .foregroundColor(ThaiLifeTheme.deepGreen)

                        HStack(spacing: 10) {
                            ProgressStatCard(
                                title: "历史答对率",
                                value: "\(Int(viewModel.snapshot.historicalCorrectRate * 100))%",
                                color: ThaiLifeTheme.ratingGood
                            )
                            ProgressStatCard(
                                title: "FSRS预计回忆率",
                                value: "\(Int(viewModel.snapshot.estimatedRecall * 100))%",
                                color: ThaiLifeTheme.paleGreen
                            )
                            ProgressStatCard(
                                title: "目标记忆率",
                                value: "\(Int(viewModel.snapshot.targetRetention * 100))%",
                                color: ThaiLifeTheme.deepGreen
                            )
                        }
                    }
                    .padding(.horizontal)

                    // 30-day forecast
                    VStack(alignment: .leading, spacing: 12) {
                        Text("未来 30 天复习负荷预测")
                            .font(.headline)
                            .foregroundColor(ThaiLifeTheme.deepGreen)

                        if viewModel.snapshot.dailyLoad.isEmpty {
                            Text("暂无足够数据")
                                .font(.subheadline)
                                .foregroundColor(ThaiLifeTheme.textSecondary)
                        } else {
                            let maxLoad = max(1, viewModel.snapshot.dailyLoad.max() ?? 1)
                            HStack(alignment: .bottom, spacing: 3) {
                                ForEach(Array(viewModel.snapshot.dailyLoad.enumerated()), id: \.offset) { _, load in
                                    let height = max(4, CGFloat(load) / CGFloat(maxLoad) * 80)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(load > maxLoad / 2 ? ThaiLifeTheme.ratingAgain : ThaiLifeTheme.paleGreen)
                                        .frame(height: height)
                                }
                            }
                            .frame(height: 80)
                        }
                    }
                    .padding(.horizontal)

                    // Category mastery
                    VStack(alignment: .leading, spacing: 12) {
                        Text("各主题掌握度")
                            .font(.headline)
                            .foregroundColor(ThaiLifeTheme.deepGreen)

                        ForEach(viewModel.snapshot.categoryMastery, id: \.category) { cm in
                            HStack {
                                Text("\(cm.category.emoji) \(cm.category.displayNameZhHans)")
                                    .font(.subheadline)
                                    .foregroundColor(ThaiLifeTheme.textPrimary)
                                Spacer()
                                Text("\(Int(cm.mastery * 100))%")
                                    .font(.subheadline.bold())
                                    .foregroundColor(ThaiLifeTheme.deepGreen)
                            }
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(ThaiLifeTheme.paleGreen.opacity(0.3))
                                    .frame(height: 6)
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(ThaiLifeTheme.paleGreen)
                                            .frame(width: geo.size.width * cm.mastery, height: 6)
                                    }
                            }
                            .frame(height: 6)
                        }
                    }
                    .padding(.horizontal)

                    // Weak directions with practice link
                    if !viewModel.snapshot.weakDirections.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("薄弱提取方向")
                                .font(.headline)
                                .foregroundColor(ThaiLifeTheme.deepGreen)

                            ForEach(viewModel.snapshot.weakDirections, id: \.self) { dir in
                                NavigationLink(destination: ReviewSessionView(route: .weakness).environmentObject(appState)) {
                                    HStack {
                                        Text(dir)
                                            .font(.subheadline)
                                            .foregroundColor(ThaiLifeTheme.textPrimary)
                                        Spacer()
                                        Text("针对性练习 →")
                                            .font(.caption)
                                            .foregroundColor(ThaiLifeTheme.paleGreen)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if !viewModel.snapshot.confusedPairs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("易混词辨析")
                                .font(.headline)
                                .foregroundColor(ThaiLifeTheme.deepGreen)

                            ForEach(Array(viewModel.snapshot.confusedPairs.enumerated()), id: \.offset) { idx, pair in
                                let ids = idx < viewModel.snapshot.confusedPairIDs.count
                                    ? viewModel.snapshot.confusedPairIDs[idx] : []
                                NavigationLink(destination: ReviewSessionView(route: .confusedPairs(ids)).environmentObject(appState)) {
                                    Text(pair)
                                        .font(.subheadline)
                                        .foregroundColor(ThaiLifeTheme.textPrimary)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .background(ThaiLifeTheme.warmWhite)
            .navigationTitle("进度")
            .onAppear { viewModel.refresh(appState: appState) }
        }
    }
}

struct ProgressStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(ThaiLifeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ThaiLifeTheme.cardWhite)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
