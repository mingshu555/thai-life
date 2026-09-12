import SwiftUI

/// Structured Root Word Family Card View (词根/前缀组词卡片)
/// Presents a root word and a multi-column table of high-frequency derived words.
struct WordFamilyCardView: View {
    let family: WordFamily
    let isFlipped: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onFlip: () -> Void
    let onSwipeNext: () -> Void
    let onSwipePrevious: () -> Void
    let onTapMemberAudio: (WordFamilyMember) -> Void
    let onTapRootAudio: () -> Void

    @State private var dragOffset: CGSize = .zero
    private let swipeThreshold: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    if !isFlipped {
                        WordFamilyCardFront(
                            family: family,
                            onFlip: onFlip,
                            onTapRootAudio: onTapRootAudio
                        )
                    } else {
                        WordFamilyCardBack(
                            family: family,
                            onFlip: onFlip,
                            onTapRootAudio: onTapRootAudio,
                            onTapMemberAudio: onTapMemberAudio
                        )
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ThaiLifeTheme.cardWhite)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .offset(x: dragOffset.width, y: dragOffset.height)
                .rotationEffect(.degrees(Double(dragOffset.width / 15)))
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            let width = value.translation.width

                            if width < -swipeThreshold {
                                // Swipe left -> Next card
                                if canGoNext {
                                    performCardDismiss(toRight: false) {
                                        onSwipeNext()
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        dragOffset = .zero
                                    }
                                }
                            } else if width > swipeThreshold {
                                // Swipe right -> Previous card
                                if canGoPrevious {
                                    performCardDismiss(toRight: true) {
                                        onSwipePrevious()
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        dragOffset = .zero
                                    }
                                }
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
            }
        }
    }

    private func performCardDismiss(toRight: Bool, action: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: toRight ? 600 : -600, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            action()
            dragOffset = .zero
        }
    }
}

// MARK: - Front of Root Word Family Card

struct WordFamilyCardFront: View {
    let family: WordFamily
    let onFlip: () -> Void
    let onTapRootAudio: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header Tag
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("词根词族扩展 · 包含 \(family.items.count) 个高频词")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(ThaiLifeTheme.deepGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(ThaiLifeTheme.paleGreen.opacity(0.25))
            .cornerRadius(20)

            // Prominent Root Thai Word Button (Tap to pronounce root ONLY)
            Button(action: { onTapRootAudio() }) {
                Text(family.rootThai)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(ThaiLifeTheme.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Chinese Meaning
            Text(family.rootMeaningZhHans)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ThaiLifeTheme.deepGreen)

            Spacer()

            Button(action: { onFlip() }) {
                HStack(spacing: 4) {
                    Text("点击翻面查看完整词族")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                }
                .foregroundColor(ThaiLifeTheme.textTertiary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .contentShape(Rectangle())
        .onTapGesture {
            onFlip()
        }
    }
}

// MARK: - Back of Root Word Family Card (Clean 2-Column Table View)

struct WordFamilyCardBack: View {
    let family: WordFamily
    let onFlip: () -> Void
    let onTapRootAudio: () -> Void
    let onTapMemberAudio: (WordFamilyMember) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Bar with Root Summary
                    HStack(alignment: .firstTextBaseline) {
                        Button(action: { onTapRootAudio() }) {
                            HStack(spacing: 10) {
                                Text(family.rootThai)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(ThaiLifeTheme.textPrimary)

                                Text(family.rootMeaningZhHans)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(ThaiLifeTheme.deepGreen)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(action: { onFlip() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10))
                                Text("翻回正面")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ThaiLifeTheme.deepGreen)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    // Usage Note Box
                    if !family.usageNote.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(ThaiLifeTheme.warning)
                                .font(.system(size: 13))
                            Text(family.usageNote)
                                .font(.system(size: 12))
                                .foregroundColor(ThaiLifeTheme.textSecondary)
                        }
                        .padding(10)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(8)
                    }

                    Divider()

                    // Multi-column List of Derived Words (Thai Pill | Chinese Meaning)
                    VStack(spacing: 12) {
                        ForEach(family.items) { member in
                            HStack(alignment: .center, spacing: 12) {
                                // Column 1: Thai Word Pill Button (Plays member audio, does NOT flip card)
                                Button(action: { onTapMemberAudio(member) }) {
                                    Text(member.thai)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(ThaiLifeTheme.deepGreen)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(ThaiLifeTheme.paleGreen.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(ThaiLifeTheme.paleGreen, lineWidth: 1.2)
                                        )
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                // Column 2: Chinese Meaning with Underline Accent
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(member.meaningZhHans)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(ThaiLifeTheme.textPrimary)

                                    Rectangle()
                                        .fill(ThaiLifeTheme.paleGreen)
                                        .frame(height: 2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}
