# 收藏日期分组浏览 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将首页「收藏练习」改为按收藏日期分组且日期标题悬浮的列表；点击条目后从该条进入无 FSRS 副作用的收藏卡片浏览。

**Architecture:** 在持久化层把 `FavoriteRecord` 映射为稳定排序的值类型快照，在展示层以纯函数把快照与 bundle 内容合并、过滤无效 ID、按本地自然日分组。新增收藏列表页；`ReviewSessionViewModel` 增加与课程浏览平行的 `favoriteBrowse` 路由，通过同一快照排序装载卡片，不调用 FSRS、日志或草稿逻辑。

**Tech Stack:** Swift 5、SwiftUI、SwiftData、XCTest、现有 `ReviewSessionView`/`ReviewSessionViewModel` 卡片浏览框架。

## Global Constraints

- 保留 `FavoriteRecord.contentID` 与 `FavoriteRecord.favoritedAt` 的既有 SwiftData schema，不迁移、不删除孤立收藏记录。
- 分组以设备当前 `Calendar` 和本地时区的自然日计算；日期组、组内条目均按最新优先，时间相同时 `contentID` 升序。
- 首页收藏入口必须先到列表；课程浏览、日常复习、`.favorites` FSRS 队列和音频逻辑不得改变。
- `favoriteBrowse` 只能浏览有效收藏：不得显示评分、写 review log、改 FSRS、保存或恢复草稿。
- 悬浮日期标题必须使用 `LazyVStack(pinnedViews: [.sectionHeaders])`。
- 所有新 Swift 源与测试文件必须加入 `ThaiLife.xcodeproj/project.pbxproj` 的正确 group、Sources 或 test Sources build phase。
- 不重置、删除或覆盖工作区中的既有未提交功能和资源改动。

---

### Task 1: 收藏快照、稳定排序与日期展示模型

**Files:**
- Modify: `ThaiLife/Domain/StudyModels.swift:35-47`
- Modify: `ThaiLife/Data/StudyStore.swift:44-67`
- Create: `ThaiLife/Features/Review/FavoriteListPresentation.swift`
- Modify: `ThaiLife.xcodeproj/project.pbxproj`（新 source file 引用、Review group、app Sources）
- Modify: `ThaiLifeTests/StudyStoreTests.swift:39-45`
- Create: `ThaiLifeTests/FavoriteListPresentationTests.swift`
- Modify: `ThaiLife.xcodeproj/project.pbxproj`（新 test file 引用、ThaiLifeTests group、test Sources）

**Interfaces:**
- Produces `FavoriteSnapshot`, a value type with `contentID: String` and `favoritedAt: Date`.
- Produces `StudyStore.allFavorites() throws -> [FavoriteSnapshot]` sorted by newest `favoritedAt`, then ascending `contentID`.
- Produces `FavoriteListPresentation.sections(records:content:now:calendar:) -> [FavoriteDateSection]`.
- Produces `FavoriteDateSection` (`id` is start-of-day `Date`, `title: String`, `entries: [FavoriteListEntry]`) and `FavoriteListEntry` (`content: ContentItem`, `favoritedAt: Date`, `id == content.id`).
- Consumed by Tasks 2 and 3; do not expose SwiftData `FavoriteRecord` to SwiftUI views.

- [ ] **Step 1: Write failing persistence and presentation tests**

```swift
func testAllFavoritesSortsNewestFirstThenContentID() throws {
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    container.mainContext.insert(FavoriteRecord(contentID: "z", favoritedAt: timestamp))
    container.mainContext.insert(FavoriteRecord(contentID: "a", favoritedAt: timestamp))
    container.mainContext.insert(FavoriteRecord(contentID: "new", favoritedAt: timestamp.addingTimeInterval(1)))
    try container.mainContext.save()

    XCTAssertEqual(try store.allFavorites().map(\.contentID), ["new", "a", "z"])
}

func testSectionsGroupByLocalDaySortNewestFirstAndSkipMissingContent() {
    let calendar = Calendar(identifier: .gregorian)
    let now = date("2026-08-16 12:00")
    let sections = FavoriteListPresentation.sections(
        records: [
            .init(contentID: "today-earlier", favoritedAt: date("2026-08-16 08:00")),
            .init(contentID: "missing", favoritedAt: date("2026-08-16 11:00")),
            .init(contentID: "today-later", favoritedAt: date("2026-08-16 10:00")),
            .init(contentID: "yesterday", favoritedAt: date("2026-08-15 20:00")),
        ],
        content: [fixture("today-earlier"), fixture("today-later"), fixture("yesterday")],
        now: now,
        calendar: calendar
    )

    XCTAssertEqual(sections.map(\.title), ["今天 · 8月16日", "昨天 · 8月15日"])
    XCTAssertEqual(sections[0].entries.map(\.id), ["today-later", "today-earlier"])
}
```

