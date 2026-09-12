# 泰国招牌无头字对照页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在课程页新增一个离线、单页、可滚动的泰国招牌无头字对照入口，展示真实 Sarabun/Prompt 字形、易混提醒和合规场景例子，并支持单字和整词播放。

**Architecture:** 新建独立的 `LooplessSignageReference` 领域模型与 JSON 资源，不扩展普通 `ContentItem`。`ContentRepository` 负责离线加载及结构校验；`LooplessSignageReferenceView` 以一个长 `ScrollView` 渲染固定说明、高频对照、易混提醒和场景卡，所有音频经已有 `AudioPlaybackService` 播放。

**Tech Stack:** Swift 5、SwiftUI、Foundation、XCTest、现有 iOS Bundle 资源、现有 AudioPlaybackService、Sarabun/Prompt 字体资源（经许可验证后）。

## Global Constraints

- 页面必须是单张可滚动对照页：没有目录、章节、查询框、测试、答案、评分、进度、FSRS、复习或草稿行为。
- 标准有头字使用 Sarabun，现代无头字使用 Prompt；两者必须离线真实渲染，禁止系统回退、网络下载或图片伪造。
- 图片和字体必须先通过来源、版本、iOS 离线再分发许可和署名要求审计；无法证明许可即用合规替代物，绝不导入 App Bundle。
- 场景词必须播放完整词音频，不得由单字或片段拼接；单字可播放标准单字音频。
- 保持普通 `items.json`、其 checksum、FSRS、收藏练习、课程分类和既有音频管线语义不变。
- 所有新 Swift 文件、测试、JSON、字体、图片、许可文档都要加入 `ThaiLife.xcodeproj` 的正确 Source/Resources build phase；不覆盖既有未提交改动。

---

### Task 1: 审计并准备可分发的字体与场景资源

**Files:**
- Create: `ThaiLife/Resources/Attributions/loopless-signage-assets.md`
- Create: `ThaiLife/Resources/Fonts/Sarabun-<verified-version>.ttf`
- Create: `ThaiLife/Resources/Fonts/Prompt-<verified-version>.ttf`
- Create: `ThaiLife/Resources/Fonts/LICENSE-Sarabun.txt`
- Create: `ThaiLife/Resources/Fonts/LICENSE-Prompt.txt`
- Create: `ThaiLife/Resources/LooplessSignage/<five-verified-scene-images>`
- Modify: `ThaiLife.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces registered font PostScript names, recorded in `loopless-signage-assets.md` and consumed by Task 3 as `LooplessSignageFont.standardName` and `.looplessName`.
- Produces five resource image IDs consumed by `LooplessScene.imageAssetID` in Task 2.

- [ ] **Step 1: Write a failing resource-audit test**

Create `ThaiLifeTests/LooplessSignageResourceTests.swift`:

```swift
func testLooplessFontsAndAttributionAreBundled() throws {
    XCTAssertNotNil(Bundle.main.url(forResource: "Sarabun-Regular", withExtension: "ttf", subdirectory: "Fonts"))
    XCTAssertNotNil(Bundle.main.url(forResource: "Prompt-Regular", withExtension: "ttf", subdirectory: "Fonts"))
    XCTAssertNotNil(Bundle.main.url(forResource: "loopless-signage-assets", withExtension: "md", subdirectory: "Attributions"))
}
```

Add one assertion per `LooplessScene.imageAssetID` after Task 2 defines scene data. The test must load from the app resource bundle through the same fallback pattern used by `ContentRepository.resourceBundle`.

- [ ] **Step 2: Run the test to confirm it fails**

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -only-testing:ThaiLifeTests/LooplessSignageResourceTests \
  test
```

Expected: FAIL because the fonts, attributions and verified scene images are not bundled.

- [ ] **Step 3: Perform the resource licence audit before copying assets**

For Sarabun and Prompt, retrieve files only from their official source, retain the exact license text, record source repository/release/tag, filename, SHA-256 and license in `loopless-signage-assets.md`, and verify the font loads on macOS/iOS tooling with its expected family/PostScript name.

For each candidate image (`thai_cafe_signboard.jpg`, `thai_store_discount.jpg`, `thai_open_closed.jpg`, `thai_pharmacy_sign.jpg`, `thai_station_exit.jpg`), document original source and redistributable license. If any candidate lacks proof, replace it with an original, licensed or otherwise verified image before adding it. The attribution document must contain one row per final asset:

```markdown
| Asset | Source | Version / retrieval date | License | Required attribution | SHA-256 |
|---|---|---|---|---|---|
```

Copy only verified final resources to the directories above, add them to Copy Bundle Resources, add both font files under `UIAppFonts` in the generated/target Info.plist configuration, and ensure the attributions document is bundled.

