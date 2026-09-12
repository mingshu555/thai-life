import SwiftUI

struct UnitDetailView: View {
    let category: ContentCategory
    @EnvironmentObject private var appState: AppState
    @State private var items: [ContentItem] = []
    @State private var favoriteIDs: Set<String> = []
    @State private var favoriteErrorMessage: String?
    @State private var showReview = false
    @State private var selectedBrowseItemID: String?

    static func browserRoute(category: ContentCategory, itemID: String) -> ReviewSessionRoute {
        .courseBrowse(category: category, startContentID: itemID)
    }

    var body: some View {
        List {
            ForEach(items) { item in
                UnitDetailRowView(
                    item: item,
                    isFavorite: favoriteIDs.contains(item.id),
                    onToggleFavorite: {
                        guard let store = appState.store else {
                            favoriteErrorMessage = "收藏服务暂不可用"
                            return
                        }
                        do {
                            try store.toggleFavorite(contentID: item.id)
                            favoriteIDs = Set(try store.allFavoriteIDs())
                        } catch {
                            favoriteErrorMessage = error.localizedDescription
                        }
                    },
                    onSelectBrowse: {
                        selectedBrowseItemID = item.id
                    }
                )
            }
        }
        .listStyle(.plain)
        .navigationTitle(category.displayNameZhHans)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("练习") {
                    showReview = true
                }
                .font(.subheadline.bold())
            }
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewSessionView(route: .unit(category.rawValue))
                .environmentObject(appState)
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedBrowseItemID != nil },
            set: { if !$0 { selectedBrowseItemID = nil } }
        )) {
            if let itemID = selectedBrowseItemID {
                ReviewSessionView(route: UnitDetailView.browserRoute(category: category, itemID: itemID))
                    .environmentObject(appState)
            }
        }
        .alert(
            "收藏失败",
            isPresented: Binding(
                get: { favoriteErrorMessage != nil },
                set: { if !$0 { favoriteErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(favoriteErrorMessage ?? "未知错误")
        }
        .onAppear {
            do {
                guard let store = appState.store else {
                    favoriteErrorMessage = "收藏服务暂不可用"
                    return
                }
                items = try ContentRepository.loadBundled().filter { $0.category == category }
                favoriteIDs = Set(try store.allFavoriteIDs())
            } catch {
                favoriteErrorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Row View with Explicit Hit Target Isolation

enum UnitDetailRowHitArea: String, Equatable, CaseIterable {
    case thaiText
    case meaning
    case example
    case metadata
    case rowBackground
    case favoriteButton
}

enum UnitDetailRowActionTarget: Equatable {
    case playAudio
    case toggleFavorite
    case browse
}

struct UnitDetailRowHitTargetResolver {
    static func target(for area: UnitDetailRowHitArea) -> UnitDetailRowActionTarget {
        switch area {
        case .thaiText:
            return .playAudio
        case .favoriteButton:
            return .toggleFavorite
        case .meaning, .example, .metadata, .rowBackground:
            return .browse
        }
    }
}

struct UnitDetailRowView: View {
    let item: ContentItem
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onSelectBrowse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1. Thai text only: play audio target
            ThaiText(
                thai: item.thai,
                audioID: item.audioID,
                showMeaning: false,
                fontSize: CourseListTypography.itemThaiFontSize
            )

            // 2. Browse navigation area: Chinese meaning, Example, Metadata & full width whitespace
            VStack(alignment: .leading, spacing: 6) {
                Text(item.meaningZhHans)
                    .font(.system(size: CourseListTypography.itemThaiFontSize * 0.55))
                    .foregroundColor(ThaiLifeTheme.textSecondary)

                if let example = item.example, !example.isEmpty {
                    Text("例：\(example)")
                        .font(.system(size: CourseListTypography.exampleFontSize))
                        .foregroundColor(ThaiLifeTheme.textTertiary)
                }

                HStack {
                    Label(item.kind.rawValue, systemImage: kindIcon(for: item.kind))
                        .font(.system(size: CourseListTypography.metadataFontSize))
                        .foregroundColor(ThaiLifeTheme.paleGreen)

                    Spacer()

                    // 3. Favorite button: toggle favorite target
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(isFavorite ? .red : ThaiLifeTheme.textTertiary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectBrowse()
            }
        }
        .padding(.vertical, 4)
    }

    private func kindIcon(for kind: ContentKind) -> String {
        switch kind {
        case .word: "character"
        case .chunk: "text.word.spacing"
        case .sentence: "text.quote"
        case .dialogue: "bubble.left.and.bubble.right"
        }
    }
}
