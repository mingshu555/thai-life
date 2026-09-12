import SwiftUI

enum ThaiMenuCardFace {
    /// Legacy front-face check used by the unit tests and other callers.
    static func isFacingViewer(at rotation: Double) -> Bool {
        let normalized = rotation.truncatingRemainder(dividingBy: 360)
        return normalized > -90 && normalized < 90
    }

    /// Select exactly one face throughout the 0° ↔ 180° animation.
    /// The back face owns the 90° boundary so there is never a frame where
    /// both faces are transparent (the source of the flip text flash).
    static func isFacingViewer(at rotation: Double, isBack: Bool) -> Bool {
        var angle = rotation.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }

        if isBack {
            return angle >= 90 && angle <= 270
        }
        return angle < 90 || angle > 270
    }
}

struct ThaiMenuCardFaceModifier: AnimatableModifier {
    var rotation: Double
    var isBack: Bool

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    func body(content: Content) -> some View {
        let isVisible = ThaiMenuCardFace.isFacingViewer(at: rotation, isBack: isBack)
        return content
            // Face visibility is a discrete culling decision. Do not animate
            // the opacity switch; only the card shell's 3D rotation animates.
            .opacity(isVisible ? 1 : 0)
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}

struct ThaiMenuBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var audioService: AudioPlaybackServiceWrapper
    let startCardID: String?
    let cards: [ThaiMenuCard]?
    @State private var reference: ThaiMenuReference?
    @State private var loadError: String?
    @State private var index = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGFloat = 0

    init(startCardID: String? = nil, cards: [ThaiMenuCard]? = nil) {
        self.startCardID = startCardID
        self.cards = cards
    }

    static func initialIndex(cards: [ThaiMenuCard], startCardID: String?) -> Int {
        guard let startCardID,
              let index = cards.firstIndex(where: { $0.id == startCardID }) else { return 0 }
        return index
    }

    static func shouldShowMinimalBreakdown(for card: ThaiMenuCard) -> Bool {
        guard card.breakdown.minimal.count == 1,
              let onlyPart = card.breakdown.minimal.first else { return true }
        return onlyPart.thai != card.thai
    }