Add test helpers directly in `FavoriteListPresentationTests` that create deterministic Gregorian dates in `Asia/Shanghai`, so title tests do not depend on the test machine date/time zone. Add a historical-date assertion for `"2026年8月14日"` and an equal-timestamp `contentID` tie assertion.

- [ ] **Step 2: Run the new tests to verify they fail**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -only-testing:ThaiLifeTests/StudyStoreTests/testAllFavoritesSortsNewestFirstThenContentID \
  -only-testing:ThaiLifeTests/FavoriteListPresentationTests \
  test
```

Expected: compilation failure because `FavoriteSnapshot`, `allFavorites()`, and `FavoriteListPresentation` do not yet exist.

- [ ] **Step 3: Implement the smallest persistence and presentation API**

In `StudyModels.swift`, add the non-persistent value type:

```swift
struct FavoriteSnapshot: Identifiable, Equatable, Sendable {
    let contentID: String
    let favoritedAt: Date

    var id: String { contentID }
}
```

In `StudyStore.swift`, add:

```swift
func allFavorites() throws -> [FavoriteSnapshot] {
    let descriptor = FetchDescriptor<FavoriteRecord>(
        sortBy: [
            SortDescriptor(\.favoritedAt, order: .reverse),
            SortDescriptor(\.contentID)
        ]
    )
    return try context.fetch(descriptor).map {
        FavoriteSnapshot(contentID: $0.contentID, favoritedAt: $0.favoritedAt)
    }
}
```

Keep `allFavoriteIDs()` for the existing `.favorites` FSRS route; implement it by mapping `allFavorites()` so both paths share deterministic storage ordering.

In `FavoriteListPresentation.swift`, implement the three value types and a pure `sections` function that:

```swift
let itemByID = Dictionary(uniqueKeysWithValues: content.map { ($0.id, $0) })
let validEntries = records.compactMap { record in
    itemByID[record.contentID].map {
        FavoriteListEntry(content: $0, favoritedAt: record.favoritedAt)
    }
}
```

Sort `validEntries` with later `favoritedAt` first and `content.id` ascending on ties. Group with `calendar.startOfDay(for:)`, sort group dates descending, and call a dedicated `dateTitle(for:now:calendar:)` that returns exactly the spec strings. No view code or navigation in this task.

For the store test, insert `FavoriteRecord(contentID:favoritedAt:)` directly through the existing in-memory `container.mainContext` and save it; do not add a production-only insertion API.

- [ ] **Step 4: Run focused tests to verify they pass**

Run the command from Step 2. Expected: all selected tests pass, including deterministic today/yesterday/history, tie-break and missing-content coverage.

- [ ] **Step 5: Commit the focused data-model change**

```bash
git add ThaiLife/Domain/StudyModels.swift ThaiLife/Data/StudyStore.swift \
  ThaiLife/Features/Review/FavoriteListPresentation.swift \
  ThaiLifeTests/StudyStoreTests.swift ThaiLifeTests/FavoriteListPresentationTests.swift \
  ThaiLife.xcodeproj/project.pbxproj
git commit -m "feat: model favorite date sections"
```

### Task 2: 按日期分组且标题悬浮的收藏列表页

**Files:**
- Create: `ThaiLife/Features/Review/FavoriteListView.swift`
- Modify: `ThaiLife.xcodeproj/project.pbxproj`（新 view 引用、Review group、app Sources）
- Create: `ThaiLifeTests/FavoriteListViewTests.swift`
- Modify: `ThaiLife.xcodeproj/project.pbxproj`（新 test 引用、ThaiLifeTests group、test Sources）

**Interfaces:**
- Consumes `FavoriteSnapshot`, `StudyStore.allFavorites()`, `FavoriteListPresentation`, and `AppState.contentItems` from Task 1.
- Produces `FavoriteListView` and `FavoriteListView.browserRoute(contentID:) -> ReviewSessionRoute`.
- Produces a read-only grouped list with `FavoriteDateSection` header values and `NavigationLink` destinations.
- Task 3 consumes `FavoriteListView.browserRoute(contentID:)` and defines the returned `favoriteBrowse` route case.

- [ ] **Step 1: Write failing list-view and route tests**

```swift
func testFavoriteListRouteStartsBrowseAtTappedContent() {
    XCTAssertEqual(
        FavoriteListView.browserRoute(contentID: "sentence-001"),
        .favoriteBrowse(startContentID: "sentence-001")
    )
}

