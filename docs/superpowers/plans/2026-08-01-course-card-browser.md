# Course Card Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-FSRS, full-category card browser that opens at the item selected in a course list while preserving Thai-audio and favorite-row controls.

**Architecture:** Add a `courseBrowse(category:startContentID:)` route to the existing review screen. That route bypasses `StudyQueueBuilder` and initializes queue/cursor directly from bundled category content in source order. `ReviewSessionView` and `FlipCardView` receive an explicit browse-mode flag so browser navigation cannot display or call rating behavior.

**Tech Stack:** SwiftUI, SwiftData-backed `StudyStore`, existing `ContentRepository`, `ReviewSessionViewModel`, `AudioPlaybackService`, XCTest.

## Global Constraints

- Browser mode applies to every `ContentCategory` and uses every category item in bundled-content order.
- Browser mode must not read or write FSRS scheduling state, review logs, or review drafts.
- Thai text keeps headword playback; example playback stays one complete sentence through `playSentence` and `<audioID>-example`.
- The favorite button remains independent.
- Existing `.unit` “练习” sessions keep their current FSRS queue behavior.
- Do not add content or audio files.

---

### Task 1: Define and test the course-browser route

**Files:**
- Modify: `ThaiLife/Features/Review/ReviewSessionView.swift:3-38`
- Modify: `ThaiLife/Features/Review/ReviewSessionViewModel.swift:1-121`
- Test: `ThaiLifeTests/ReviewSessionViewModelTests.swift` (create if absent)

**Interfaces:**
- Produces: `ReviewSessionRoute.courseBrowse(category: ContentCategory, startContentID: String)`.
- Produces: `ReviewSessionRoute.isCourseBrowser: Bool` and `draftSource == nil` for the browse route.
- Produces: `ReviewSessionViewModel.loadSession(route:appState:)` direct browse initialization.

- [ ] **Step 1: Write failing route tests**

```swift
func testCourseBrowseRouteDoesNotHaveDraftSource() {
    let route = ReviewSessionRoute.courseBrowse(category: .basics, startContentID: "basics-word-003")
    XCTAssertNil(route.draftSource)
    XCTAssertTrue(route.isCourseBrowser)
}

func testCourseBrowseStartsAtRequestedItemAndKeepsCategoryOrder() {
    // Fixture order: basics-001, basics-002, basics-003.
    // Load route at basics-002 and assert cursor == 1 and all three entries remain in order.
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:
```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ThaiLifeTests/ReviewSessionViewModelTests test
```
Expected: failure because `courseBrowse` and its direct initialization path do not exist.

- [ ] **Step 3: Implement the route and direct browse initializer**

```swift
enum ReviewSessionRoute: Equatable {
    case daily
    case unit(String)
    case courseBrowse(category: ContentCategory, startContentID: String)
    // existing cases...

    var isCourseBrowser: Bool {
        if case .courseBrowse = self { return true }
        return false
    }
}
```

In `loadSession`, branch on `.courseBrowse` before draft restoration and `StudyQueueBuilder.makeQueue`. Filter bundled `items` by the supplied category without sorting, map every item to a `QueueItem`, set `cursor` to `firstIndex(where: { $0.contentID == startContentID }) ?? 0`, and call `updateCurrentItem()`.

- [ ] **Step 4: Run the focused test and confirm it passes**

Run the Task 1 command. Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add ThaiLife/Features/Review/ReviewSessionView.swift ThaiLife/Features/Review/ReviewSessionViewModel.swift ThaiLifeTests/ReviewSessionViewModelTests.swift
git commit -m "feat: add course card browser route"
```

### Task 2: Make list-row hit targets open the selected browser card

**Files:**
- Modify: `ThaiLife/Features/Catalog/UnitDetailView.swift:3-66`
- Test: `ThaiLifeTests/UnitDetailViewTests.swift` (create if absent, or add to existing catalog test file)

**Interfaces:**
- Consumes: `ReviewSessionRoute.courseBrowse(category:startContentID:)` from Task 1.
- Produces: `selectedBrowseItemID: String?` and browser navigation destination state.

- [ ] **Step 1: Write failing interaction/state tests**