- [ ] **Step 4: Run resource validation**

Run the Task 1 Step 2 test plus:

```bash
for f in ThaiLife/Resources/Fonts/*.ttf; do file "$f"; shasum -a 256 "$f"; done
for f in ThaiLife/Resources/LooplessSignage/*; do file "$f"; shasum -a 256 "$f"; done
```

Expected: every declared resource exists, fonts are valid TrueType/OpenType font data, images decode, and source/license/checksum rows match the files.

- [ ] **Step 5: Commit audited resources separately**

```bash
git add ThaiLife/Resources/Fonts ThaiLife/Resources/LooplessSignage \
  ThaiLife/Resources/Attributions/loopless-signage-assets.md \
  ThaiLifeTests/LooplessSignageResourceTests.swift ThaiLife.xcodeproj/project.pbxproj
git commit -m "feat: add audited loopless signage assets"
```

### Task 2: 独立 JSON 模型、加载器与内容校验

**Files:**
- Create: `ThaiLife/Domain/LooplessSignageModels.swift`
- Create: `ThaiLife/Resources/Content/loopless_signage_reference.json`
- Modify: `ThaiLife/Data/ContentRepository.swift`
- Create: `ThaiLife/Data/LooplessSignageValidator.swift`
- Modify: `ThaiLife.xcodeproj/project.pbxproj`
- Create: `ThaiLifeTests/LooplessSignageContentTests.swift`

**Interfaces:**
- Produces `LooplessSignageReference`, `LooplessGlyphEntry`, `LooplessConfusionGroup`, and `LooplessScene`, all `Codable`, `Equatable`, `Sendable`, and `Identifiable` where applicable.
- Produces `ContentRepository.loadLooplessSignageReference() throws -> LooplessSignageReference`.
- Produces `LooplessSignageValidator.validate(_:) throws`.
- Task 3 consumes this reference and must not load/modify `items.json`.

- [ ] **Step 1: Write failing decoding and validation tests**

```swift
func testBundledLooplessReferenceHasRequiredSectionsAndFiveScenes() throws {
    let reference = try ContentRepository.loadLooplessSignageReference()
    XCTAssertFalse(reference.glyphs.isEmpty)
    XCTAssertFalse(reference.confusionGroups.isEmpty)
    XCTAssertEqual(reference.scenes.map(\.id), ["milk-tea", "discount", "open-close", "pharmacy", "station-exit"])
}

func testLooplessValidatorRejectsSceneWithUnknownGlyphOrMissingAudio() {
    var reference = LooplessSignageReference.fixture()
    reference.scenes[0].glyphExplanationIDs = ["unknown-glyph"]
    XCTAssertThrowsError(try LooplessSignageValidator.validate(reference))
}
```

Also test: duplicate IDs; empty standard/loopless Thai; scene missing image ID; scene missing Thai word/Chinese meaning/audio ID; less/more than the mandatory five scene IDs; and all scene image IDs match the resource audit file list.

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -only-testing:ThaiLifeTests/LooplessSignageContentTests \
  test
```

Expected: compile/load failure because the models, JSON and loader do not exist.

- [ ] **Step 3: Implement the models, data and validation**

Use exactly these top-level fields:

```swift
struct LooplessSignageReference: Codable, Equatable, Sendable {
    let introductionZhHans: String
    let glyphs: [LooplessGlyphEntry]
    let confusionGroups: [LooplessConfusionGroup]
    let scenes: [LooplessScene]
}
```

`LooplessGlyphEntry` includes `id`, `standardThai`, `looplessThai`, `thaiName`, `audioID`, `visualHintZhHans`, and `exampleWords`. `LooplessConfusionGroup` includes `id`, `glyphIDs`, and `comparisonHintZhHans`. `LooplessScene` includes `id`, `titleZhHans`, `imageAssetID`, `thaiWord`, `standardThaiWord`, `meaningZhHans`, `audioID`, and `glyphExplanationZhHans`.

Populate the JSON with the spec’s high-frequency n/d/m/h/u/tail/vowel groups, the mandatory confusion groups, and exactly the five mandatory scene IDs. Use existing complete-word audio IDs for `ลดราคา`, `เปิด`, `ปิด`, `ยา`, `ทางออก`, `ทางเข้า`, and add a dedicated complete-word MP3/ID for `ชานม` under the project’s audio rules. Validate every internal ID relationship, nonempty localized field and resource name before UI code is added.

`ContentRepository.loadLooplessSignageReference()` must load only `loopless_signage_reference.json`, decode it, call `LooplessSignageValidator.validate`, and throw a dedicated localized load error. It must not affect `loadBundled()` or the existing content manifest checksum.

- [ ] **Step 4: Run focused content tests to confirm they pass**

Run the Task 2 Step 2 command. Expected: all valid-bundle tests pass and every malformed fixture fails with a precise validation error.

- [ ] **Step 5: Commit the isolated content system**

```bash
git add ThaiLife/Domain/LooplessSignageModels.swift ThaiLife/Data/LooplessSignageValidator.swift \
  ThaiLife/Data/ContentRepository.swift ThaiLife/Resources/Content/loopless_signage_reference.json \
  ThaiLifeTests/LooplessSignageContentTests.swift ThaiLife.xcodeproj/project.pbxproj
