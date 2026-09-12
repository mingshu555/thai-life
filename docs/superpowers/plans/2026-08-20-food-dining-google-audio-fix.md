# Food Dining Google Audio Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regenerate Google MP3 pronunciation for the 16 newly added fruit/drink words, make Thai menu text directly playable, and deploy the verified build to the user’s iPhone 17 Pro Max.

**Architecture:** Add an explicit audio-ID filter to the existing Google TTS generator so a bounded set of content-backed main-word assets can be regenerated without touching unrelated files. Use the existing `AudioPlaybackService` as the single bundled-MP3-first playback path, injecting it into the menu list/browser and assigning direct Thai-text tap targets that coexist with navigation, flip, and drag gestures. Validate content and MP3 resources, build the existing project, then install/launch via CoreDevice.

**Tech Stack:** SwiftUI, AVFAudio/AVSpeechSynthesizer, XCTest, Python 3, Google Cloud Text-to-Speech, Xcode/xcodebuild, `xcrun devicectl`.

## Global Constraints

- Only regenerate primary audio IDs `audio-food_dining-word-060` through `audio-food_dining-word-075`; do not generate `-example` assets for these entries.
- Google synthesis must use `texttospeech.AudioEncoding.MP3` and atomically commit each completed file with `os.replace`.
- TTS input must be the content item’s complete `thai` text; never synthesize text from segments or glosses.
- Credentials remain outside the repository and are supplied only through `GOOGLE_APPLICATION_CREDENTIALS`; never print or commit credential contents.
- Primary pronunciation must try bundled `Audio/<audioID>.mp3` first, with one complete Thai system-TTS utterance only as a failure fallback.
- Preserve menu navigation, favorite, flip, and horizontal-drag behavior.
- Validate content, manifest/MP3 format, Debug device build, installation, and app launch on UDID `00008150-000229AA2199401C`.

---

## File Structure

- `tools/generate_audio.py` — adds a validated `--audio-id` filter for precise main-word regeneration.
- `tools/test_generate_audio.py` — adds Python-level request/filter coverage without Google credentials.
- `ThaiLife/Features/Catalog/ThaiMenuListView.swift` — makes the Thai label a direct playback control while retaining row navigation.
- `ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift` — makes front/back Thai dish names direct playback controls while retaining flip/swipe behavior.
- `ThaiLifeTests/ThaiMenuTests.swift` — verifies menu views route direct Thai-text controls through a card’s own `audioID`.
- `ThaiLifeTests/ThaiMenuResourceTests.swift` — verifies the 16 fruit/drink IDs resolve to bundled MP3s.
- `ThaiLife/Resources/Audio/audio-food_dining-word-060.mp3` … `audio-food_dining-word-075.mp3` — regenerated Google MP3 assets.
- `ThaiLife/Resources/Content/content-manifest.json` — regenerated audio manifest data after resource audit.

### Task 1: Add bounded Google-audio generator selection

**Files:**
- Modify: `tools/generate_audio.py`
- Create or modify: `tools/test_generate_audio.py`

**Interfaces:**
- Consumes: `audio_requests(items, examples_only=False, segments_only=False)`.
- Produces: `audio_requests(..., audio_ids: set[str] | None = None)` and CLI `--audio-id AUDIO_ID` (repeatable).
- Contract: selecting IDs filters only primary requests; `--examples-only` and `--segments-only` cannot be combined with `--audio-id`.

- [ ] **Step 1: Write failing filter tests**

```python
from generate_audio import audio_requests


def test_audio_id_filter_returns_only_requested_primary_content_item():
    items = [
        {"audioID": "audio-food_dining-word-060", "thai": "มะม่วง"},
        {"audioID": "audio-food_dining-word-061", "thai": "ทุเรียน"},
    ]
    assert list(audio_requests(items, audio_ids={"audio-food_dining-word-060"})) == [
        ("audio-food_dining-word-060", "มะม่วง"),
    ]
```

Add cases proving unknown ID raises `ValueError`, filters never include example IDs, and incompatible flags are rejected.

- [ ] **Step 2: Run the targeted Python test to verify it fails**

Run: `python3 -m unittest tools.test_generate_audio -v`  
Expected: FAIL because `audio_requests` has no `audio_ids` parameter.

- [ ] **Step 3: Implement minimal request filtering and CLI validation**

Add an optional `audio_ids` set, validate it against main `item["audioID"]` values, filter `audio_requests`, and parse repeatable `--audio-id`. Keep the generator’s MP3 enum and `tmp_path`/`os.replace` sequence unchanged.

- [ ] **Step 4: Run generator unit tests**

Run: `python3 -m unittest tools.test_generate_audio -v`  
Expected: PASS without credentials or API traffic.

- [ ] **Step 5: Commit the generator/test change**

```bash
git add tools/generate_audio.py tools/test_generate_audio.py
git commit -m "feat: target Google audio regeneration by ID"
```

### Task 2: Wire direct menu-text playback without gesture regressions

**Files:**
- Modify: `ThaiLife/Features/Catalog/ThaiMenuListView.swift`
- Modify: `ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift`
- Modify: `ThaiLifeTests/ThaiMenuTests.swift`

