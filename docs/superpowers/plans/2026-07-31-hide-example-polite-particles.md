# Hide Polite-Particle Glosses in Example Translations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove a recognized final Thai polite particle’s Chinese gloss from the example-sentence translation shown on a review card, while retaining the segment breakdown unchanged.

**Architecture:** Put the conservative normalization in a `ContentItem` computed property so it is deterministic, unit-testable, and does not mutate decoded content. `CardBack` reads that property instead of the raw `exampleMeaning`; the existing `segments` rendering continues to use `PhraseSegment.gloss` directly.

**Tech Stack:** Swift 5, SwiftUI, XCTest, Xcode project `ThaiLife.xcodeproj`.

## Global Constraints

- Do not modify `ThaiLife/Resources/Content/items.json` or regenerate content.
- Only final segment Thai values `ครับ`, `ค่ะ`, and `คะ` qualify for removal.
- Only a matching terminal Chinese gloss is removed; all non-final lexical translation text remains intact.
- `segments` must continue to display the original `PhraseSegment.gloss`.
- If data is absent or no recognized matching suffix is present, return the raw `exampleMeaning` unchanged.

---

## File Structure

- Modify `ThaiLife/Domain/ContentModels.swift`: add `ContentItem.displayExampleMeaning`, a presentation-safe computed property that conditionally strips a final polite-particle gloss; extend the existing fixture helper for concise tests.
- Modify `ThaiLife/Features/Review/FlipCardView.swift`: render `displayExampleMeaning` in the example area.
- Modify `ThaiLifeTests/ContentValidatorTests.swift`: add isolated XCTest coverage for the computed property without creating a new Xcode target file reference.

### Task 1: ContentItem — normalize the display-only example meaning

**Files:**
- Modify: `ThaiLife/Domain/ContentModels.swift:168-205`
- Test: `ThaiLifeTests/ContentValidatorTests.swift` (append a new `ExampleMeaningDisplayTests` test case after `ContentValidatorTests`)

**Interfaces:**
- Consumes: `ContentItem.exampleMeaning: String?`, `ContentItem.segments: [PhraseSegment]`, and `PhraseSegment.thai` / `PhraseSegment.gloss`.
- Produces: `ContentItem.displayExampleMeaning: String?`, which is either the original example meaning or that meaning without one matching terminal polite-particle gloss.

- [ ] **Step 1: Write the failing XCTest coverage**

Append this test case to `ThaiLifeTests/ContentValidatorTests.swift`:

```swift
final class ExampleMeaningDisplayTests: XCTestCase {
    func testDisplayExampleMeaningRemovesMalePoliteParticleGloss() {
        let item = ContentItem.fixture(
            exampleMeaning: "昨晚睡得好吗礼貌语气词",
            segments: [
                PhraseSegment(thai: "เมื่อคืน", gloss: "昨晚"),
                PhraseSegment(thai: "นอน", gloss: "睡"),
                PhraseSegment(thai: "หลับ", gloss: "睡着"),
                PhraseSegment(thai: "ดี", gloss: "好"),
                PhraseSegment(thai: "ไหม", gloss: "吗"),
                PhraseSegment(thai: "ครับ", gloss: "礼貌语气词(男)")
            ]
        )

        XCTAssertEqual(item.displayExampleMeaning, "昨晚睡得好吗")
    }

    func testDisplayExampleMeaningRemovesFemaleAndQuestionParticleGlosses() {
        let femaleItem = ContentItem.fixture(
            exampleMeaning: "谢谢语气词",
            segments: [PhraseSegment(thai: "ค่ะ", gloss: "语气词(女)")]
        )
        let questionItem = ContentItem.fixture(
            exampleMeaning: "可以吗礼貌语气词",
            segments: [PhraseSegment(thai: "คะ", gloss: "礼貌语气词(女)")]
        )

        XCTAssertEqual(femaleItem.displayExampleMeaning, "谢谢")
        XCTAssertEqual(questionItem.displayExampleMeaning, "可以吗")
    }

    func testDisplayExampleMeaningKeepsNonPoliteFinalWordAndUnmatchedSuffix() {
        let lexicalItem = ContentItem.fixture(
            exampleMeaning: "我喜欢米饭",
            segments: [PhraseSegment(thai: "ข้าว", gloss: "米饭")]
        )
        let unmatchedItem = ContentItem.fixture(
            exampleMeaning: "我睡得很好",
            segments: [PhraseSegment(thai: "ครับ", gloss: "礼貌语气词(男)")]
        )

        XCTAssertEqual(lexicalItem.displayExampleMeaning, "我喜欢米饭")
        XCTAssertEqual(unmatchedItem.displayExampleMeaning, "我睡得很好")
    }

    func testDisplayExampleMeaningPreservesRawValueWhenMeaningOrSegmentsAreMissing() {
        XCTAssertNil(ContentItem.fixture(exampleMeaning: nil).displayExampleMeaning)
        XCTAssertEqual(ContentItem.fixture(exampleMeaning: "你好").displayExampleMeaning, "你好")
    }
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ThaiLifeTests/ExampleMeaningDisplayTests test
```

