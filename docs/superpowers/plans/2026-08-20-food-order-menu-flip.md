# 饮食水果排序与菜单翻卡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Place all fruit vocabulary immediately after the base-food vocabulary and before drink vocabulary in the 饮食与点餐 course, and make 泰国常见菜单 cards perform a true one-visible-face-at-a-time 3D flip.

**Architecture:** The content generator remains the sole writer of `items.json` and `content-manifest.json`. A deterministic food-dining ordering helper will preserve item field values and IDs while producing three word sections: base food, fruit, then drink. The menu browser will replace its rotating two-sided `ZStack` with two independently rotated, animatable faces that explicitly hide their back-facing surface at and beyond 90°.

**Tech Stack:** Python 3 content generator and JSON fixtures; Swift 5.10; SwiftUI; XCTest; Xcode/iOS Simulator.

## Global Constraints

- `ThaiLife/Resources/Content/items.json` and `content-manifest.json` are generated artifacts; do not manually edit either file.
- Preserve all content item IDs, Thai text, Chinese meanings, tags, examples, example translations, audio IDs, prerequisite IDs, and audio resources.
- Treat every `ContentItem.example` as a complete sentence; do not derive example text, translation, or audio from segments.
- Do not create, remove, rename, or regenerate audio files for this ordering-only change.
- Menu front: image, category, Thai name, Chinese name. Menu back: Thai name, Chinese name, breakdown.
- A menu card must show only its viewer-facing side; the back-facing side must not overlap or expose mirrored text during the 3D animation.
- Retain existing gestures: tap toggles the face, horizontal drag changes cards, vertical drag remains available to the back-side scroll view, and card navigation resets the card to its front side.

---

## File Structure

| File | Responsibility |
|---|---|
| `tools/generate_content.py` | Define stable section-ID order and apply it after the 18 extra food-dining words are created, before JSON serialization. |
| `tools/test_content_pipeline.py` | Exercise the generator with its real baseline and prove the food-dining word sequence has base food → fruit → drinks without changing IDs or fields. |
| `ThaiLife/Resources/Content/items.json` | Generated course payload with the reordered `food_dining` entries. |
| `ThaiLife/Resources/Content/content-manifest.json` | Generated checksum and generation timestamp for the reordered payload. |
| `ThaiLifeTests/ContentAcceptanceTests.swift` | Assert the bundled-app ordering contract so a future generator change cannot put fruits back at the bottom. |
| `ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift` | Define the reusable 3D face-culling modifier and compose the menu card from independently rotating front/back faces. |
| `ThaiLifeTests/ThaiMenuFlipTests.swift` | Unit-test the pure facing-direction logic used to cull the back-facing surface. |

## Task 1: Lock the course ordering contract with failing generator and bundle tests

**Files:**
- Modify: `tools/test_content_pipeline.py`
- Modify: `ThaiLifeTests/ContentAcceptanceTests.swift`

**Interfaces:**
- Consumes: `generate_to_paths(source, coverage, output_root)` from `tools/generate_content.py`; `ContentRepository.loadBundled()` from `ThaiLife/Data/ContentRepository.swift`.
- Produces: A specified ID-order contract for the first three word sections of the `food_dining` category, used by Task 2.

- [ ] **Step 1: Add a failing Python generator-order test**

Add this test to `tools/test_content_pipeline.py`. It must generate into a temporary output root using the repository’s current bundled content as the baseline (copy `ThaiLife/Resources/Content/items.json` into the temporary root first), then decode the generated JSON.