**Interfaces:**
- Consumes: `@EnvironmentObject var audioService: AudioPlaybackServiceWrapper` and `AudioPlaybackService.play(audioID:thaiText:)`.
- Produces: a direct `Button`/tap target for `card.thai` that invokes `play(audioID: card.audioID, thaiText: card.thai)`.
- Contract: row tap still sets `selectedCardID`; direct text tap plays only audio; browser card background still flips and horizontal drag still pages.

- [ ] **Step 1: Write failing source/behavior-contract tests**

Add XCTest assertions that both catalog view files refer to `audioService.service.play(audioID: card.audioID, thaiText: card.thai)`, that their Thai controls are buttons, and that the existing flip/drag symbols remain present.

- [ ] **Step 2: Run the focused XCTest suite to verify it fails**

Run: `xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:ThaiLifeTests/ThaiMenuTests test`  
Expected: FAIL because the direct playback call is absent.

- [ ] **Step 3: Implement direct Thai text controls**

Inject `AudioPlaybackServiceWrapper` in the list/browser views. Make Thai names `Button`s with `.buttonStyle(.plain)` and an accessibility label/hint; the action calls the existing service with the card’s own ID/text. Scope row/card background taps to non-text content so text taps do not accidentally navigate or flip; keep the drag gesture on the card container.

- [ ] **Step 4: Run focused menu tests**

Run: `xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:ThaiLifeTests/ThaiMenuTests test`  
Expected: PASS.

- [ ] **Step 5: Commit the Swift/test change**

```bash
git add ThaiLife/Features/Catalog/ThaiMenuListView.swift ThaiLife/Features/Catalog/ThaiMenuBrowserView.swift ThaiLifeTests/ThaiMenuTests.swift
git commit -m "fix: play Thai menu text on tap"
```

### Task 3: Regenerate and audit fruit/drink Google MP3 assets

**Files:**
- Modify: `ThaiLife/Resources/Audio/audio-food_dining-word-060.mp3` through `ThaiLife/Resources/Audio/audio-food_dining-word-075.mp3`
- Modify: `ThaiLife/Resources/Content/content-manifest.json`
- Modify: `ThaiLifeTests/ThaiMenuResourceTests.swift`

**Interfaces:**
- Consumes: the ID filter from Task 1, `items.json`, `GOOGLE_APPLICATION_CREDENTIALS`, and `generate_audio_manifest.py`.
- Produces: 16 valid bundle resources and an updated manifest.
- Contract: all output files are valid MPEG MP3 assets and correspond one-to-one with content IDs 060–075.

- [ ] **Step 1: Write failing bundled-resource coverage**

Add `testFruitAndDrinkWordsHaveBundledAudio` to enumerate IDs 060 through 075 and assert `ContentRepository.resourceBundle` resolves each as `Audio/<id>.mp3`.

- [ ] **Step 2: Run the focused resource test**

Run: `xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:ThaiLifeTests/ThaiMenuResourceTests test`  
Expected: initially verifies existence; record the pre-regeneration checksums separately rather than falsely requiring failure for existing files.

- [ ] **Step 3: Regenerate only the 16 Google audio assets**

Set `GOOGLE_APPLICATION_CREDENTIALS` to the project-external Downloads credential path and run `.venv/bin/python tools/generate_audio.py --force` with 16 repeatable `--audio-id` arguments. Do not echo the environment value or inspect its contents.

- [ ] **Step 4: Verify containers and regenerate manifest**

Run `file` over exactly the 16 outputs; each must contain `MPEG` and `layer III`. Then run:

```bash
python3 tools/validate_content.py
.venv/bin/python tools/generate_audio_manifest.py
```

Expected: validation succeeds and the manifest reports no missing, orphan, invalid-format, or undecodable files.

- [ ] **Step 5: Run resource and generator tests**

Run:

```bash
python3 -m unittest tools.test_generate_audio -v
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:ThaiLifeTests/ThaiMenuResourceTests test
```

Expected: PASS.

- [ ] **Step 6: Commit regenerated assets and audit data**

```bash
git add ThaiLife/Resources/Audio ThaiLife/Resources/Content/content-manifest.json ThaiLifeTests/ThaiMenuResourceTests.swift
git commit -m "fix: regenerate food dining Google audio"
```

### Task 4: Full verification and iPhone deployment

**Files:**
- No source changes expected; investigate and fix only failures produced by the commands below.

**Interfaces:**
- Consumes: complete source/resources from Tasks 1–3.
- Produces: a built, installed, launched `com.yaohuix.ThaiLife` app on the paired iPhone 17 Pro Max.

- [ ] **Step 1: Run full project test suite**

Run: `xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test`  
Expected: PASS.

- [ ] **Step 2: Build for the real device**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -configuration Debug \
  -destination 'id=00008150-000229AA2199401C' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

Expected: `BUILD SUCCEEDED` and the built `ThaiLife.app` contains all 16 target MP3s in `Audio/`.

- [ ] **Step 3: Install and launch on the iPhone 17 Pro Max**

Use `xcrun devicectl device install app --device 00008150-000229AA2199401C <built/ThaiLife.app>` and `xcrun devicectl device process launch --device 00008150-000229AA2199401C com.yaohuix.ThaiLife`.

Expected: both commands report success.

- [ ] **Step 4: Report exact verification and deployment results**

Provide the 16-ID scope, generator/test/content/manifest/build outcomes, and confirmation that the app was installed/launched on the iPhone. Never include credential data.
