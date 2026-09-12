# 卡片反面例句发音 + 词块拆解 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CardBack 例句整句可点击发音；词块拆解仅展示不发音。

**Architecture:** 在 CardBack 新增 `onTapExample` 闭包参数，ReviewSessionViewModel 新增 `playExampleAudio` 方法。例句区加 `.onTapGesture` 触发发音。不修改 CardFront、AudioPlaybackService、数据模型。

**Tech Stack:** SwiftUI, AVSpeechSynthesizer (via AudioPlaybackService)

## Global Constraints

- 不修改 `ContentItem` 数据模型（`example`/`segments` 字段已存在）
- 不修改 `AudioPlaybackService` API
- 例句无数据时整个例句区不渲染（已有逻辑，保持不变）
- 词块拆解仅展示，不单独发音

---

### Task 1: ReviewSessionViewModel — 新增 playExampleAudio 方法

**Files:**
- Modify: `ThaiLife/Features/Review/ReviewSessionViewModel.swift:158-161`

**Interfaces:**
- Consumes: `currentItem: StudyQueueItem?` (已有), `AppState.audioService` (已有)
- Produces: `func playExampleAudio(appState: AppState)` — plays `item.example` via TTS

- [ ] **Step 1: Add playExampleAudio method**

在 `playAudio` 方法下方插入：

```swift
func playExampleAudio(appState: AppState) {
    guard let item = currentItem,
          let example = item.example,
          !example.isEmpty else { return }
    _ = appState.audioService.play(audioID: item.audioID + "-example", thaiText: example)
}
```

- [ ] **Step 2: Verify syntax**

```bash
swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) \
  -target arm64-apple-ios17.0-simulator \
  ThaiLife/Features/Review/ReviewSessionViewModel.swift 2>&1
```
Expected: exit 0（可能因模块依赖报类型缺失错误，只需确认没有语法错误）

- [ ] **Step 3: Commit**

```bash
git add ThaiLife/Features/Review/ReviewSessionViewModel.swift
git commit -m "feat: add playExampleAudio to ReviewSessionViewModel"
```

---

### Task 2: CardBack — 新增 onTapExample 参数 + 例句点按发音

**Files:**
- Modify: `ThaiLife/Features/Review/FlipCardView.swift:167-173` (CardBack struct params)
- Modify: `ThaiLife/Features/Review/FlipCardView.swift:248-258` (例句显示区)

**Interfaces:**
- Consumes: `CardBack` 已有参数 `item`, `layout`, `continuationPart`, `isContinuation`, `onTapThai`, `onRate`
- Produces: 新增参数 `let onTapExample: () -> Void`

- [ ] **Step 1: Add onTapExample parameter to CardBack**

将 CardBack struct 声明改为：

```swift
struct CardBack: View {
    let item: ContentItem
    let layout: ThaiTextLayout
    let continuationPart: Int
    let isContinuation: Bool
    let onTapThai: () -> Void
    let onTapExample: () -> Void
    let onRate: (String) -> Void
```

注意 `onTapExample` 插在 `onTapThai` 和 `onRate` 之间，保持回调参数相邻。

- [ ] **Step 2: Make example text tappable**

将例句区（`if let example = item.example, !example.isEmpty` 块内）的 `Text(example)` 改为可点击发音：

```swift
// Example
if let example = item.example, !example.isEmpty {
    VStack(alignment: .leading, spacing: 4) {
        Text("例句")
            .font(.caption.bold())
            .foregroundColor(ThaiLifeTheme.textTertiary)
        HStack(alignment: .top, spacing: 8) {
            Text(example)
                .font(.subheadline)
                .foregroundColor(ThaiLifeTheme.textSecondary)
                .contentShape(Rectangle())
                .onTapGesture { onTapExample() }

            Spacer()

            Button(action: onTapExample) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(ThaiLifeTheme.deepGreen)
                    .padding(6)
                    .background(ThaiLifeTheme.paleGreen.opacity(0.3))
                    .clipShape(Circle())
            }
        }
    }
}
```