```swift
func testSelectingListItemBuildsCourseBrowseRouteAtThatItem() {
    let route = UnitDetailView.browserRoute(category: .basics, itemID: "basics-word-003")
    XCTAssertEqual(route, .courseBrowse(category: .basics, startContentID: "basics-word-003"))
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:
```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ThaiLifeTests/UnitDetailViewTests test
```
Expected: failure because the route helper and selected item state do not exist.

- [ ] **Step 3: Implement row hit-target separation**

Add `@State private var selectedBrowseItemID: String?`. Keep `ThaiText` unchanged as the Thai-only audio target and keep the favorite `Button` unchanged. Wrap all non-control row content in a separate `Button`/gesture target that sets `selectedBrowseItemID = item.id`; do not attach that action to the ThaiText subtree or the favorite button. Add a navigation destination that constructs:

```swift
ReviewSessionView(
    route: .courseBrowse(category: category, startContentID: selectedBrowseItemID)
)
```

only when a selected ID exists. Keep the existing `showReview` destination for toolbar “练习”.

- [ ] **Step 4: Run the focused test and confirm it passes**

Run the Task 2 command. Expected: PASS.

- [ ] **Step 5: Commit Task 2**

```bash
git add ThaiLife/Features/Catalog/UnitDetailView.swift ThaiLifeTests/UnitDetailViewTests.swift
git commit -m "feat: open course browser from list rows"
```

### Task 3: Render browser controls without ratings

**Files:**
- Modify: `ThaiLife/Features/Review/ReviewSessionView.swift:31-134`
- Modify: `ThaiLife/Features/Review/FlipCardView.swift:37-335`
- Test: `ThaiLifeTests/ReviewSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `route.isCourseBrowser`.
- Produces: `FlipCardView` browser-mode configuration with no rating action and deterministic previous/next controls.

- [ ] **Step 1: Write failing browser-mode tests**

```swift
func testCourseBrowseNavigationDoesNotWriteReviewLogOrDraft() throws {
    // Start browse mode, move forward/back, then assert the store has no added review logs and no draft.
}

func testCourseBrowseKeepsFullCategoryCountInsteadOfDailyNewLimit() {
    // Use a category fixture with more than 10 items and assert queue.count equals all category items.
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run the Task 1 test command. Expected: failure because browse mode still exposes review-only behavior or uses review queue semantics.

- [ ] **Step 3: Implement browse UI and no-side-effect behavior**

Pass `isBrowsing: route.isCourseBrowser` into `FlipCardView`. In browse mode, replace the rating bar with explicit previous/next controls using existing `onSwipePrevious` / `onSwipeNext`; disable previous at `cursor == 0` and next at the final card. Do not call `viewModel.rate`, `saveDraft`, `clearDraft`, or completion UI for browse navigation. Keep flip, card counter, Thai audio, and example audio unchanged.

- [ ] **Step 4: Run the focused test and confirm it passes**

Run the Task 1 test command. Expected: PASS.

- [ ] **Step 5: Commit Task 3**

```bash
git add ThaiLife/Features/Review/ReviewSessionView.swift ThaiLife/Features/Review/FlipCardView.swift ThaiLife/Features/Review/ReviewSessionViewModel.swift ThaiLifeTests/ReviewSessionViewModelTests.swift
git commit -m "feat: add non-FSRS course card browser controls"
```

### Task 4: Regression verification and real-device smoke test

**Files:**
- Modify only if a failing regression test demonstrates a concrete defect.
- Test: `ThaiLifeTests/ReviewSessionViewModelTests.swift`, `ThaiLifeTests/UnitDetailViewTests.swift`

- [ ] **Step 1: Run focused course-browser tests**

Run:
```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ThaiLifeTests/ReviewSessionViewModelTests \
  -only-testing:ThaiLifeTests/UnitDetailViewTests test
```
Expected: PASS.

- [ ] **Step 2: Run existing audio and content checks**

Run:
```bash
python3 tools/validate_content.py
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ThaiLifeTests/AudioPlaybackServiceTests \
  -only-testing:ThaiLifeTests/ExampleSentencePlaybackTests test
```
Expected: content validation succeeds and all targeted tests pass.

- [ ] **Step 3: Build for the connected device**

Run:
```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -configuration Debug \
  -destination 'id=<connected-device-udid>' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Perform device smoke test**

On the connected device, verify for at least 开口基础 and 数字、时间与数量:

1. Thai text tap plays only headword audio.
2. Favorite tap changes favorite only.
3. Non-Thai/non-favorite row tap opens the expected card first.
4. Counter includes the whole category, including more than ten cards.
5. Previous/next and swipes remain inside the category without rating buttons.
6. Back returns to the same course list.
7. Toolbar “练习” still creates the FSRS session rather than browser mode.

- [ ] **Step 5: Commit Task 4**

```bash
git add ThaiLife/Features/Catalog/UnitDetailView.swift ThaiLife/Features/Review/ReviewSessionView.swift ThaiLife/Features/Review/ReviewSessionViewModel.swift ThaiLife/Features/Review/FlipCardView.swift ThaiLifeTests
git commit -m "test: cover course card browser navigation"
```