Expected: build fails because `ContentItem.fixture` has no `exampleMeaning` argument and `ContentItem` has no `displayExampleMeaning` member.

- [ ] **Step 3: Add the fixture parameter and the display-only computed property**

In `ThaiLife/Domain/ContentModels.swift`, replace the fixture signature/body portion beginning with `relatedIDs` through the initializer call with this version, preserving the existing defaults before and after it:

```swift
        relatedIDs: [String] = [],
        exampleMeaning: String? = nil,
        segments: [PhraseSegment] = [],
        sourceID: String = "author-001"
    ) -> ContentItem {
        ContentItem(
            id: id,
            kind: kind,
            category: category,
            thai: thai,
            romanization: romanization,
            meaningZhHans: meaningZhHans,
            audioID: audioID,
            prerequisiteIDs: prerequisiteIDs,
            relatedIDs: relatedIDs,
            exampleMeaning: exampleMeaning,
            segments: segments,
            sourceID: sourceID
        )
    }
}
```

Immediately after that extension, add:

```swift
extension ContentItem {
    private static let finalPoliteParticles: Set<String> = ["ครับ", "ค่ะ", "คะ"]
    private static let politeParticleGlossSuffixes = [
        "礼貌语气词(男)",
        "礼貌语气词(女)",
        "语气词(男)",
        "语气词(女)",
        "礼貌语气词",
        "语气词"
    ]

    var displayExampleMeaning: String? {
        guard let exampleMeaning, let finalSegment = segments.last,
              Self.finalPoliteParticles.contains(finalSegment.thai) else {
            return exampleMeaning
        }

        let suffixes = [finalSegment.gloss] + Self.politeParticleGlossSuffixes
        guard let suffix = suffixes.sorted(by: { $0.count > $1.count }).first(where: exampleMeaning.hasSuffix) else {
            return exampleMeaning
        }

        return String(exampleMeaning.dropLast(suffix.count))
    }
}
```

This retains source data, handles current content variants such as `礼貌语气词` and `语气词(男)`, and avoids deleting text unless both the final Thai segment and a terminal Chinese gloss match.

- [ ] **Step 4: Run the focused test to verify it passes**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ThaiLifeTests/ExampleMeaningDisplayTests test
```

Expected: `** TEST SUCCEEDED **`; all four `ExampleMeaningDisplayTests` methods pass.

- [ ] **Step 5: Commit the model and unit tests**

```bash
git add ThaiLife/Domain/ContentModels.swift ThaiLifeTests/ContentValidatorTests.swift
git commit -m "fix: hide polite particles in example meanings"
```

### Task 2: CardBack — render the normalized value

**Files:**
- Modify: `ThaiLife/Features/Review/FlipCardView.swift:263-266`
- Test: `ThaiLifeTests/ContentValidatorTests.swift` (Task 1’s tests validate the value supplied to this rendering path)

**Interfaces:**
- Consumes: `ContentItem.displayExampleMeaning: String?` from Task 1.
- Produces: The review card’s example translation text without a final polite-particle gloss; its existing segment loop remains unchanged.

- [ ] **Step 1: Replace the example-meaning binding in CardBack**

In the existing `// Example` block in `CardBack`, replace:

```swift
if let exampleMeaning = item.exampleMeaning, !exampleMeaning.isEmpty {
    Text(exampleMeaning)
        .font(.caption)
        .foregroundColor(ThaiLifeTheme.textTertiary)
}
```

with:

```swift
if let exampleMeaning = item.displayExampleMeaning, !exampleMeaning.isEmpty {
    Text(exampleMeaning)
        .font(.caption)
        .foregroundColor(ThaiLifeTheme.textTertiary)
}
```

Do not change the adjacent `ForEach` loop: it must continue rendering `Text(segment.gloss)` so the standalone explanation of `ครับ` / `ค่ะ` / `คะ` stays visible under 「词块拆解」.

- [ ] **Step 2: Build and run the full test suite**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: build exits with status `0` and ends with `** TEST SUCCEEDED **`.

- [ ] **Step 3: Manually verify the UI path in the simulator**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build exits with status `0`. Launch the resulting app in the same iPhone 16 simulator, open the review card whose example is `เมื่อคืน นอนหลับดีไหมครับ`, flip it, and confirm:

1. The example translation ends at `昨晚睡得好吗` with no polite-particle label.
2. The 「词块拆解」 section still includes `ครับ` with its original gloss.
3. A card whose final segment is a normal word keeps its full example translation.

- [ ] **Step 4: Commit the UI binding**

```bash
git add ThaiLife/Features/Review/FlipCardView.swift
git commit -m "fix: render normalized example meanings"
```
