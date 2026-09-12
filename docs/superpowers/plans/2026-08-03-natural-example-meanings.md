# Natural Example Meanings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 654 条例句的中文翻译改为逐条审校后的自然简体中文，同时建立不会被内容生成器覆盖的确定性源、覆盖契约和 fail-closed 校验。

**Architecture:** `tools/example_content.json` 保存 654 条例句的完整 `example`、`segments` 与独立 `exampleMeaning`；`tools/example_content_coverage.json` 保存固定的 654-ID 集合、分类计数和基线 checksum。`tools/generate_content.py` 先生成 1,200 条基础内容，再在内存中严格校验并 overlay 例句字段，最后才写出 `items.json` 和 `content-manifest.json`。Python 负责源/生成期完整校验，Swift 只负责 Bundle 内容验收和运行时机械风险检查。

**Tech Stack:** Python 3 标准库、JSON、Swift/XCTest、Xcode `xcodebuild`、现有 MP3 manifest 审计工具。

---

## 文件责任边界

| 文件 | 责任 |
| --- | --- |
| `tools/example_content.json` | 654 条例句的唯一可维护源；保留当前 `example` 与 `segments`，只修订 `exampleMeaning`，保存审校状态。 |
| `tools/example_content_coverage.json` | 固定 654 条 expected IDs、category counts，以及迁移基线的 `example`/`segments` 内容 checksum；普通生成流程不得重写。 |
| `tools/generate_content.py` | 生成基础内容、加载两个源文件、执行严格 overlay、校验后原子写出两个内容产物。不得自动翻译。 |
| `tools/validate_content.py` | 独立检查生成产物、源/产物覆盖、例句字段成对关系、segment 重组和机械拼接风险。 |
| `tools/test_content_pipeline.py` | Python 单元/集成测试，覆盖源 schema、coverage、overlay、fail-closed 和确定性。 |
| `ThaiLife/Data/ContentValidator.swift` | Bundle 内结构、例句字段成对关系、654 条数量和 mechanical gloss 拼接的运行时硬校验。 |
| `ThaiLifeTests/ContentValidatorTests.swift` | Swift validator 的机械翻译、自然翻译、缺字段和 segment 回归测试。 |
| `ThaiLifeTests/ContentAcceptanceTests.swift` | Bundle 总量、分类量、654 条例句覆盖和 manifest 验收。 |
| `README.md`、`docs/CONTENT_AUTHORING.md` | 说明源文件→生成器→校验流程，禁止手改产物，并明确例句只改中文翻译。 |
| `ThaiLife/Resources/Content/items.json` | 生成产物；只在自然翻译完成并通过 gate 后更新。 |
| `ThaiLife/Resources/Content/content-manifest.json` | 最终 `items.json` 的生成 checksum；只由生成器更新。 |

禁止修改：`ContentItem` 模型、`ThaiLife/Features/Review/`、`ThaiLife/Features/Catalog/`、`AudioPlaybackService`、任何 MP3 文件、`romanization` 数据和音频文本。

---

## Task 1: 建立当前 654 条的 source 与 coverage 基线

**Files:**
- Create: `tools/example_content.json`
- Create: `tools/example_content_coverage.json`
- Read-only input: `ThaiLife/Resources/Content/items.json`

### Step 1: 写入只读迁移命令

从当前 `items.json` 提取所有 `example` 非空的条目，按 `id` 排序。迁移必须复制 `example` 字符串和 `segments` 数组中的每个对象、顺序、`thai`、`gloss`；迁移阶段不修改这些字段。旧 `exampleMeaning` 只作为待修订输入，状态必须设置为 `needs-review`，不能设置为 `approved`。

