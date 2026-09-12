# Thai Menu List and Favorites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a category-style Thai menu list with persistent favorites, surface menu favorites in the existing 收藏练习 page, and open menu cards at the selected item.

**Architecture:** Keep `ThaiMenuCard` separate from `ContentItem`. Reuse `StudyStore.FavoriteRecord.contentID` for both ID namespaces, add a `ThaiMenuListView`, and make the favorite presentation layer represent either a course item or a menu card. Menu browsing remains in `ThaiMenuBrowserView`; ordinary course review routes remain unchanged.

**Tech Stack:** SwiftUI, SwiftData, XCTest, existing `ContentRepository`, `StudyStore`, and navigation patterns in `UnitDetailView`/`FavoriteListView`.

## Global Constraints

- Menu cards must retain the existing full-card 3D flip and no-text-flash behavior.
- Menu IDs must remain the stable `ThaiMenuCard.id` values.
- Ordinary `ContentItem` favorite and review behavior must not regress.
- Ignore unrelated working-tree changes, including generated audio/resources and other projects.
- Use complete menu card data from `ContentRepository.loadThaiMenuReference()`; do not synthesize `ContentItem` values.

---

### Task 1: Add menu list navigation and selected-card browsing

**Files:**
- Create: `ThaiLife/Features/Catalog/ThaiMenuListView.swift`
- Modify: `ThaiLife/Features/Catalog/CatalogView.swift:11-25`
- Modify: `ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift:42-68, 197-205`
- Test: `ThaiLifeTests/ThaiMenuTests.swift` (add pure navigation/index tests if appropriate)

**Interfaces:**
- `ThaiMenuListView` consumes `AppState.store` and `ContentRepository.loadThaiMenuReference()`; produces navigation to `ThaiMenuBrowserView(startCardID:)` and favorite toggles through `StudyStore.toggleFavorite(contentID:)`.
- `ThaiMenuBrowserView` gains `init(startCardID: String? = nil)` and starts at the matching card ID, falling back to index 0.

- [ ] **Step 1: Write failing tests for start-card resolution.**

Add a pure helper on `ThaiMenuBrowserView` (or a file-private testable helper) with this contract:

```swift
static func initialIndex(cards: [ThaiMenuCard], startCardID: String?) -> Int {
    guard let startCardID,
          let index = cards.firstIndex(where: { $0.id == startCardID }) else { return 0 }
    return index
}
```

Test a matching ID and an unknown/nil ID in `ThaiLifeTests/ThaiMenuTests.swift`.

- [ ] **Step 2: Run the focused test and verify it fails.**

Run:

```bash
xcodebuild test -project ThaiLife.xcodeproj -scheme ThaiLife -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

Expected: the new helper tests fail because the helper/init does not exist yet.

- [ ] **Step 3: Implement the browser start-card initializer.**

Use a stored `let startCardID: String?`, keep the default initializer source-compatible, and set the index only after the reference is loaded:

```swift
struct ThaiMenuBrowserView: View {
    let startCardID: String?
    // existing @State properties...

    init(startCardID: String? = nil) {
        self.startCardID = startCardID
    }

    static func initialIndex(cards: [ThaiMenuCard], startCardID: String?) -> Int {
        guard let startCardID,
              let index = cards.firstIndex(where: { $0.id == startCardID }) else { return 0 }
        return index
    }

