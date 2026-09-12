import SwiftUI

enum ReviewSessionRoute: Equatable {
    case daily
    case unit(String)
    case weakness
    case favorites
    case confusedPairs([String])
    case courseBrowse(category: ContentCategory, startContentID: String)
    case favoriteBrowse(startContentID: String)

    var draftSource: String? {
        switch self {
        case .daily: return "daily"
        case .unit(let category): return "unit:\(category)"
        case .weakness: return "weakness"
        case .favorites: return "favorites"
        case .confusedPairs: return nil
        case .courseBrowse, .favoriteBrowse: return nil
        }
    }

    var isCardBrowser: Bool {
        switch self {
        case .courseBrowse, .favoriteBrowse: return true
        default: return false
        }
    }

    var isCourseBrowser: Bool {
        if case .courseBrowse = self { return true }
        return false
    }

    func acceptsDraftSource(_ source: String) -> Bool {
        draftSource == source
    }
}

struct ReviewSessionView: View {
    let route: ReviewSessionRoute
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ReviewSessionViewModel()
    @Environment(\.dismiss) private var dismiss

    private var emptyMessage: String {
        switch route {
        case .daily: "暂无可复习内容"
        case .weakness: "暂无薄弱项，继续保持！"
        case .favorites: "暂无收藏内容"
        case .confusedPairs: "暂无易混词"
        case .unit: "该主题暂无可复习内容"
        case .courseBrowse: "该分类暂无卡片"
        case .favoriteBrowse: "暂无收藏内容"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: {
                    viewModel.goBack(appState: appState)
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(ThaiLifeTheme.deepGreen)
                }

                Spacer()

                if !viewModel.queue.isEmpty {
                    Text("\(viewModel.cursor + 1) / \(viewModel.queue.count)")
                        .font(.subheadline)
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                }

                Spacer()
                Image(systemName: "arrow.left")
                    .font(.title3)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(ThaiLifeTheme.warmWhite)

            // Card area
            if (viewModel.queue.isEmpty || viewModel.cursor >= viewModel.queue.count) && viewModel.currentItem == nil {
                Spacer()
                VStack(spacing: 16) {
                    if viewModel.cursor > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(ThaiLifeTheme.success)
                        Text(route.isCardBrowser ? "已浏览完毕" : "复习完成！")
                            .font(.title2.bold())
                            .foregroundColor(ThaiLifeTheme.deepGreen)

                        Button(action: { viewModel.goToPrevious() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.left")
                                Text("返回上一张卡片")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(ThaiLifeTheme.deepGreen)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(ThaiLifeTheme.paleGreen.opacity(0.3))
                            .cornerRadius(20)
                        }
                    } else {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(ThaiLifeTheme.textTertiary)
                        Text(emptyMessage)
                            .font(.title3)
                            .foregroundColor(ThaiLifeTheme.textSecondary)
                    }
                }
                Spacer()
            } else if let currentItem = viewModel.currentItem {
                FlipCardView(
                    item: currentItem,
                    isFlipped: viewModel.isFlipped,
                    direction: viewModel.currentDirection,
                    isContinuation: viewModel.isCurrentContinuation,
                    continuationPart: viewModel.continuationPart,
                    canGoPrevious: viewModel.hasPrevious,
                    canGoNext: viewModel.hasNext,
                    isBrowsing: route.isCardBrowser,
                    onTapThai: { viewModel.playAudio(appState: appState) },
                    onTapExample: { viewModel.playExampleAudio(appState: appState) },
                    onTapSegment: { viewModel.playSegment($0, appState: appState) },
                    onFlip: { viewModel.flip() },
                    onRate: { rating in viewModel.rate(rating, appState: appState) },
                    onSwipeNext: { viewModel.goToNext() },
                    onSwipePrevious: { viewModel.goToPrevious() }
                )
            } else {
                Spacer()
                SwiftUI.ProgressView("正在准备…")
                Spacer()
            }

            Spacer()
        }
        .background(ThaiLifeTheme.warmWhite)
        .alert(
            "加载失败",
            isPresented: Binding(
                get: { viewModel.loadError != nil },
                set: { if !$0 { viewModel.loadError = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.loadError ?? "未知错误")
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadSession(route: route, appState: appState)
        }
    }
}