```bash
python3 - <<'PY'
import hashlib
import json
from pathlib import Path

root = Path.cwd()
items_path = root / "ThaiLife/Resources/Content/items.json"
source_path = root / "tools/example_content.json"
coverage_path = root / "tools/example_content_coverage.json"

items = json.loads(items_path.read_text(encoding="utf-8"))
example_items = sorted((item for item in items if item.get("example")), key=lambda item: item["id"])
assert len(example_items) == 654
assert all(item["kind"] == "word" for item in example_items)

records = []
for item in example_items:
    records.append({
        "id": item["id"],
        "example": item["example"],
        "exampleMeaning": item.get("exampleMeaning", ""),
        "segments": item["segments"],
        "review": {
            "status": "needs-review",
            "reviewedBy": "",
            "reviewedAt": "",
        },
    })

category_counts = {}
for item in example_items:
    category_counts[item["category"]] = category_counts.get(item["category"], 0) + 1
expected_category_counts = {
    "basics": 40,
    "social": 40,
    "numbers": 40,
    "food_dining": 59,
    "shopping": 40,
    "home_living": 45,
    "transport": 50,
    "phone_network": 40,
    "health": 50,
    "safety": 50,
    "weather_leisure": 50,
    "airport": 50,
    "hotel": 50,
    "local_errands": 50,
}
assert category_counts == expected_category_counts

baseline_payload = [
    {"id": record["id"], "example": record["example"], "segments": record["segments"]}
    for record in records
]
baseline_bytes = json.dumps(
    baseline_payload, ensure_ascii=False, separators=(",", ":")
).encode("utf-8")

source_path.write_text(
    json.dumps({
        "schemaVersion": 1,
        "locale": "zh-Hans",
        "recordCount": 654,
        "items": records,
    }, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
coverage_path.write_text(
    json.dumps({
        "schemaVersion": 1,
        "recordCount": 654,
        "categoryCounts": expected_category_counts,
        "expectedIDs": [record["id"] for record in records],
        "baselineExampleSegmentsSHA256": hashlib.sha256(baseline_bytes).hexdigest(),
    }, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY
```

Expected: two new files; exactly 654 source records; `categoryCounts` exactly matches the approved mapping; no `example` or `segments` values are authored manually in this step.

### Step 2: Verify the migration preserves the current baseline

```bash
python3 - <<'PY'
import json
from pathlib import Path

items = json.loads(Path("ThaiLife/Resources/Content/items.json").read_text(encoding="utf-8"))
source = json.loads(Path("tools/example_content.json").read_text(encoding="utf-8"))
by_id = {item["id"]: item for item in items if item.get("example")}
assert len(source["items"]) == 654
for record in source["items"]:
    baseline = by_id[record["id"]]
    assert record["example"] == baseline["example"]
    assert record["segments"] == baseline["segments"]
print("baseline example and segments preserved for 654 records")
PY
```

Expected: `baseline example and segments preserved for 654 records`.

### Step 3: Commit only the source/baseline files

```bash
git add tools/example_content.json tools/example_content_coverage.json
git commit -m "content: add example translation source baseline"
```

After the commit, send r1 the commit hash and the two-file diff. Do not run the production generator yet because all records are still `needs-review`.

---

## Task 2: Add fail-closed generator overlay and Python tests

**Files:**
- Modify: `tools/generate_content.py`
- Modify: `tools/validate_content.py`
- Create: `tools/test_content_pipeline.py`

### Step 1: Write failing Python tests

Create `tools/test_content_pipeline.py` with `unittest` tests for these public generator helpers:

```python
class ExampleContentPipelineTests(unittest.TestCase):
    def test_rejects_missing_coverage_id(self):
        with self.assertRaises(ValueError, msg="missing expected ID must fail closed"):
            validate_example_source(source_without_one_record, coverage)

    def test_rejects_extra_or_unknown_coverage_id(self):
        with self.assertRaises(ValueError):
            validate_example_source(source_with_unknown_id, coverage)

    def test_rejects_unapproved_translation(self):
        with self.assertRaises(ValueError):
            validate_example_source(source_with_needs_review_record, coverage)

    def test_rejects_example_or_segments_drift(self):
        with self.assertRaises(ValueError):
            validate_example_source(source_with_changed_example, coverage)

    def test_rejects_mechanical_gloss_translation(self):
        with self.assertRaises(ValueError):
            validate_example_source(source_with_gloss_concatenation, coverage)

    def test_accepts_natural_translation_without_gloss_concatenation(self):
        validate_example_source(source_with_natural_translation, coverage)

    def test_overlay_copies_only_example_fields(self):
        output = apply_example_overlay(base_items, source, coverage)
        self.assertEqual(output_by_id["basics-word-001"]["example"], source_by_id["basics-word-001"]["example"])
        self.assertEqual(output_by_id["basics-word-001"]["segments"], source_by_id["basics-word-001"]["segments"])
        self.assertEqual(output_by_id["basics-word-001"]["exampleMeaning"], source_by_id["basics-word-001"]["exampleMeaning"])
        self.assertEqual(output_by_id["basics-word-001"]["meaningZhHans"], base_by_id["basics-word-001"]["meaningZhHans"])

    def test_invalid_source_is_rejected_before_any_output_write(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            before = snapshot_paths(temp_dir)
            with self.assertRaises(ValueError):
                generate_to_paths(invalid_source, coverage, temp_dir)
            self.assertEqual(before, snapshot_paths(temp_dir))

    def test_serialization_is_deterministic(self):
        first = serialize_generated_items(apply_example_overlay(base_items, source, coverage))
        second = serialize_generated_items(apply_example_overlay(base_items, source, coverage))
        self.assertEqual(hashlib.sha256(first).hexdigest(), hashlib.sha256(second).hexdigest())
```

