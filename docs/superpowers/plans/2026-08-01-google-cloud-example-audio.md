# Google Cloud Example Audio Implementation Plan

> **For agentic workers:** Implement task-by-task with TDD and verify each checkpoint before moving on.

**Goal:** Play every example as a bundled Google Cloud TTS sentence when its MP3 exists, with a complete-sentence iOS TTS fallback while preserving offline app behavior.

**Architecture:** Derive example asset IDs as `<item.audioID>-example`, avoiding a schema migration for `ContentItem`. The build-time generator emits both headword/phrase audio and example-sentence audio; the manifest treats both as expected assets. `AudioPlaybackService.playSentence` tries the bundled MP3 first and falls back to one normalized Thai `AVSpeechUtterance` if the asset is unavailable.

**Tech Stack:** Swift/AVFAudio, AVFoundation `AVAudioPlayer`, Google Cloud Text-to-Speech Python client, MP3 resources, XCTest.

## Global Constraints

- Never bundle or log Google credentials.
- Example audio must use the complete `example` string, never `segments`.
- Missing example MP3 must not block playback; use the iOS Thai voice fallback.
- Existing headword playback behavior remains unchanged.
- Run content validation, build-for-testing, device build, and device installation before completion.

### Task 1: Add failing tests for bundled sentence playback

**Files:**
- Modify: `ThaiLifeTests/AudioPlaybackServiceTests.swift`
- Test fixture: `ThaiLife/Resources/Audio/audio-test-example.mp3` only if a deterministic valid fixture is needed; prefer existing bundle lookup behavior tests without committing generated audio.

- [ ] Add tests asserting `playSentence(audioID:text:)` is available, returns `.started` for a complete sentence, and falls back when the bundled example asset is absent.
- [ ] Run the focused test target/build and verify the new API is missing or behavior fails before implementation.

### Task 2: Implement MP3-first sentence playback

**Files:**
- Modify: `ThaiLife/Audio/AudioPlaybackService.swift`
- Modify: `ThaiLife/Features/Review/ReviewSessionViewModel.swift`

**Interfaces:**
- Produce `AudioPlaybackService.playSentence(audioID:text:) -> PlaybackResult`.
- Use `AVAudioPlayer` for `Audio/<audioID>.mp3` when present and valid.
- Fall back to the existing `AVSpeechSynthesizer` with `ThaiSpeechText.fullSentence(text)`.

- [ ] Implement audio-player lifecycle, interruption, restart, and delegate cleanup.
- [ ] Wire `playExampleAudio` to `playSentence` using `<item.audioID>-example`.
- [ ] Run audio tests/build-for-testing and verify success.

### Task 3: Extend Google Cloud TTS generation to examples

**Files:**
- Modify: `tools/generate_audio.py`
- Modify: `tools/generate_audio_manifest.py`
- Modify: `docs/AUDIO_PIPELINE.md`

- [ ] Add an example request for every non-empty `item.example` using `<audioID>-example` and the complete example text.
- [ ] Add explicit flags for replacing placeholder MP3s and/or generating examples only; preserve atomic writes.
- [ ] Make the manifest expect base assets plus derived example assets and map manifest IDs to the correct Thai text for collision checks.
- [ ] Verify `--dry-run` reports complete example sentences and the manifest script handles missing assets clearly.

### Task 4: Generate and audit assets when credentials are available

**Files:**
- Modify/Create: `ThaiLife/Resources/Audio/audio-*-example.mp3`
- Modify: `ThaiLife/Resources/Audio/audio-manifest.json`

- [ ] Require `GOOGLE_APPLICATION_CREDENTIALS` only at generation time.
- [ ] Generate all 654 example MP3s with Google Cloud TTS using the complete `example` field.
- [ ] Run manifest generation and verify no missing or orphan example assets.
- [ ] Sample-listen representative single-sentence and multi-clause examples.

### Task 5: Verify app behavior and install

**Files:**
- No new source files.

- [ ] Run `python3 tools/validate_content.py`.
- [ ] Run `xcodebuild ... build-for-testing` for the connected device.
- [ ] Run device build and install with `devicectl`.
- [ ] Confirm fallback behavior remains available if generated assets are not present in this environment; report any credential-dependent asset generation separately.
