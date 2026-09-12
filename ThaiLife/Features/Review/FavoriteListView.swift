import SwiftUI

struct FavoriteListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var sections: [FavoriteDateSection] = []
    @State private var menuCards: [ThaiMenuCard] = []
    @State private var loadError: String?
    @State private var selectedEntryID: String?

    static func browserRoute(contentID: String) -> ReviewSessionRoute { .favoriteBrowse(startContentID: contentID) }

    private var allEntries: [FavoriteListEntry] {
        sections.flatMap(\.entries)
    }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("收藏加载失败", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if sections.isEmpty {
                ContentUnavailableView("暂无收藏内容", systemImage: "heart")
            } else {
                favoriteSections
            }
        }
        .background(Color.white)
        .navigationTitle("收藏练习")
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(isPresented: Binding(
            get: { selectedEntryID != nil },
            set: { if !$0 { selectedEntryID = nil } }
        )) {
            FavoriteBrowserView(startEntryID: selectedEntryID, entries: allEntries)
                .environmentObject(appState)
        }
        .task { load() }
    }

    private var favoriteSections: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.entries) { entry in
                        FavoriteListRow(
                            entry: entry,
                            onPlayThai: { item in
                                _ = appState.audioService.play(
                                    audioID: item.audioID,
                                    thaiText: item.thai
                                )
                            },
                            onBrowse: {
                                selectedEntryID = entry.id
                            },
                            onRemoveFavorite: {
                                removeFavorite(entry.id)
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.visible)
                    }
                } header: {
                    FavoriteDateHeader(title: section.title)
                        .textCase(nil)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.white)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color.white)
    }

    private func load() {
        guard let store = appState.store else {
            loadError = "学习数据服务暂不可用"
            return
        }
        do {
            let loadedMenuCards = (try? ContentRepository.loadThaiMenuReference().cards) ?? []
            menuCards = loadedMenuCards
            sections = FavoriteListPresentation.sections(
                records: try store.allFavorites(),
                content: appState.contentItems,
                menuCards: loadedMenuCards
            )
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func removeFavorite(_ contentID: String) {
        guard let store = appState.store else {
            loadError = "收藏服务暂不可用"
            return
        }
        do {
            try store.toggleFavorite(contentID: contentID)
            sections = sections.compactMap { section in
                let remaining = section.entries.filter { $0.id != contentID }
                guard !remaining.isEmpty else { return nil }
                return FavoriteDateSection(date: section.date, title: section.title, entries: remaining)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct FavoriteListRow: View {
    let entry: FavoriteListEntry
    let onPlayThai: (ContentItem) -> Void
    let onBrowse: () -> Void
    let onRemoveFavorite: () -> Void

    var body: some View {
        rowContent
            .background(Color.white)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(action: onRemoveFavorite) {
                    Label("取消收藏", systemImage: "heart.slash")
                }
                .tint(ThaiLifeTheme.error)
            }
    }

    @ViewBuilder
    private var rowContent: some View {
        switch entry.kind {
        case .content(let item):
            HStack(alignment: .top, spacing: 12) {
                Button(action: { onPlayThai(item) }) {
                    Text(item.thai)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ThaiLifeTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.meaningZhHans)
                        .font(.body)
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onBrowse)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 14)
            .contentShape(Rectangle())

        case .menu(let card):
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.thai)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ThaiLifeTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(card.meaningZhHans)
                        .font(.body)
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture(perform: onBrowse)
        }
    }
}

private struct FavoriteDateHeader: View {
    let title: String

    var body: some View {
        ZStack {
            Rectangle().fill(Color.white)
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ThaiLifeTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .zIndex(1)
    }
}

struct FavoriteBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let startEntryID: String?
    let entries: [FavoriteListEntry]

    @State private var index: Int = 0

    init(startEntryID: String?, entries: [FavoriteListEntry]) {
        self.startEntryID = startEntryID
        self.entries = entries
        let initialIdx = entries.firstIndex(where: { $0.id == startEntryID }) ?? 0
        _index = State(initialValue: initialIdx)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(ThaiLifeTheme.deepGreen)
                }

                Spacer()

                if !entries.isEmpty {
                    Text("\(index + 1) / \(entries.count)")
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
            .padding(.bottom, 8)
            .background(ThaiLifeTheme.warmWhite)

            // Card display area
            if entries.isEmpty {
                Spacer()
                ContentUnavailableView("暂无收藏内容", systemImage: "heart")
                Spacer()
            } else {
                TabView(selection: $index) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                        FavoriteCardPageCell(entry: entry)
                            .tag(idx)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(ThaiLifeTheme.warmWhite)
        .navigationBarHidden(true)
    }
}

private struct FavoriteCardPageCell: View {
    let entry: FavoriteListEntry
    @EnvironmentObject private var appState: AppState
    @State private var isFlipped = false

    var body: some View {
        Group {
            switch entry.kind {
            case .content(let item):
                contentCard(item)
            case .menu(let card):
                menuCard(card)
            }
        }
    }

    private func contentCard(_ item: ContentItem) -> some View {
        GeometryReader { geo in
            let layout = ThaiTextSizing.font(
                for: isFlipped ? item.thai : item.thai,
                availableWidth: geo.size.width - 48,
                maxLines: 8
            )

            ZStack {
                if !isFlipped {
                    CardFront(
                        item: item,
                        direction: "thai→zh",
                        fontSize: layout.fontSize,
                        onTapThai: {
                            _ = appState.audioService.play(audioID: item.audioID, thaiText: item.thai)
                        }
                    )
                } else {
                    CardBack(
                        item: item,
                        layout: layout,
                        continuationPart: 0,
                        isContinuation: false,
                        isBrowsing: true,
                        onTapThai: {
                            _ = appState.audioService.play(audioID: item.audioID, thaiText: item.thai)
                        },
                        onTapExample: {
                            guard let ex = item.example, !ex.isEmpty else { return }
                            _ = appState.audioService.playSentence(audioID: item.audioID + "-example", text: ex)
                        },
                        onTapSegment: { segment in
                            _ = appState.audioService.playSegment(segment)
                        },
                        onRate: { _ in }
                    )
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ThaiLifeTheme.cardWhite)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isFlipped.toggle()
                }
            }
        }
    }

    private func menuCard(_ card: ThaiMenuCard) -> some View {
        ThaiMenuCardView(
            card: card,
            isFlipped: isFlipped,
            onTapThai: {
                _ = appState.audioService.play(audioID: card.audioID, thaiText: card.thai)
            },
            onTapSegment: { part in
                _ = appState.audioService.play(
                    audioID: SegmentAudioID.audioID(for: part.thai),
                    thaiText: part.thai
                )
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                isFlipped.toggle()
            }
        }
    }
}