func testFavoriteListUsesPinnedDateSectionHeaders() throws {
    let source = try String(contentsOfFile: sourcePath("ThaiLife/Features/Review/FavoriteListView.swift"))
    XCTAssertTrue(source.contains("LazyVStack(pinnedViews: [.sectionHeaders])"))
    XCTAssertTrue(source.contains("Section"))
}
```

The source-shape assertion is intentional: SwiftUI does not expose the pinned-header modifier as a value that XCTest can inspect. Keep behavioral grouping coverage in `FavoriteListPresentationTests` from Task 1.

- [ ] **Step 2: Run the new tests to verify they fail**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -only-testing:ThaiLifeTests/FavoriteListViewTests \
  test
```

Expected: compilation failure because `FavoriteListView` and `.favoriteBrowse` do not yet exist.

- [ ] **Step 3: Implement the list view with a single load boundary**

Implement `FavoriteListView` with `@EnvironmentObject private var appState: AppState`, `@State private var sections: [FavoriteDateSection]`, and `@State private var loadError: String?`. On `.task` (or equivalent first appearance):

```swift
guard let store = appState.store else {
    loadError = "学习数据服务暂不可用"
    sections = []
    return
}
do {
    sections = FavoriteListPresentation.sections(
        records: try store.allFavorites(),
        content: appState.contentItems,
        now: Date(),
        calendar: .current
    )
} catch {
    loadError = error.localizedDescription
    sections = []
}
```

Render non-empty content exactly through:

```swift
ScrollView {
    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
        ForEach(sections) { section in
            Section {
                ForEach(section.entries) { entry in
                    NavigationLink(destination: ReviewSessionView(
                        route: Self.browserRoute(contentID: entry.id)
                    ).environmentObject(appState)) {
                        FavoriteListRow(item: entry.content)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                FavoriteDateHeader(title: section.title)
            }
        }
    }
}
```

Use the same Thai/Chinese typography, row padding, colors, background and full-row tap affordance as `UnitDetailView.ContentRow`, but do not include the course row’s favorite-toggle control: this page is a navigation list. Give the page navigation title `收藏练习`. Render `暂无收藏内容` for zero valid sections and a separate concise error message when `loadError != nil`.

Add the static route helper:

```swift
static func browserRoute(contentID: String) -> ReviewSessionRoute {
    .favoriteBrowse(startContentID: contentID)
}
```

- [ ] **Step 4: Run focused tests to verify they pass**

Run the Task 2 Step 2 command plus Task 1 presentation tests. Expected: all pass and no Course UI tests regress.

- [ ] **Step 5: Commit the list UI**

```bash
git add ThaiLife/Features/Review/FavoriteListView.swift \
  ThaiLifeTests/FavoriteListViewTests.swift ThaiLife.xcodeproj/project.pbxproj
git commit -m "feat: add date-grouped favorite list"
```

### Task 3: 收藏卡片浏览路由、首页入口与无副作用保护

**Files:**
- Modify: `ThaiLife/Features/Review/ReviewSessionView.swift:3-30, 32-150`
- Modify: `ThaiLife/Features/Review/ReviewSessionViewModel.swift:20-205`
- Modify: `ThaiLife/Features/Today/TodayView.swift:84-92`
- Modify: `ThaiLifeTests/ReviewSessionViewModelTests.swift:1-225`
- Modify: `ThaiLifeTests/TodayViewModelTests.swift` 或 Create: `ThaiLifeTests/FavoriteListNavigationTests.swift`

**Interfaces:**
- Consumes `FavoriteListView.browserRoute(contentID:)`, `StudyStore.allFavorites()`, and `FavoriteListPresentation` from Tasks 1–2.
- Produces `ReviewSessionRoute.favoriteBrowse(startContentID:)` and a renamed/generalized `isCardBrowser` route property covering both course and favorite browse modes.
- Produces `ReviewSessionViewModel.loadSession(route:appState:favoriteSnapshotsLoader:)` handling `favoriteBrowse` before FSRS replay and draft restoration.

- [ ] **Step 1: Write failing browser and entry-point tests**