```python
def test_food_dining_words_are_grouped_as_base_food_then_fruit_then_drinks(tmp_path: Path):
    output_root = tmp_path
    content_dir = output_root / "ThaiLife" / "Resources" / "Content"
    content_dir.mkdir(parents=True)
    shutil.copy(ROOT / "ThaiLife/Resources/Content/items.json", content_dir / "items.json")

    generate_to_paths(load_example_source(), load_example_coverage(), output_root)
    items = json.loads((content_dir / "items.json").read_text(encoding="utf-8"))
    word_ids = [
        item["id"] for item in items
        if item["category"] == "food_dining" and item["kind"] == "word"
    ]

    expected_prefix = [
        "food_dining-word-001", "food_dining-word-003", "food_dining-word-005",
        "food_dining-word-006", "food_dining-word-007", "food_dining-word-008",
        "food_dining-word-009", "food_dining-word-010",
        "food_dining-word-004",
        "food_dining-word-060", "food_dining-word-061", "food_dining-word-062",
        "food_dining-word-063", "food_dining-word-064", "food_dining-word-065",
        "food_dining-word-066", "food_dining-word-067", "food_dining-word-068",
        "food_dining-word-069",
        "food_dining-word-002", "food_dining-word-030", "food_dining-word-031",
        "food_dining-word-032", "food_dining-word-033", "food_dining-word-034",
        "food_dining-word-035", "food_dining-word-070", "food_dining-word-071",
        "food_dining-word-072", "food_dining-word-073", "food_dining-word-074",
        "food_dining-word-075",
    ]

    assert word_ids[:len(expected_prefix)] == expected_prefix
    assert [item["id"] for item in items if item["id"] == "food_dining-word-060"] == ["food_dining-word-060"]
```

Add missing imports at the top of the file:

```python
import shutil
from pathlib import Path
```

Use the existing test module’s import style for `ROOT`, `generate_to_paths`, `load_example_source`, and `load_example_coverage`; do not duplicate their definitions.

- [ ] **Step 2: Run the Python test and verify it fails**

Run:

```bash
.venv/bin/python -m unittest tools.test_content_pipeline.ContentPipelineTests.test_food_dining_words_are_grouped_as_base_food_then_fruit_then_drinks
```

Expected: failure because `food_dining-word-060` through `food_dining-word-075` are currently appended after the existing 1,200-item payload, so the fruit section is not after the base-food section.

- [ ] **Step 3: Add a failing bundled-content XCTest**

Add this method to `ThaiLifeTests/ContentAcceptanceTests.swift`:

```swift
func testFoodDiningPlacesFruitImmediatelyAfterBaseFoodAndBeforeDrinks() throws {
    let words = try ContentRepository.loadBundled().filter {
        $0.category == .foodDining && $0.kind == .word
    }
    let ids = words.map(\.id)
    let expectedPrefix = [
        "food_dining-word-001", "food_dining-word-003", "food_dining-word-005",
        "food_dining-word-006", "food_dining-word-007", "food_dining-word-008",
        "food_dining-word-009", "food_dining-word-010",
        "food_dining-word-004",
        "food_dining-word-060", "food_dining-word-061", "food_dining-word-062",
        "food_dining-word-063", "food_dining-word-064", "food_dining-word-065",
        "food_dining-word-066", "food_dining-word-067", "food_dining-word-068",
        "food_dining-word-069",
        "food_dining-word-002", "food_dining-word-030", "food_dining-word-031",
        "food_dining-word-032", "food_dining-word-033", "food_dining-word-034",
        "food_dining-word-035", "food_dining-word-070", "food_dining-word-071",
        "food_dining-word-072", "food_dining-word-073", "food_dining-word-074",
        "food_dining-word-075"
    ]

    XCTAssertEqual(Array(ids.prefix(expectedPrefix.count)), expectedPrefix)
}
```

- [ ] **Step 4: Run the focused XCTest and verify it fails**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:ThaiLifeTests/ContentAcceptanceTests/testFoodDiningPlacesFruitImmediatelyAfterBaseFoodAndBeforeDrinks \
  test
