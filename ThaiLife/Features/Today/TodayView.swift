import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TodayViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack(alignment: .center, spacing: 16) {
                        Image("KhoKhaiIconClay")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 56)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("泰生活")
                                .font(.title.bold())
                                .foregroundColor(ThaiLifeTheme.deepGreen)

                            Text(formattedDate)
                                .font(.subheadline)
                                .foregroundColor(ThaiLifeTheme.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Stats cards
                    HStack(spacing: 12) {
                        StatCard(
                            title: "待复习",
                            value: "\(viewModel.snapshot.dueCount)",
                            color: ThaiLifeTheme.ratingAgain
                        )
                        StatCard(
                            title: "新词额度",
                            value: "\(viewModel.snapshot.newLimit)",
                            color: ThaiLifeTheme.paleGreen
                        )
                        StatCard(
                            title: "预计用时",
                            value: "\(viewModel.snapshot.estimatedMinutes)分钟",
                            color: ThaiLifeTheme.deepGreen
                        )
                    }
                    .padding(.horizontal)

                    // Retention
                    HStack {
                        Text("目标记忆率")
                            .font(.subheadline)
                            .foregroundColor(ThaiLifeTheme.textSecondary)
                        Spacer()
                        Text("\(Int(viewModel.snapshot.targetRetention * 100))%")
                            .font(.subheadline.bold())
                            .foregroundColor(ThaiLifeTheme.deepGreen)
                    }
                    .padding(.horizontal)

                    // Primary CTA
                    Button(action: { viewModel.startReview() }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(viewModel.snapshot.dueCount > 0 ? "开始复习" : "学新词")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ThaiLifeTheme.deepGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(viewModel.snapshot.dueCount == 0 && viewModel.snapshot.newLimit == 0)

                    // Quick links
                    VStack(alignment: .leading, spacing: 12) {
                        // Favorites entry
                        NavigationLink(destination: FavoriteListView().environmentObject(appState)) {
                            QuickLinkRow(
                                icon: "heart.fill",
                                title: "收藏练习",
                                subtitle: "只复习已收藏的内容"
                            )
                        }

                        if !viewModel.snapshot.weakDirections.isEmpty {
                            Button(action: { viewModel.startWeaknessReview() }) {
                                QuickLinkRow(
                                    icon: "arrow.triangle.swap",
                                    title: "薄弱方向",
                                    subtitle: viewModel.snapshot.weakDirections.joined(separator: "、")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if !viewModel.snapshot.confusedPairs.isEmpty {
                            NavigationLink(destination: Text("易混词辨析")) {
                                QuickLinkRow(
                                    icon: "rectangle.on.rectangle.angled",
                                    title: "易混词辨析",
                                    subtitle: "\(viewModel.snapshot.confusedPairs.count) 组易混词"
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.vertical)
            }
            .background(ThaiLifeTheme.warmWhite)
            .navigationDestination(isPresented: $viewModel.showReview) {
                ReviewSessionView(route: viewModel.reviewRoute)
                    .environmentObject(appState)
            }
            .onAppear { viewModel.refresh(appState: appState) }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: Date())
    }
}

// MARK: - Subviews

struct StatCard: View {
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

struct QuickLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ThaiLifeTheme.deepGreen)
                .frame(width: 32, height: 32)
                .background(ThaiLifeTheme.paleGreen.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(ThaiLifeTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ThaiLifeTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ThaiLifeTheme.textTertiary)
        }
        .padding(12)
        .background(ThaiLifeTheme.cardWhite)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