Use small in-memory fixtures for the tests; do not build the test around the full 654 translations. The fixture must include both a mechanical gloss concatenation and a fluent translation so the exact-gloss guard is proven to reject and accept the correct cases.

### Step 2: Run the Python tests and verify RED

```bash
python3 -m unittest -v tools.test_content_pipeline
```

Expected: FAIL because the source loader, coverage validator, overlay function, and atomic generation helper do not exist yet. Fix test import/setup errors until the failures are specifically missing behavior rather than malformed tests.

### Step 3: Implement source and coverage helpers

Add deterministic paths rooted at the repository rather than the caller’s current directory:

```python
ROOT = Path(__file__).resolve().parents[1]
EXAMPLE_SOURCE_PATH = ROOT / "tools/example_content.json"
EXAMPLE_COVERAGE_PATH = ROOT / "tools/example_content_coverage.json"

EXPECTED_EXAMPLE_CATEGORY_COUNTS = {
    "basics": 40, "social": 40, "numbers": 40,
    "food_dining": 59, "shopping": 40, "home_living": 45,
    "transport": 50, "phone_network": 40, "health": 50,
    "safety": 50, "weather_leisure": 50, "airport": 50,
    "hotel": 50, "local_errands": 50,
}
```

Implement these functions in `tools/generate_content.py`:

```python
def load_example_source(path: Path = EXAMPLE_SOURCE_PATH) -> dict: ...
def load_example_coverage(path: Path = EXAMPLE_COVERAGE_PATH) -> dict: ...
def validate_example_source(source: dict, coverage: dict, base_items: list[dict]) -> None: ...
def apply_example_overlay(base_items: list[dict], source: dict, coverage: dict) -> list[dict]: ...
def serialize_generated_items(items: list[dict]) -> bytes: ...
def generate_to_paths(source: dict, coverage: dict, output_root: Path) -> None: ...
```

The implementation must enforce all of the following before any `open(..., "w")` or `os.replace` call:

- `schemaVersion == 1`, `locale == "zh-Hans"`, and source `recordCount == 654`.
- Coverage `schemaVersion == 1`, `recordCount == 654`, exact fixed category counts, exactly 654 unique sorted `expectedIDs`, and `baselineExampleSegmentsSHA256` matching the canonical `{id, example, segments}` payload.
- Source IDs equal coverage IDs and each ID exists in the 1,200 generated base items.
- Every record has non-empty `example`, `exampleMeaning`, and `segments`; every review status is `approved` for production generation.
- `segments[].thai` joined with only whitespace normalization equals `example`; no punctuation deletion or fuzzy matching.
- The source `example` and `segments` remain equal to the baseline payload represented by the coverage checksum.
- `exampleMeaning` is not empty, does not contain known segment-label residue (`礼貌语气词`, `语气词`, `…的是`), and does not equal normalized concatenated glosses.
- Overlay changes only `example`, `exampleMeaning`, and `segments`; all other generated fields remain from the base item.
- The final output has exactly 1,200 items and exactly 654 non-empty examples, with source/output equality for all three example fields.

Use `json.dumps(..., ensure_ascii=False, indent=2) + "\n"` for stable output. Compute the manifest from those final serialized bytes. Write both output files to sibling temporary files and replace only after all validations and serialization have succeeded; invalid source must leave existing `items.json` and `content-manifest.json` untouched.

### Step 4: Run the Python tests and verify GREEN

```bash
python3 -m unittest -v tools.test_content_pipeline
python3 tools/validate_content.py
```

Expected: all pipeline tests pass. The repository’s current source is still `needs-review`, so the production generator must fail closed with an explicit unapproved-status error rather than overwrite `items.json`; do not change the source status in this task.

### Step 5: Commit generator and Python validation changes

```bash
git add tools/generate_content.py tools/validate_content.py tools/test_content_pipeline.py
git commit -m "feat: add fail-closed example content overlay"
```

Send r1 the commit hash, changed files, test output, and proof that an invalid/unapproved source did not change the two content outputs.

---

## Task 3: Replace all 654 translations and generate content artifacts

**Files:**
- Modify: `tools/example_content.json`
- Modify: `ThaiLife/Resources/Content/items.json`
- Modify: `ThaiLife/Resources/Content/content-manifest.json`
- Do not modify: `ThaiLife/Resources/Audio/*`

### Step 1: Create a translation-only diff guard before editing values

