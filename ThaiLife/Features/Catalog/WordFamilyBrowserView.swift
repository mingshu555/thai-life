import SwiftUI

/// Browser view for Root Word Family Cards (词根词族卡片浏览器)
struct WordFamilyBrowserView: View {
    @EnvironmentObject private var appState: AppState

    let families: [WordFamily]
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false

    init(families: [WordFamily] = [], initialIndex: Int = 0) {
        self.families = families.isEmpty ? ContentRepository.loadWordFamilies() : families
        self._currentIndex = State(initialValue: initialIndex)
    }

    private var activeAudioService: AudioPlaybackService {
        appState.audioService
    }

    var body: some View {
        VStack(spacing: 0) {
            if families.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundColor(ThaiLifeTheme.textTertiary)
                    Text("暂无词根词族卡片")
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let family = families[currentIndex]

                // Word Family Card View with horizontal swipe gesture
                WordFamilyCardView(
                    family: family,
                    isFlipped: isFlipped,
                    canGoPrevious: currentIndex > 0,
                    canGoNext: currentIndex < families.count - 1,
                    onFlip: {
                        withAnimation(.spring(response: 0.4)) {
                            isFlipped.toggle()
                        }
                    },
                    onSwipeNext: goToNext,
                    onSwipePrevious: goToPrevious,
                    onTapMemberAudio: { member in
                        let audioID = member.audioID ?? "audio-\(member.id)"
                        activeAudioService.play(audioID: audioID, thaiText: member.thai)
                    },
                    onTapRootAudio: {
                        // Strictly use rootAudioID if available; otherwise use empty string so TTS speaks ONLY the root word itself (e.g. "ไม่")
                        let audioID = (family.rootAudioID?.isEmpty == false) ? family.rootAudioID! : ""
                        activeAudioService.play(audioID: audioID, thaiText: family.rootThai)
                    }
                )
                .padding(.top, 8)

                // Bottom Page Control Indicator. Each dot has a larger tap target
                // than its visual circle so users can jump directly to any card.
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(0..<families.count, id: \.self) { idx in
                                Button {
                                    jumpToCard(idx)
                                } label: {
                                    Circle()
                                        .fill(idx == currentIndex ? ThaiLifeTheme.deepGreen : ThaiLifeTheme.paleGreen.opacity(0.4))
                                        .frame(width: 8, height: 8)
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("第\(idx + 1)张卡片")
                                .accessibilityValue(idx == currentIndex ? "当前" : "")
                                .accessibilityAddTraits(idx == currentIndex ? .isSelected : [])
                                .id(idx)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        proxy.scrollTo(currentIndex, anchor: .center)
                    }
                    .onChange(of: currentIndex) { _, index in
                        withAnimation {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("词根高频词族")
        .navigationBarTitleDisplayMode(.inline)
        .background(ThaiLifeTheme.warmWhite.ignoresSafeArea())
    }

    private func jumpToCard(_ index: Int) {
        guard families.indices.contains(index) else { return }
        withAnimation {
            currentIndex = index
            isFlipped = false
        }
    }

    private func goToPrevious() {
        guard currentIndex > 0 else { return }
        withAnimation {
            currentIndex -= 1
            isFlipped = false
        }
    }

    private func goToNext() {
        guard currentIndex < families.count - 1 else { return }
        withAnimation {
            currentIndex += 1
            isFlipped = false
        }
    }
}
