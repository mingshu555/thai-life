import SwiftUI

struct ThaiMenuListView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var audioService: AudioPlaybackServiceWrapper
    @State private var reference: ThaiMenuReference?
    @State private var favoriteIDs: Set<String> = []
    @State private var loadError: String?
    @State private var favoriteErrorMessage: String?
    @State private var selectedCardID: String?

    private var groupedCards: [(category: String, cards: [ThaiMenuCard])] {
        guard let cards = reference?.cards else { return [] }
        var seenCategories: [String] = []
        var cardsByCategory: [String: [ThaiMenuCard]] = [:]

        for card in cards {
            if cardsByCategory[card.category] == nil {
                seenCategories.append(card.category)
                cardsByCategory[card.category] = []
            }
            cardsByCategory[card.category]?.append(card)
        }

        return seenCategories.compactMap { category in
            guard let categoryCards = cardsByCategory[category] else { return nil }
            return (category, categoryCards)
        }
    }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("菜单加载失败", systemImage: "fork.knife", description: Text(loadError))
            } else if let reference {
                menuList(reference)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("泰国常见菜单")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(
            get: { selectedCardID != nil },
            set: { if !$0 { selectedCardID = nil } }
        )) {
            ThaiMenuBrowserView(startCardID: selectedCardID)
                .environmentObject(appState)
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
        .task { load() }
        .onAppear { refreshFavorites() }
    }

    private func menuList(_ reference: ThaiMenuReference) -> some View {
        List {
            ForEach(groupedCards, id: \.category) { group in
                Section(header: Text(group.category)) {
                    ForEach(group.cards) { card in
                        menuRow(card)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func menuRow(_ card: ThaiMenuCard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    _ = audioService.service.play(audioID: card.audioID, thaiText: card.thai)
                } label: {
                    Text(card.thai)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ThaiLifeTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(card.thai)
                .accessibilityHint("播放泰文发音")
                Text(card.meaningZhHans)
                    .font(.body)
                    .foregroundColor(ThaiLifeTheme.textSecondary)
            }
            Spacer()
            Button {
                toggleFavorite(card.id)
            } label: {
                Image(systemName: favoriteIDs.contains(card.id) ? "heart.fill" : "heart")
                    .foregroundColor(favoriteIDs.contains(card.id) ? .red : ThaiLifeTheme.textTertiary)
                    .padding(8)
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCardID = card.id
        }
    }

    private func load() {
        do {
            reference = try ContentRepository.loadThaiMenuReference()
            refreshFavorites()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func refreshFavorites() {
        guard let store = appState.store else { return }
        do {
            favoriteIDs = Set(try store.allFavoriteIDs())
        } catch {
            favoriteErrorMessage = error.localizedDescription
        }
    }

    private func toggleFavorite(_ cardID: String) {
        guard let store = appState.store else {
            favoriteErrorMessage = "收藏服务暂不可用"
            return
        }
        do {
            try store.toggleFavorite(contentID: cardID)
            favoriteIDs = Set(try store.allFavoriteIDs())
        } catch {
            favoriteErrorMessage = error.localizedDescription
        }
    }
}