Run a baseline comparison that stores the current source payload for `id`, `example`, and `segments`. After translation edits, the guard must report that only `exampleMeaning` and the review metadata changed:

```bash
python3 - <<'PY'
import json
from pathlib import Path

source = json.loads(Path("tools/example_content.json").read_text(encoding="utf-8"))
assert source["recordCount"] == 654
for record in source["items"]:
    assert record["example"]
    assert record["segments"]
    assert record["review"]["status"] in {"needs-review", "approved"}
print("translation source has 654 complete records")
PY
```

### Step 2: Rewrite `exampleMeaning` in stable category batches

Edit only `exampleMeaning`, `review.status`, `review.reviewedBy`, and `review.reviewedAt` in the 654 source records. Keep records sorted by ID. Use natural simplified Chinese sentence translations, preserving sentence intent and natural Chinese word order. Do not copy the previous mechanical values, concatenate glosses, alter `example`, or alter any segment object.

Complete and review batches in this exact order so each batch is auditable:

1. `basics`: 40
2. `social`: 40
3. `numbers`: 40
4. `food_dining`: 59
5. `shopping`: 40
6. `home_living`: 45
7. `transport`: 50
8. `phone_network`: 40
9. `health`: 50
10. `safety`: 50
11. `weather_leisure`: 50
12. `airport`: 50
13. `hotel`: 50
14. `local_errands`: 50

For every record, set:

```json
"review": {
  "status": "approved",
  "reviewedBy": "author-yaohuix",
  "reviewedAt": "2026-08-03"
}
```

A batch is not complete until its translations are fluent, punctuation is appropriate, known segment-label residue is absent, and its `example` and `segments` match the pre-edit baseline exactly.

### Step 3: Run translation source quality gates before generating artifacts

```bash
python3 -m unittest -v tools.test_content_pipeline
python3 - <<'PY'
import json
from pathlib import Path

source = json.loads(Path("tools/example_content.json").read_text(encoding="utf-8"))
assert source["recordCount"] == 654
assert len(source["items"]) == 654
assert all(item["review"]["status"] == "approved" for item in source["items"])
assert all(item["review"]["reviewedBy"] == "author-yaohuix" for item in source["items"])
assert all(item["review"]["reviewedAt"] == "2026-08-03" for item in source["items"])
assert all("礼貌语气词" not in item["exampleMeaning"] for item in source["items"])
assert all("语气词" not in item["exampleMeaning"] for item in source["items"])
assert all("…的是" not in item["exampleMeaning"] for item in source["items"])
print("654 translations are approved and free of known segment-label residue")
PY
```

Expected: all tests pass and exactly 654 records are approved. If any source field other than `exampleMeaning` or review metadata differs from the baseline, stop and restore that field before proceeding.

### Step 4: Generate the two content artifacts through the guarded generator

```bash
python3 tools/generate_content.py
python3 tools/validate_content.py
```

Expected: generator reports 1,200 items and writes only `items.json` and `content-manifest.json`; validator reports 1,200 items across 14 categories, 654 example-bearing IDs, and no mechanical translation errors.

### Step 5: Verify artifact equality and unchanged non-translation fields

```bash
python3 - <<'PY'
import json
from pathlib import Path

source = json.loads(Path("tools/example_content.json").read_text(encoding="utf-8"))
items = json.loads(Path("ThaiLife/Resources/Content/items.json").read_text(encoding="utf-8"))
by_id = {item["id"]: item for item in items}
assert len(source["items"]) == 654
for record in source["items"]:
    output = by_id[record["id"]]
    assert output["example"] == record["example"]
    assert output["exampleMeaning"] == record["exampleMeaning"]
    assert output["segments"] == record["segments"]
assert sum(bool(item.get("example")) for item in items) == 654
assert sum(bool(item.get("exampleMeaning")) for item in items) == 654
print("generated items preserve source example fields and contain 654 translations")
PY
```

### Step 6: Commit source translations and generated artifacts

```bash
git add tools/example_content.json ThaiLife/Resources/Content/items.json ThaiLife/Resources/Content/content-manifest.json
git commit -m "content: add natural Chinese example meanings"
```

Send r1 the commit hash, category-by-category counts, representative translation diff, source/output equality result, and confirmation that no audio file changed.

---

## Task 4: Add Swift Bundle checks, documentation, and final verification

**Files:**
- Modify: `ThaiLife/Data/ContentValidator.swift`
- Modify: `ThaiLifeTests/ContentValidatorTests.swift`
- Modify: `ThaiLifeTests/ContentAcceptanceTests.swift`
- Modify: `README.md`
- Modify: `docs/CONTENT_AUTHORING.md`