    var body: some View {
        Group {
            if let reference {
                browser(reference)
            } else if let loadError {
                ContentUnavailableView(cards != nil ? "暂无收藏菜单" : "菜单加载失败", systemImage: "fork.knife", description: Text(loadError))
            } else {
                ProgressView()
            }
        }
        .navigationTitle(cards != nil ? "收藏菜单" : "泰国常见菜单")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    @ViewBuilder
    private func browser(_ reference: ThaiMenuReference) -> some View {
        VStack(spacing: 0) {
            if !reference.cards.isEmpty {
                Text("\(index + 1) / \(reference.cards.count)")
                    .font(.subheadline)
                    .foregroundColor(ThaiLifeTheme.textSecondary)
                    .padding(.top, 12)

                    menuCard(reference.cards[index])
                    .id(reference.cards[index].id)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(ThaiLifeTheme.warmWhite)
    }

    private func menuCard(_ card: ThaiMenuCard) -> some View {
        ZStack {
            menuCardFront(card)
                .modifier(ThaiMenuCardFaceModifier(rotation: isFlipped ? 180 : 0, isBack: false))
            menuCardBack(card)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                .modifier(ThaiMenuCardFaceModifier(rotation: isFlipped ? 180 : 0, isBack: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThaiLifeTheme.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        // Rotate the complete card shell, including its background and both faces.
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.7
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                isFlipped.toggle()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    defer { dragOffset = 0 }
                    guard abs(value.translation.width) > abs(value.translation.height), abs(value.translation.width) > 70 else { return }
                    if value.translation.width < 0 { next() } else { previous() }
                }
        )
        .offset(x: dragOffset * 0.12)
        .animation(.easeOut(duration: 0.18), value: dragOffset)
    }

    private func menuCardFront(_ card: ThaiMenuCard) -> some View {
        GeometryReader { geometry in
            let imageHeight = max(180, geometry.size.height * 0.52)

            VStack(spacing: 0) {
                // Top: Edge-to-edge food image
                ZStack(alignment: .topTrailing) {
                    if let url = ContentRepository.resourceBundle.url(forResource: card.imageAssetID, withExtension: "jpg", subdirectory: "ThaiMenu"),
                       let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: imageHeight)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(ThaiLifeTheme.paleGreen.opacity(0.25))
                            .frame(width: geometry.size.width, height: imageHeight)
                    }
                }
                .frame(width: geometry.size.width, height: imageHeight)

                // Bottom: Balanced info section
                VStack(spacing: 12) {
                    Spacer()

                    // Category Pill Tag
                    Text(card.category)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ThaiLifeTheme.deepGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(ThaiLifeTheme.paleGreen.opacity(0.35))
                        .clipShape(Capsule())

                    // Thai Dish Name (Click text directly to play audio)
                    Button {
                        _ = audioService.service.play(audioID: card.audioID, thaiText: card.thai)
                    } label: {
                        Text(card.thai)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(ThaiLifeTheme.deepGreen)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(card.thai)
                    .accessibilityHint("播放泰文菜名发音")

                    // Chinese Popular Name
                    Text(card.meaningZhHans)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(ThaiLifeTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(width: geometry.size.width, height: max(0, geometry.size.height - imageHeight))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func menuCardBack(_ card: ThaiMenuCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header: Category Pill Tag
                Text(card.category)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ThaiLifeTheme.deepGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ThaiLifeTheme.paleGreen.opacity(0.35))
                    .clipShape(Capsule())

                // Thai Name (Click text directly to play audio) and Chinese Name
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        _ = audioService.service.play(audioID: card.audioID, thaiText: card.thai)
                    } label: {
                        Text(card.thai)
                            .font(.system(size: ReviewCardTypography.answerThaiMinimum, weight: .bold))
                            .foregroundColor(ThaiLifeTheme.deepGreen)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(card.thai)
                    .accessibilityHint("播放泰文菜名发音")

                    Text(card.meaningZhHans)
                        .font(.system(size: ReviewCardTypography.answerMeaningMinimum, weight: .semibold))
                        .foregroundColor(ThaiLifeTheme.textPrimary)
                }

                // Optional Cultural / Culinary / Ingredient Explanation
                if let explanation = card.explanationZhHans, !explanation.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.2))
                                .font(.system(size: 13))
                            Text("菜名与食材小知识")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(ThaiLifeTheme.textSecondary)
                        }
                        Text(explanation)
                            .font(.system(size: 13))
                            .foregroundColor(ThaiLifeTheme.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.96, green: 0.95, blue: 0.91))
                    .cornerRadius(10)
                }

                // Breakdown section
                breakdown(card)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func breakdown(_ card: ThaiMenuCard) -> some View {
        if Self.shouldShowMinimalBreakdown(for: card) {
            VStack(alignment: .leading, spacing: 8) {
                Text("最小拆解")
                    .font(.system(size: ReviewCardTypography.sectionLabelFontSize, weight: .bold))
                    .foregroundColor(ThaiLifeTheme.textTertiary)

                VStack(spacing: 6) {
                    ForEach(card.breakdown.minimal) { part in
                        breakdownPartButton(part)
                    }
                }
            }
        }
    }

    private func breakdownPartButton(_ part: ThaiMenuBreakdownPart) -> some View {
        Button {
            _ = audioService.service.play(
                audioID: SegmentAudioID.audioID(for: part.thai),
                thaiText: part.thai
            )
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(part.thai)
                    .font(.system(size: ReviewCardTypography.segmentThaiFontSize, weight: .bold))
                    .foregroundColor(ThaiLifeTheme.deepGreen)

                Spacer()

                Text(part.glossZhHans)
                    .font(.system(size: ReviewCardTypography.segmentGlossFontSize))
                    .foregroundColor(ThaiLifeTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ThaiLifeTheme.warmWhite)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(part.thai)
        .accessibilityHint("播放拆解词块发音")
    }

    private func load() {
        if let customCards = cards {
            if customCards.isEmpty {
                loadError = "暂无已收藏的菜单卡片"
                reference = nil
            } else {
                reference = ThaiMenuReference(introductionZhHans: "收藏菜单", cards: customCards)
                index = Self.initialIndex(cards: customCards, startCardID: startCardID)
                isFlipped = false
                loadError = nil
            }
            return
        }

        do {
            let loaded = try ContentRepository.loadThaiMenuReference()
            reference = loaded
            index = Self.initialIndex(cards: loaded.cards, startCardID: startCardID)
            isFlipped = false
        } catch {
            loadError = error.localizedDescription
        }
    }


    private func previous() {
        guard index > 0 else { return }
        withAnimation(.easeOut(duration: 0.2)) { index -= 1; isFlipped = false }
    }

    private func next() {
        guard let count = reference?.cards.count, index < count - 1 else { return }
        withAnimation(.easeOut(duration: 0.2)) { index += 1; isFlipped = false }
    }
}

struct ThaiMenuCardView: View {
    let card: ThaiMenuCard
    let isFlipped: Bool
    let onTapThai: () -> Void
    let onTapSegment: (ThaiMenuBreakdownPart) -> Void

    var body: some View {
        ZStack {
            cardFront
                .modifier(ThaiMenuCardFaceModifier(rotation: isFlipped ? 180 : 0, isBack: false))
            cardBack
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                .modifier(ThaiMenuCardFaceModifier(rotation: isFlipped ? 180 : 0, isBack: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThaiLifeTheme.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.7
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
    }

    private var cardFront: some View {
        GeometryReader { geometry in
            let imageHeight = max(180, geometry.size.height * 0.52)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if let url = ContentRepository.resourceBundle.url(forResource: card.imageAssetID, withExtension: "jpg", subdirectory: "ThaiMenu"),
                       let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: imageHeight)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(ThaiLifeTheme.paleGreen.opacity(0.25))
                            .frame(width: geometry.size.width, height: imageHeight)
                    }
                }
                .frame(width: geometry.size.width, height: imageHeight)

                VStack(spacing: 12) {
                    Spacer()

                    Text(card.category)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ThaiLifeTheme.deepGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(ThaiLifeTheme.paleGreen.opacity(0.35))
                        .clipShape(Capsule())

                    Button(action: onTapThai) {
                        Text(card.thai)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(ThaiLifeTheme.deepGreen)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(card.thai)
                    .accessibilityHint("播放泰文菜名发音")

                    Text(card.meaningZhHans)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(ThaiLifeTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(width: geometry.size.width, height: max(0, geometry.size.height - imageHeight))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardBack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(card.category)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ThaiLifeTheme.deepGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ThaiLifeTheme.paleGreen.opacity(0.35))
                    .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 4) {
                    Button(action: onTapThai) {
                        Text(card.thai)
                            .font(.system(size: ReviewCardTypography.answerThaiMinimum, weight: .bold))
                            .foregroundColor(ThaiLifeTheme.deepGreen)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(card.thai)
                    .accessibilityHint("播放泰文菜名发音")

                    Text(card.meaningZhHans)
                        .font(.system(size: ReviewCardTypography.answerMeaningMinimum, weight: .semibold))
                        .foregroundColor(ThaiLifeTheme.textPrimary)
                }

                if let explanation = card.explanationZhHans, !explanation.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.2))
                                .font(.system(size: 13))
                            Text("菜名与食材小知识")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(ThaiLifeTheme.textSecondary)
                        }
                        Text(explanation)
                            .font(.system(size: 13))
                            .foregroundColor(ThaiLifeTheme.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.96, green: 0.95, blue: 0.91))
                    .cornerRadius(10)
                }

                if ThaiMenuBrowserView.shouldShowMinimalBreakdown(for: card) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最小拆解")
                            .font(.system(size: ReviewCardTypography.sectionLabelFontSize, weight: .bold))
                            .foregroundColor(ThaiLifeTheme.textTertiary)

                        VStack(spacing: 6) {
                            ForEach(card.breakdown.minimal) { part in
                                Button(action: { onTapSegment(part) }) {
                                    HStack(alignment: .center, spacing: 10) {
                                        Text(part.thai)
                                            .font(.system(size: ReviewCardTypography.segmentThaiFontSize, weight: .bold))
                                            .foregroundColor(ThaiLifeTheme.deepGreen)

                                        Spacer()

                                        Text(part.glossZhHans)
                                            .font(.system(size: ReviewCardTypography.segmentGlossFontSize))
                                            .foregroundColor(ThaiLifeTheme.textSecondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(ThaiLifeTheme.warmWhite)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(part.thai)
                                .accessibilityHint("播放拆解词块发音")
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .frame(maxHeight: .infinity)
    }
}

struct ThaiMenuCardBrowserCard: View {
    let card: ThaiMenuCard
    let isFlipped: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onTapThai: () -> Void
    let onTapSegment: (ThaiMenuBreakdownPart) -> Void
    let onFlip: () -> Void
    let onSwipeNext: () -> Void
    let onSwipePrevious: () -> Void

    var body: some View {
        ThaiMenuCardView(
            card: card,
            isFlipped: isFlipped,
            onTapThai: onTapThai,
            onTapSegment: onTapSegment
        )
    }
}