```

Expected: failure at the expected-prefix assertion because the bundled generated JSON still has fruits at the end of the food-dining category.

- [ ] **Step 5: Commit the red tests**

```bash
git add tools/test_content_pipeline.py ThaiLifeTests/ContentAcceptanceTests.swift
git commit -m "test: specify food and drink vocabulary order"
```

## Task 2: Generate the base-food → fruit → drinks sequence without changing content fields

**Files:**
- Modify: `tools/generate_content.py:434-462`
- Modify: `ThaiLife/Resources/Content/items.json` (generated)
- Modify: `ThaiLife/Resources/Content/content-manifest.json` (generated)

**Interfaces:**
- Consumes: `EXTRA_FOOD_DINING_WORDS`, `append_extra_food_dining_words(items:)`, and `generate_to_paths(...)`.
- Produces: `reorder_food_dining_items(_:) -> list[dict]`, invoked by `append_extra_food_dining_words`, which returns the original item dictionaries in the approved sequence.

- [ ] **Step 1: Implement exact section identifiers and the ordering helper**

In `tools/generate_content.py`, immediately below `EXTRA_FOOD_DINING_WORDS`, define these constants and helper:

```python
FOOD_DINING_BASE_FOOD_WORD_IDS = [
    "food_dining-word-001", "food_dining-word-003", "food_dining-word-005",
    "food_dining-word-006", "food_dining-word-007", "food_dining-word-008",
    "food_dining-word-009", "food_dining-word-010",
]
FOOD_DINING_FRUIT_WORD_IDS = [
    "food_dining-word-004",
    "food_dining-word-060", "food_dining-word-061", "food_dining-word-062",
    "food_dining-word-063", "food_dining-word-064", "food_dining-word-065",
    "food_dining-word-066", "food_dining-word-067", "food_dining-word-068",
    "food_dining-word-069",
]
FOOD_DINING_DRINK_WORD_IDS = [
    "food_dining-word-002", "food_dining-word-030", "food_dining-word-031",
    "food_dining-word-032", "food_dining-word-033", "food_dining-word-034",
    "food_dining-word-035", "food_dining-word-070", "food_dining-word-071",
    "food_dining-word-072", "food_dining-word-073", "food_dining-word-074",
    "food_dining-word-075",
]


def reorder_food_dining_items(items: list[dict]) -> list[dict]:
    food_items = [item for item in items if item["category"] == "food_dining"]
    food_by_id = {item["id"]: item for item in food_items}
    section_ids = (
        FOOD_DINING_BASE_FOOD_WORD_IDS
        + FOOD_DINING_FRUIT_WORD_IDS
        + FOOD_DINING_DRINK_WORD_IDS
    )
    missing_ids = [item_id for item_id in section_ids if item_id not in food_by_id]
    if missing_ids:
        raise ValueError(f"food-dining ordering IDs are missing: {missing_ids}")

    prioritized = [food_by_id[item_id] for item_id in section_ids]
    remaining_food = [item for item in food_items if item["id"] not in set(section_ids)]
    ordered_food = prioritized + remaining_food

    first_food_index = next(
        index for index, item in enumerate(items) if item["category"] == "food_dining"
    )
    non_food_items = [item for item in items if item["category"] != "food_dining"]
    return non_food_items[:first_food_index] + ordered_food + non_food_items[first_food_index:]
```

Build the `section_id_set = set(section_ids)` once before calculating `remaining_food` so the membership expression is deterministic and does not allocate a set for each item:

```python
section_id_set = set(section_ids)
remaining_food = [item for item in food_items if item["id"] not in section_id_set]
```

- [ ] **Step 2: Invoke the helper after all extra words have been appended**

Replace the final `return items` in `append_extra_food_dining_words` with:

```python
return reorder_food_dining_items(items)
```

This preserves every existing dictionary object and only changes its position. It also moves all 18 extra words from the tail of the global list into the food-dining block, before the next category begins.

- [ ] **Step 3: Run the focused Python test and verify it passes**

Run:

```bash
.venv/bin/python -m unittest tools.test_content_pipeline.ContentPipelineTests.test_food_dining_words_are_grouped_as_base_food_then_fruit_then_drinks
```

Expected: PASS.

- [ ] **Step 4: Regenerate the tracked content artifacts**

Run:

```bash
.venv/bin/python tools/generate_content.py
python3 tools/validate_content.py
```

Expected: the generator reports 1,200 base items plus the current extras and writes `items.json` and `content-manifest.json`; the validator reports a matching manifest checksum and valid content.

- [ ] **Step 5: Run the focused bundled XCTest and verify it passes**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:ThaiLifeTests/ContentAcceptanceTests/testFoodDiningPlacesFruitImmediatelyAfterBaseFoodAndBeforeDrinks \
  test
```

Expected: PASS.

- [ ] **Step 6: Commit the generator and generated payload**

```bash
git add tools/generate_content.py \
  ThaiLife/Resources/Content/items.json \
  ThaiLife/Resources/Content/content-manifest.json
git commit -m "fix: group fruit vocabulary before drinks"
```