关键改动：例句文字加 `.contentShape(Rectangle()).onTapGesture` + 右侧喇叭按钮，与上方泰语主词的发音 UI 一致。

- [ ] **Step 3: Verify syntax**

```bash
swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) \
  -target arm64-apple-ios17.0-simulator \
  ThaiLife/Features/Review/FlipCardView.swift 2>&1
```
Expected: exit 0（可能因模块依赖报类型缺失错误，确认无语法错误）

- [ ] **Step 4: Commit**

```bash
git add ThaiLife/Features/Review/FlipCardView.swift
git commit -m "feat: add onTapExample to CardBack, make example sentence tappable"
```

---

### Task 3: FlipCardView + ReviewSessionView — 接线 onTapExample

**Files:**
- Modify: `ThaiLife/Features/Review/FlipCardView.swift:35-42` (CardBack 实例化)
- Modify: `ThaiLife/Features/Review/ReviewSessionView.swift:85` (onTapThai 闭包)

**Interfaces:**
- Consumes: `ReviewSessionViewModel.playExampleAudio(appState:)` (Task 1), `CardBack.onTapExample` (Task 2)
- Produces: 完整的 call chain: 例句点击 → ViewModel → AudioPlaybackService

- [ ] **Step 1: FlipCardView 传递 onTapExample**

在 `FlipCardView.body` 中 CardBack 实例化处，添加 `onTapExample:` 参数。先找到 FlipCardView struct 的参数列表，确认外层是否已经有 `onTapExample` 传入。

FlipCardView 的声明：
```swift
struct FlipCardView: View {
    let item: ContentItem
    let isFlipped: Bool
    let direction: String
    let layout: ThaiTextLayout
    let continuationPart: Int
    let isContinuation: Bool
    let onTapThai: () -> Void
    let onFlip: () -> Void
    let onRate: (String) -> Void
```

添加：
```swift
    let onTapExample: () -> Void
```

在 CardBack 调用处（约第 35 行）添加 `onTapExample:` 参数：

```swift
CardBack(
    item: item,
    layout: layout,
    continuationPart: continuationPart,
    isContinuation: isContinuation,
    onTapThai: onTapThai,
    onTapExample: onTapExample,
    onRate: onRate
)
```

- [ ] **Step 2: ReviewSessionView 传入 onTapExample 闭包**

在 `ReviewSessionView.swift` 中 FlipCardView 实例化处（约第 81-88 行），添加 `onTapExample:` 参数：

```swift
FlipCardView(
    item: item,
    isFlipped: isFlipped,
    direction: direction,
    layout: layout,
    continuationPart: continuationPart,
    isContinuation: isContinuation,
    onTapThai: { viewModel.playAudio(appState: appState) },
    onTapExample: { viewModel.playExampleAudio(appState: appState) },
    onFlip: { ... },
    onRate: { ... }
)
```

（需根据实际代码调整，确认 `onFlip` 和 `onRate` 的现有写法并保持风格一致）

- [ ] **Step 3: Verify full chain with grep**

```bash
grep -n 'onTapExample' \
  ThaiLife/Features/Review/FlipCardView.swift \
  ThaiLife/Features/Review/ReviewSessionView.swift \
  ThaiLife/Features/Review/ReviewSessionViewModel.swift
```
Expected: 每处引用匹配 — CardBack 参数声明、CardBack body 中使用、FlipCardView 传递、ReviewSessionView 闭包、ViewModel 方法。

- [ ] **Step 4: Commit**

```bash
git add ThaiLife/Features/Review/FlipCardView.swift ThaiLife/Features/Review/ReviewSessionView.swift
git commit -m "feat: wire onTapExample from ReviewSessionView through FlipCardView to CardBack"
```