### Step 1: Write failing Swift tests

Add tests for:

```swift
func testValidatorRejectsExampleWithoutMeaning() { /* example != nil, exampleMeaning == nil */ }
func testValidatorRejectsMeaningWithoutExample() { /* example == nil, exampleMeaning != nil */ }
func testValidatorRejectsMechanicalGlossConcatenation() { /* existing regression */ }
func testValidatorAcceptsNaturalExampleMeaning() { /* “你从哪里来？” */ }
func testBundledContentContainsExactly654ExampleTranslations() throws { /* count and pair */ }
```

Run the focused tests before implementation:

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -destination 'id=D9FCDAC2-B578-4567-9BFB-3F87C500EFDF' \
  -only-testing:ThaiLifeTests/ContentValidatorTests \
  -only-testing:ThaiLifeTests/ContentAcceptanceTests test -quiet
```

Expected: the new assertions fail against the pre-change validator or current content where the assertion describes newly enforced behavior. Existing unrelated tests must still compile.

### Step 2: Implement minimal Swift validation

Extend `ContentValidator.ValidationError` with explicit example-pair errors if needed, then validate:

- non-empty `example` requires non-empty `exampleMeaning` and `segments`;
- non-empty `exampleMeaning` requires non-empty `example`;
- example segments recompose the complete example after only whitespace normalization;
- normalized full-gloss equality remains a hard error;
- no runtime source-file dependency is introduced.

Keep `ContentItem` unchanged. Do not add translation generation, UI normalization, or forbidden-label heuristics that could claim to prove naturalness.

Add Bundle acceptance assertions for 654 examples and the fixed category counts from the coverage contract. The Swift target may validate the packaged count/IDs without loading `tools/example_content_coverage.json`.

### Step 3: Run focused Swift tests and verify GREEN

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -destination 'id=D9FCDAC2-B578-4567-9BFB-3F87C500EFDF' \
  -only-testing:ThaiLifeTests/ContentValidatorTests \
  -only-testing:ThaiLifeTests/ContentAcceptanceTests test -quiet
```

Expected: exit 0; the output must show no failing selected tests. Keep the available simulator UDID rather than the unavailable `iPhone 16` name.

### Step 4: Update documentation without changing unrelated behavior

Update `README.md` and `docs/CONTENT_AUTHORING.md` to state:

- `tools/example_content.json` is the edit source;
- `tools/example_content_coverage.json` is a fixed baseline contract;
- `items.json` and `content-manifest.json` are generated artifacts and must not be hand-edited;
- `exampleMeaning` is authored independently from `segments[].gloss`;
- current `example` text and `segments` are preserved and are not part of this translation change;
- the required command order is source validation → guarded generation → content validation → Swift/Bundle tests.

Do not document a generator command that bypasses the source or coverage gate.

### Step 5: Run full required verification

```bash
python3 -m unittest -v tools.test_content_pipeline
python3 tools/validate_content.py
python3 tools/generate_audio_manifest.py
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -destination 'id=D9FCDAC2-B578-4567-9BFB-3F87C500EFDF' \
  test -quiet
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -configuration Debug \
  -destination 'id=00008132-000129560AB9001C' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration build
```

Expected final evidence:

- Python pipeline and content validator pass.
- Audio manifest audits 1,854 MP3 assets with no missing, orphan, wrong-format, or undecodable entries; no MP3 file checksum or Thai audio text changes.
- Swift tests pass, including 654 example translation coverage.
- Simulator test and connected-device build pass.
- `git diff --name-only` shows only the approved task files; no audio files, model files, UI files, or unrelated workspace changes are included in the task commits.

### Step 6: Commit Swift/docs/verification changes

```bash
git add ThaiLife/Data/ContentValidator.swift \
  ThaiLifeTests/ContentValidatorTests.swift \
  ThaiLifeTests/ContentAcceptanceTests.swift \
  README.md docs/CONTENT_AUTHORING.md
git commit -m "test: enforce natural example translation coverage"
```

Send r1 the final commit hash and complete verification table before claiming completion.

---

## Review checkpoints

After each task commit, pause implementation and send r1:

1. commit hash and exact changed files;
2. `git diff --check` result;
3. focused tests and their exit status;
4. source/coverage counts and any generated artifact checksums;
5. explicit confirmation that `example` and `segments` are unchanged;
6. explicit confirmation that no audio/model/UI/playback file changed.

Do not proceed to the next task if r1 identifies a source-field drift, coverage mismatch, non-fail-closed write, mechanical translation, or forbidden file change. The 654-translation task is complete only after all four task commits and the final r1 review.