## Task 3: Define and test back-face culling for the menu card

**Files:**
- Create: `ThaiLifeTests/ThaiMenuFlipTests.swift`
- Modify: `ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift:1-10`

**Interfaces:**
- Produces: `ThaiMenuCardFace.isFacingViewer(at: Double) -> Bool` with an inclusive hiding boundary at -90° and 90°.
- Consumes: the function in `ThaiMenuCardFaceModifier`, introduced in Task 4.

- [ ] **Step 1: Write the failing face-direction XCTest**

Create `ThaiLifeTests/ThaiMenuFlipTests.swift`:

```swift
@testable import ThaiLife
import XCTest

final class ThaiMenuFlipTests: XCTestCase {
    func testFaceIsVisibleOnlyWhileItsRotationFacesTheViewer() {
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: 0))
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: 89.9))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: 90))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: 180))
        XCTAssertFalse(ThaiMenuCardFace.isFacingViewer(at: -90))
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: -89.9))
        XCTAssertTrue(ThaiMenuCardFace.isFacingViewer(at: 360))
    }
}
```

- [ ] **Step 2: Run the focused XCTest and verify it fails to compile**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:ThaiLifeTests/ThaiMenuFlipTests/testFaceIsVisibleOnlyWhileItsRotationFacesTheViewer \
  test
```

Expected: compiler error because `ThaiMenuCardFace` does not exist yet.

- [ ] **Step 3: Commit the red test**

```bash
git add ThaiLifeTests/ThaiMenuFlipTests.swift
git commit -m "test: define Thai menu face visibility"
```

## Task 4: Render menu faces independently and cull the hidden face during animation

**Files:**
- Modify: `ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift:1-104`
- Modify: `ThaiLifeTests/ThaiMenuFlipTests.swift`

**Interfaces:**
- Consumes: `ThaiMenuCardFace.isFacingViewer(at:)` from Task 3 and existing `menuCardFront(_:)`, `menuCardBack(_:)`, `isFlipped`, `next()`, and `previous()`.
- Produces: `ThaiMenuCardFaceModifier: AnimatableModifier`, which has `var rotation: Double`, animates that value through `animatableData`, rotates one face, and hides it when its local rotation is not viewer-facing.

- [ ] **Step 1: Add the face-direction type and animatable modifier**

Immediately after `import SwiftUI`, add this internal type and private modifier:

```swift
enum ThaiMenuCardFace {
    static func isFacingViewer(at rotation: Double) -> Bool {
        let normalized = rotation.truncatingRemainder(dividingBy: 360)
        return normalized > -90 && normalized < 90
    }
}

private struct ThaiMenuCardFaceModifier: AnimatableModifier {
    var rotation: Double

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(ThaiMenuCardFace.isFacingViewer(at: rotation) ? 1 : 0)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
    }
}
```

The boundary is deliberately hidden at exactly ±90°. At that angle the face is edge-on; hiding it prevents a one-frame overlap as SwiftUI interpolates the two face rotations.

- [ ] **Step 2: Replace the current whole-stack rotation with two local rotations**

In `menuCard(_:)`, replace the current `ZStack` and the outer `.rotation3DEffect(...)` with this face composition. Retain the existing background, clip, shadow, tap gesture, drag gesture, offset, and drag-offset animation:

```swift
ZStack {
    menuCardFront(card)
        .modifier(ThaiMenuCardFaceModifier(rotation: isFlipped ? 180 : 0))

    menuCardBack(card)
        .modifier(ThaiMenuCardFaceModifier(rotation: isFlipped ? 0 : -180))
}
.background(ThaiLifeTheme.cardWhite)
.clipShape(RoundedRectangle(cornerRadius: 16))
.shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
.contentShape(RoundedRectangle(cornerRadius: 16))
.animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
```

Remove only the obsolete outer rotation modifier:

```swift
.rotation3DEffect(
    .degrees(isFlipped ? 180 : 0),
    axis: (x: 0, y: 1, z: 0)
)
```

In `browser(_:)`, change the card identity from the flip-state-dependent expression to card identity only:

```swift
.id(reference.cards[index].id)
```

This prevents a local view identity reset from being tied to a face change while still replacing the visual card when `index` changes.

- [ ] **Step 3: Add a source-level regression assertion for the two local face modifiers**

Append this test to `ThaiLifeTests/ThaiMenuFlipTests.swift`:

```swift
func testMenuBrowserUsesIndependentFaceModifiersAndResetsOnNavigation() throws {
    let path = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift")
    let source = try String(contentsOf: path)

    XCTAssertTrue(source.contains("ThaiMenuCardFaceModifier(rotation: isFlipped ? 180 : 0)"))
    XCTAssertTrue(source.contains("ThaiMenuCardFaceModifier(rotation: isFlipped ? 0 : -180)"))
    XCTAssertFalse(source.contains(".id(reference.cards[index].id + (isFlipped"))
    XCTAssertTrue(source.contains("index -= 1; isFlipped = false"))
    XCTAssertTrue(source.contains("index += 1; isFlipped = false"))
}
```

- [ ] **Step 4: Run all menu flip tests and verify they pass**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:ThaiLifeTests/ThaiMenuFlipTests \
  test
```