    private func load() {
        do {
            let loaded = try ContentRepository.loadThaiMenuReference()
            reference = loaded
            index = Self.initialIndex(cards: loaded.cards, startCardID: startCardID)
            isFlipped = false
        } catch {
            loadError = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Create the category-style menu list.**

Implement `ThaiMenuListView` with `@EnvironmentObject private var appState`, `@State` for `reference`, `favoriteIDs`, `loadError`, and `selectedCardID`. Load the reference and `allFavoriteIDs()` in `.task`/`.onAppear`. Group cards by their `category` while preserving first-seen category order. Each row must:

```swift
HStack(alignment: .top, spacing: 12) {
    VStack(alignment: .leading, spacing: 6) {
        Text(card.thai).font(.system(size: 20, weight: .bold))
        Text(card.meaningZhHans).font(.body).foregroundColor(ThaiLifeTheme.textSecondary)
    }
    Spacer()
    Button { toggleFavorite(card.id) } label: {
        Image(systemName: favoriteIDs.contains(card.id) ? "heart.fill" : "heart")
    }
    .buttonStyle(.borderless)
}
.contentShape(Rectangle())
.onTapGesture { selectedCardID = card.id }
```

Use `List` with `.listStyle(.plain)`, category `Section` headers, title “泰国常见菜单”, and the same error alert style as `UnitDetailView`. Ensure the heart button does not trigger row navigation.

- [ ] **Step 5: Change the Catalog destination.**

Replace the existing `ThaiMenuBrowserView()` navigation destination with `ThaiMenuListView().environmentObject(appState)`.

- [ ] **Step 6: Run focused menu tests and build.**

Run the Thai menu tests and Debug build; expected result is all focused tests pass and the app compiles.

- [ ] **Step 7: Commit the independently testable menu-list change.**

```bash
git add ThaiLife/Features/Catalog/CatalogView.swift ThaiLife/Features/Catalog/ThaiMenuListView.swift ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift ThaiLifeTests/ThaiMenuTests.swift
git commit -m "feat: add Thai menu list navigation"
```

---

### Task 2: Merge menu cards into 收藏练习 presentation

**Files:**
- Modify: `ThaiLife/Features/Review/FavoriteListPresentation.swift`
- Modify: `ThaiLife/Features/Review/FavoriteListView.swift`
- Test: `ThaiLifeTests/ContentValidatorTests.swift` (extend `FavoriteListPresentationTests`)

**Interfaces:**
- Add `FavoriteListEntry.Kind` (or an equivalent enum) with `.content(ContentItem)` and `.menu(ThaiMenuCard)`; preserve `id` and `favoritedAt`.
- Add `FavoriteListPresentation.sections(records:content:menuCards:now:calendar:)` returning mixed entries, while retaining the existing overload for ordinary-content callers/tests.
- `FavoriteListView` routes `.content` entries to `ReviewSessionView` and `.menu` entries to `ThaiMenuBrowserView(startCardID:)`.

- [ ] **Step 1: Add failing mixed-presentation tests.**

Extend `FavoriteListPresentationTests` with records containing one normal content ID, one menu ID, and one missing ID. Assert that the menu record is included, sorted by `favoritedAt`, grouped by date, and the missing ID is ignored. Assert the menu entry exposes its `ThaiMenuCard.id` and fields.

- [ ] **Step 2: Run the focused tests and verify failure.**

```bash
xcodebuild test -project ThaiLife.xcodeproj -scheme ThaiLife -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

Expected: compilation/test failure because the mixed overload and entry kind do not exist.

- [ ] **Step 3: Implement the mixed presentation model.**

Use an enum-backed entry without changing SwiftData:

```swift
enum FavoriteListEntryKind: Equatable {
    case content(ContentItem)
    case menu(ThaiMenuCard)
}

struct FavoriteListEntry: Identifiable, Equatable {
    let kind: FavoriteListEntryKind
    let favoritedAt: Date
    var id: String {
        switch kind {
        case .content(let item): return item.id
        case .menu(let card): return card.id
        }
    }
}
```

Implement mixed `orderedEntries`/`sections` by building dictionaries for content and menu cards, resolving each record against either dictionary, sorting newest first then ID, and grouping by `calendar.startOfDay`. Keep the existing content-only overload as a wrapper to minimize unrelated call-site changes.

- [ ] **Step 4: Update FavoriteListView state and navigation.**

Load `ThaiMenuReference` alongside `appState.contentItems`; retain a `[ThaiMenuCard]` state or a loaded reference. Call the mixed `sections` overload. Replace the content-only `FavoriteListRow` with a switch-based row renderer:

- `.content`: existing Thai audio button, meaning/example, browse callback, and remove callback.
- `.menu`: Thai text/meaning, browse callback setting a menu selection, and remove callback.

Add a `FavoriteBrowseSelection` kind that can represent either `contentID` or `menuCardID`, then use `navigationDestination(item:)` to construct either `ReviewSessionView(route: .favoriteBrowse(startContentID: ...))` or `ThaiMenuBrowserView(startCardID: ...)`. Do not send menu IDs into `ReviewSessionView`.

When removing an entry, update the relevant section locally by `entry.id`, preserving date sections and avoiding a full reload.

- [ ] **Step 5: Run focused presentation tests and build.**

Expected: existing content-only tests and new mixed favorite tests pass; Debug build succeeds.

- [ ] **Step 6: Commit the favorites integration.**

```bash
git add ThaiLife/Features/Review/FavoriteListPresentation.swift ThaiLife/Features/Review/FavoriteListView.swift ThaiLifeTests/ContentValidatorTests.swift
git commit -m "feat: include Thai menu cards in favorites"
```

---

### Task 3: Regression verification and device installation

**Files:**
- No new source files unless fixes are required by tests.

**Interfaces:**
- Validates Catalog → menu list → menu browser, menu favorite persistence, mixed 收藏练习 rendering, and unchanged course favorites.

- [ ] **Step 1: Run the full test suite.**

```bash
xcodebuild test -project ThaiLife.xcodeproj -scheme ThaiLife -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

Expected: all existing and new tests pass.

- [ ] **Step 2: Build for the configured simulator/device.**

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -configuration Debug \
  -destination 'id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Install and smoke-test navigation.**

Install the newly built app on simulator UUID `5BA5DF06-3574-4BF9-9A6A-2CAE00D81447`. Verify: Catalog menu opens list; tapping a row opens the corresponding card; heart toggles persist; 收藏练习 shows the menu favorite and opens that card; normal course favorites still open the course browser.

- [ ] **Step 4: Commit any test-only corrections and report verification.**

Use a focused commit only if a source fix was needed; do not stage unrelated generated resources or other project changes.