```swift
func testFavoriteBrowseStartsAtTappedFavoriteAndUsesFavoriteDateOrder() throws {
    appState.contentItems = [fixture("old"), fixture("selected"), fixture("new")]
    let records = [
        FavoriteSnapshot(contentID: "old", favoritedAt: date("2026-08-14 09:00")),
        FavoriteSnapshot(contentID: "selected", favoritedAt: date("2026-08-15 09:00")),
        FavoriteSnapshot(contentID: "new", favoritedAt: date("2026-08-16 09:00")),
    ]

    viewModel.loadSession(
        route: .favoriteBrowse(startContentID: "selected"),
        appState: appState,
        favoriteSnapshotsLoader: { _ in records }
    )

    XCTAssertEqual(viewModel.queue.map(\.contentID), ["new", "selected", "old"])
    XCTAssertEqual(viewModel.cursor, 1)
    XCTAssertEqual(viewModel.currentItem?.id, "selected")
}

func testFavoriteBrowseDoesNotWriteLogsOrDraft() throws {
    viewModel.loadSession(route: .favoriteBrowse(startContentID: "favorite-1"), appState: appState, favoriteSnapshotsLoader: { _ in records })
    viewModel.rate("good", appState: appState)
    viewModel.goBack(appState: appState)

    XCTAssertTrue(try store.allLogs().isEmpty)
    XCTAssertNil(try store.restoreDraft())
}
```

Also add tests for invalid/missing start ID resulting in an empty state, orphan favorite filtering, all favorites not being limited by daily-new policy, and next-card behavior at the last favorite browse card. Add an entry-point source/route test asserting `TodayView` navigates to `FavoriteListView` instead of constructing `ReviewSessionView(route: .favorites)`.

- [ ] **Step 2: Run the new tests to verify they fail**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -only-testing:ThaiLifeTests/ReviewSessionViewModelTests \
  -only-testing:ThaiLifeTests/FavoriteListNavigationTests \
  test
```

Expected: compilation failure because `favoriteBrowse` and its injection point are absent.

- [ ] **Step 3: Implement the browse route without FSRS side effects**

In `ReviewSessionRoute`, add:

```swift
case favoriteBrowse(startContentID: String)
```

Replace `isCourseBrowser` with `isCardBrowser`, returning true for `.courseBrowse` and `.favoriteBrowse`. Make its `draftSource` nil and ensure it does not accept a draft source. Update all browser-specific UI, completion copy, rating visibility and `goToNext()` checks to use `isCardBrowser` so favorite browsing has the exact card-navigation affordance of course browsing.

Extend `loadSession` with a defaultable test seam:

```swift
favoriteSnapshotsLoader: @MainActor (StudyStore) throws -> [FavoriteSnapshot] = { try $0.allFavorites() }
```

After confirming `appState.store`, but **before** loading logs, settings, replaying FSRS, or reading drafts, handle `.favoriteBrowse`:

```swift
if case .favoriteBrowse(let startContentID) = route {
    do {
        let favoriteItems = FavoriteListPresentation.orderedEntries(
            records: try favoriteSnapshotsLoader(store),
            content: items
        ).map(\.content)
        guard let startIndex = favoriteItems.firstIndex(where: { $0.id == startContentID }) else {
            queue = []; cursor = 0; currentItem = nil; return
        }
        let now = Date()
        queue = favoriteItems.map {
            .init(id: $0.id, contentID: $0.id, state: .new, due: now, reason: "browse")
        }
        cursor = startIndex
        updateCurrentItem()
    } catch {
        loadError = error.localizedDescription
        queue = []; cursor = 0; currentItem = nil
    }
    return
}
```

Factor `orderedEntries(records:content:)` out of `sections` so Task 2’s list and this route have one shared filtering/sorting implementation. Guard `rate(_:appState:)` with `guard !currentRoute.isCardBrowser` before accessing the store or creating a log. In `goBack(appState:)`, immediately return for card-browser routes. This prevents future UI regressions from creating FSRS effects even if a rating control is accidentally surfaced.

Update `TodayView`:

```swift
NavigationLink(destination: FavoriteListView().environmentObject(appState)) {
    QuickLinkRow(icon: "heart.fill", title: "收藏练习", subtitle: "只复习已收藏的内容")
}
```

The existing `.favorites` switch branch and queue policy remain unchanged for backwards compatibility.

- [ ] **Step 4: Run focused tests to verify they pass**

Run the Task 3 Step 2 command, then:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -only-testing:ThaiLifeTests/ReviewSessionRouteTests \
  -only-testing:ThaiLifeTests/UnitDetailViewTests \
  test
```