git commit -m "feat: add loopless signage reference content"
```

### Task 3: 单页对照 UI 与离线字体注册

**Files:**
- Create: `ThaiLife/Features/Catalog/LooplessSignageReferenceView.swift`
- Modify: `ThaiLife/Features/Catalog/CatalogView.swift`
- Modify: `ThaiLife.xcodeproj/project.pbxproj`
- Create: `ThaiLifeTests/LooplessSignageReferenceViewTests.swift`

**Interfaces:**
- Consumes `ContentRepository.loadLooplessSignageReference()`, all Task 2 models and Task 1 resources.
- Produces `LooplessSignageReferenceView`, a single `ScrollView` with no nested course navigation.
- Produces `LooplessSignageFont.standard` and `.loopless` font helpers resolving registered Sarabun/Prompt names and failing loudly in DEBUG if registration fails.

- [ ] **Step 1: Write failing UI structure tests**

```swift
func testCatalogOffersLooplessSignageReferenceEntry() throws {
    let source = try String(contentsOfFile: sourcePath("ThaiLife/Features/Catalog/CatalogView.swift"))
    XCTAssertTrue(source.contains("LooplessSignageReferenceView"))
    XCTAssertTrue(source.contains("泰国招牌无头字对照"))
}

func testReferenceViewIsSingleScrollPageWithoutTestingOrSearchUI() throws {
    let source = try String(contentsOfFile: sourcePath("ThaiLife/Features/Catalog/LooplessSignageReferenceView.swift"))
    XCTAssertTrue(source.contains("ScrollView"))
    XCTAssertFalse(source.contains("TextField"))
    XCTAssertFalse(source.contains("Quiz"))
    XCTAssertFalse(source.contains("评分"))
}
```

Add source-shape assertions for explicit Sarabun and Prompt font helpers, scene rendering, and full-word `audioID` playback. Keep behavioral loading/validation tests in Task 2.

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -only-testing:ThaiLifeTests/LooplessSignageReferenceViewTests \
  test
```

Expected: compile/source failure because the entry and single-page view do not exist.

- [ ] **Step 3: Implement the reference page**

In `CatalogView`, add a `NavigationLink(destination: LooplessSignageReferenceView())` above the word-family card in the existing “专项扩展” section. Its title/subtitle must be exactly:

```text
泰国招牌无头字对照
看懂广告、店铺、药店与地铁招牌
高频字形 · 易混提醒 · 真实场景
```

Implement `LooplessSignageReferenceView` as one `ScrollView` in this exact order:

1. navigation title `泰国招牌无头字对照` and the two-line introduction;
2. a “高频字形对照” block rendering all glyph entries as compact mobile rows: Sarabun standard glyph, Prompt loopless glyph, and the one-line visual hint;
3. an “易混提醒” block rendering all confusion groups side-by-side with one comparison hint;
4. a “真实招牌例子” block rendering all five `LooplessScene` cards with image, loopless word, standard word, Chinese meaning and glyph explanation.

Do not add a course directory, tabs, pagers, sections navigated by user, search field, question UI, answers, score, progress or FSRS calls. `onAppear`/`.task` loads the JSON once; load error uses `ContentUnavailableView` rather than silently showing empty content.

Use `Button` exclusively around Thai glyph/word labels. Its action must call `AudioPlaybackService.play(audioID:thaiText:)`; a scene word calls `play(scene.audioID, thaiText: scene.thaiWord)`, guaranteeing full-word pronunciation. Standard/loopless glyph buttons use the single glyph’s `audioID` and `standardThai` fallback text. Do not make whole scene cards into audio buttons.

- [ ] **Step 4: Run focused UI tests**

Run Task 3 Step 2, then:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  -only-testing:ThaiLifeTests/CatalogViewModelTests \
  -only-testing:ThaiLifeTests/AudioPlaybackServiceTests \
  test