Expected: PASS. The visibility test verifies the face-culling boundary, and the regression test verifies that the browser uses independent face rotations and preserves front-side reset on navigation.

- [ ] **Step 5: Commit the flip implementation and tests**

```bash
git add ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift ThaiLifeTests/ThaiMenuFlipTests.swift
git commit -m "fix: render Thai menu cards as two-sided flips"
```

## Task 5: Run the required integration checks

**Files:**
- Verify only: files changed by Tasks 1-4

**Interfaces:**
- Consumes: the generated content payload, manifest, bundled resources, and compiled app target.
- Produces: verified passing content pipeline and iOS test results.

- [ ] **Step 1: Run the complete Python content test suite**

Run:

```bash
.venv/bin/python -m unittest tools.test_content_pipeline
python3 tools/validate_content.py
```

Expected: all Python tests pass; validation reports no content or manifest errors.

- [ ] **Step 2: Regenerate and audit the audio manifest without regenerating audio**

Run:

```bash
.venv/bin/python tools/generate_audio_manifest.py
```

Expected: the audio manifest is regenerated from existing MP3 resources. No MP3 generation command is run, and the report has no missing, orphan, wrong-format, or undecodable audio.

- [ ] **Step 3: Run the complete iOS unit-test suite**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 4: Inspect the final diff and repository status**

Run:

```bash
git diff HEAD~3..HEAD -- tools/generate_content.py ThaiLife/Resources/Content/items.json ThaiLife/Resources/Content/content-manifest.json ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift tools/test_content_pipeline.py ThaiLifeTests/ContentAcceptanceTests.swift ThaiLifeTests/ThaiMenuFlipTests.swift
git status --short
```

Expected: the diff contains only approved generator ordering, generated artifacts, double-sided menu rendering, and tests. Preserve unrelated pre-existing working-tree files; do not stage or discard them.

- [ ] **Step 5: Commit any manifest-only audit update, if generated**

If `ThaiLife/Resources/Audio/audio-manifest.json` changed in Step 2, commit only that generated manifest:

```bash
git add ThaiLife/Resources/Audio/audio-manifest.json
git commit -m "chore: refresh audio manifest"
```

If it did not change, do not create an empty commit.

## Plan Self-Review

- **Spec coverage:** Task 1 and Task 2 enforce/recreate the exact base food → continuous fruit → drink ordering. Task 3 and Task 4 implement culling at the 90° boundary, isolated front/back surfaces, tap flips, and retained navigation reset. Task 5 runs the project-required content, audio-manifest, and Xcode validation.
- **No unintended content change:** Task 2 only reorders the original dictionaries; fields and audio IDs are explicitly preserved. It invokes the existing generator so the generated manifest checksum remains valid.
- **Gesture scope:** Task 4 retains the installed tap, drag, offset, and scroll-view structures rather than introducing a competing gesture recognizer.
- **Placeholder scan:** No placeholder markers or unspecified testing instructions remain in this plan.
- **Type consistency:** `ThaiMenuCardFace.isFacingViewer(at:)` is introduced in Task 4 and used consistently by both `ThaiMenuCardFaceModifier` and `ThaiMenuFlipTests`.