Expected: favorite browse loads in shared date order at selected content, has no logs/drafts, and course browser plus existing favorites route tests remain green.

- [ ] **Step 5: Commit route and entry-point integration**

```bash
git add ThaiLife/Features/Review/ReviewSessionView.swift \
  ThaiLife/Features/Review/ReviewSessionViewModel.swift \
  ThaiLife/Features/Today/TodayView.swift \
  ThaiLifeTests/ReviewSessionViewModelTests.swift \
  ThaiLifeTests/FavoriteListNavigationTests.swift
git commit -m "feat: browse favorites from date list"
```

### Task 4: Complete validation and real-device verification

**Files:**
- Modify only files required by test failures discovered in this task.
- Do not edit content files, audio manifest, or audio resources unless a directly related build error proves it necessary.

**Interfaces:**
- Consumes all Tasks 1–3 outputs.
- Produces passing simulator tests and a signed debug app on the already connected iPhone.

- [ ] **Step 1: Run the complete simulator suite**

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  test
```

Expected: `** TEST SUCCEEDED **`. If any unrelated existing test fails, isolate it before editing and do not weaken the test.

- [ ] **Step 2: Check the focused change set**

```bash
git diff --check
git status --short
git diff -- ThaiLife/Domain/StudyModels.swift ThaiLife/Data/StudyStore.swift \
  ThaiLife/Features/Review/FavoriteListPresentation.swift \
  ThaiLife/Features/Review/FavoriteListView.swift \
  ThaiLife/Features/Review/ReviewSessionView.swift \
  ThaiLife/Features/Review/ReviewSessionViewModel.swift ThaiLife/Features/Today/TodayView.swift
```

Expected: no whitespace errors; review only feature files, while preserving pre-existing uncommitted work.

- [ ] **Step 3: Build with the current personal Team and install**

Use the current connected CoreDevice ID `817BCF39-0C17-55EB-8E3D-6F8194CEF388` and the current Xcode Personal Team `VSASLV4YAL` without modifying project signing settings:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -configuration Debug \
  -destination 'id=817BCF39-0C17-55EB-8E3D-6F8194CEF388' \
  -derivedDataPath build/DeviceDerivedDataFavoriteDateList \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=VSASLV4YAL CODE_SIGN_STYLE=Automatic build

xcrun devicectl device install app \
  --device 817BCF39-0C17-55EB-8E3D-6F8194CEF388 \
  build/DeviceDerivedDataFavoriteDateList/Build/Products/Debug-iphoneos/ThaiLife.app

xcrun devicectl device process launch \
  --device 817BCF39-0C17-55EB-8E3D-6F8194CEF388 \
  com.yaohuix.ThaiLife
```

Expected: build and install succeed. If iOS rejects launch because the newly signed Personal Team profile is not trusted, report the exact device-side trust action; do not alter application code or signing settings to work around it.

- [ ] **Step 4: Manually smoke-test on device**

Verify: (1) 首页收藏练习先到列表；(2) 两天以上的收藏有独立日期组；(3) 上滑时日期标题悬浮、到下一日期时切换；(4) 点一条后从该条显示卡片；(5) 左右切换覆盖全部收藏；(6) 卡片无评分按钮、无复习完成写入；(7) 音频和返回列表正常。

- [ ] **Step 5: Commit only implementation files created or changed for this feature**

```bash
git add ThaiLife/Domain/StudyModels.swift ThaiLife/Data/StudyStore.swift \
  ThaiLife/Features/Review/FavoriteListPresentation.swift \
  ThaiLife/Features/Review/FavoriteListView.swift \
  ThaiLife/Features/Review/ReviewSessionView.swift \
  ThaiLife/Features/Review/ReviewSessionViewModel.swift ThaiLife/Features/Today/TodayView.swift \
  ThaiLifeTests/StudyStoreTests.swift ThaiLifeTests/FavoriteListPresentationTests.swift \
  ThaiLifeTests/FavoriteListViewTests.swift ThaiLifeTests/FavoriteListNavigationTests.swift \
  ThaiLifeTests/ReviewSessionViewModelTests.swift ThaiLife.xcodeproj/project.pbxproj
git commit -m "feat: add favorite date-grouped browser"
```

Do not stage unrelated existing content, audio, dialogue, card, or parent-workspace changes.