```

Expected: entry, single-page constraints, rendering structure and audio routing tests pass; existing catalog and audio tests remain green.

- [ ] **Step 5: Commit the UI integration**

```bash
git add ThaiLife/Features/Catalog/CatalogView.swift \
  ThaiLife/Features/Catalog/LooplessSignageReferenceView.swift \
  ThaiLifeTests/LooplessSignageReferenceViewTests.swift ThaiLife.xcodeproj/project.pbxproj
git commit -m "feat: add loopless signage reference page"
```

### Task 4: 音频、Bundle 与 final validation

**Files:**
- Modify: `ThaiLife/Resources/Audio/audio-manifest.json` only through the existing generator
- Create/Modify: `ThaiLife/Resources/Audio/<only-missing-loopless-word-audio>.mp3`
- Modify: `tools/generate_audio.py` only if a direct capability gap is proven
- Modify: tests only for failures caused by Tasks 1–3

**Interfaces:**
- Consumes all prior tasks.
- Produces a verified, offline bundle with every declared font/image/JSON/audio resource present and decodable.

- [ ] **Step 1: Identify missing declared audio IDs**

Run a small verification script that loads `loopless_signage_reference.json`, obtains every glyph/scene `audioID`, and checks for `ThaiLife/Resources/Audio/<audioID>.mp3`. Its output must list every ID once and fail on missing, orphaned or non-MP3 files.

- [ ] **Step 2: Generate only required complete-word audio**

For each missing complete word (expected at minimum `ชานม`), use the existing Google Cloud TTS pipeline with the complete Thai string once, MP3 encoding, temporary file + atomic replacement, then verify:

```bash
file ThaiLife/Resources/Audio/<new-id>.mp3
ffprobe -v error -show_entries format=format_name -of default=nw=1 \
  ThaiLife/Resources/Audio/<new-id>.mp3
```

Expected: MP3/MPEG container; never OGG_OPUS renamed as `.mp3`.

- [ ] **Step 3: Regenerate and verify manifests/content**

```bash
python3 tools/validate_content.py
.venv/bin/python tools/generate_audio_manifest.py
python3 -m tools.test_content_pipeline
```

Expected: current content checksum stays valid; audio manifest has no missing, orphan, wrong-format or undecodable resources. If the independent JSON requires a separate validator command, add and run it without changing `items.json` semantics.

- [ ] **Step 4: Run the complete simulator suite**

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,id=5BA5DF06-3574-4BF9-9A6A-2CAE00D81447' \
  test
```

Expected: `** TEST SUCCEEDED **`; do not weaken unrelated existing tests.

- [ ] **Step 5: Build, install and launch the current iPhone 17 Pro Max**

Use the current device identifiers and new personal Team without changing committed project signing settings:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -configuration Debug \
  -destination 'id=00008150-000229AA2199401C' \
  -derivedDataPath build/DeviceDerivedDataLooplessSignage \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=VSASLV4YAL CODE_SIGN_STYLE=Automatic build

xcrun devicectl device install app \
  --device 817BCF39-0C17-55EB-8E3D-6F8194CEF388 \
  build/DeviceDerivedDataLooplessSignage/Build/Products/Debug-iphoneos/ThaiLife.app

xcrun devicectl device process launch \
  --device 817BCF39-0C17-55EB-8E3D-6F8194CEF388 \
  com.yaohuix.ThaiLife
```

Manually verify: the catalog entry opens directly into one scroll page; no query/quiz/progress UI exists; both fonts visibly differ; glyph and full scene-word playback work; all five scene cards display; navigation returns to the catalog.

- [ ] **Step 6: Final change audit and commit**

```bash
git diff --check
git status --short
git add ThaiLife/Domain/LooplessSignageModels.swift \
  ThaiLife/Data/LooplessSignageValidator.swift ThaiLife/Data/ContentRepository.swift \
  ThaiLife/Features/Catalog/CatalogView.swift \
  ThaiLife/Features/Catalog/LooplessSignageReferenceView.swift \
  ThaiLife/Resources/Content/loopless_signage_reference.json \
  ThaiLife/Resources/Fonts ThaiLife/Resources/LooplessSignage \
  ThaiLife/Resources/Attributions/loopless-signage-assets.md \
  ThaiLife/Resources/Audio ThaiLife/Resources/Audio/audio-manifest.json \
  ThaiLifeTests/LooplessSignageResourceTests.swift \
  ThaiLifeTests/LooplessSignageContentTests.swift \
  ThaiLifeTests/LooplessSignageReferenceViewTests.swift \
  ThaiLife.xcodeproj/project.pbxproj
git commit -m "feat: add loopless signage reference"
```

Do not stage unrelated dialogue, chunk, favorite-list, audio-pipeline or parent-workspace changes.
