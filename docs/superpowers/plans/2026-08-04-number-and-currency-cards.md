# 数字与泰铢货币卡片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在“词根高频词族卡片”中新增 0–100 数字卡片和泰铢/萨当货币卡片，并覆盖小数点读法。

**Architecture:** 复用现有 `WordFamily` Codable 模型、`word_families.json` 内容包和 `WordFamilyCardView` UI。数字卡片通过少量关键数字条目加 `usageNote` 规律说明，货币卡片通过代表性金额条目加 `บาท`、`สตางค์` 和 `จุด` 规则说明实现，不新增专用 UI 或模型。

**Tech Stack:** SwiftUI, Swift Codable, XCTest, JSON content resources.

## Global Constraints

- 数字卡片覆盖 0–100；有规律的数字只展示规则和代表性示例，不穷举全部数字。
- 货币卡片必须包含泰铢 + 萨当表达，以及使用 `จุด` 的小数点读法。
- `WordFamily.itemCount` 必须与 `items.count` 一致。
- 不修改现有例句音频管线；新增条目使用完整泰语文本播放。

---

### Task 1: Add regression tests for the two new cards

**Files:**
- Modify: `ThaiLifeTests/WordFamilyTests.swift`

**Interfaces:**
- Consumes: `ContentRepository.loadWordFamilies() -> [WordFamily]`
- Produces: Tests that require `family-numbers-100` and `family-currency-thb` content and verify required phrases.

- [ ] **Step 1: Add tests for card presence, range rules, and currency forms**

Append these tests to `ThaiLifeTests/WordFamilyTests.swift`:

```swift
func testNumbersCard_CoversKeyFormsThroughOneHundred() {
    let families = ContentRepository.loadWordFamilies()
    let card = try! XCTUnwrap(families.first(where: { $0.id == "family-numbers-100" }))

    XCTAssertEqual(card.category, .basics)
    XCTAssertEqual(card.itemCount, card.items.count)
    XCTAssertTrue(card.usageNote.contains("11–19"))
    XCTAssertTrue(card.usageNote.contains("ยี่สิบ"))
    XCTAssertTrue(card.usageNote.contains("หนึ่งร้อย"))

    let thai = Set(card.items.map(\.thai))
    XCTAssertTrue(thai.contains("ศูนย์"))
    XCTAssertTrue(thai.contains("สิบเอ็ด"))
    XCTAssertTrue(thai.contains("ยี่สิบ"))
    XCTAssertTrue(thai.contains("ยี่สิบเอ็ด"))
    XCTAssertTrue(thai.contains("หนึ่งร้อย"))
}

func testCurrencyCard_IncludesBahtSatangAndDecimalPointForms() {
    let families = ContentRepository.loadWordFamilies()
    let card = try! XCTUnwrap(families.first(where: { $0.id == "family-currency-thb" }))

    XCTAssertEqual(card.category, .basics)
    XCTAssertEqual(card.itemCount, card.items.count)
    XCTAssertTrue(card.usageNote.contains("สตางค์"))
    XCTAssertTrue(card.usageNote.contains("จุด"))

    let thai = Set(card.items.map(\.thai))
    XCTAssertTrue(thai.contains("ยี่สิบเอ็ดบาท"))
    XCTAssertTrue(thai.contains("ห้าสิบสตางค์"))
    XCTAssertTrue(thai.contains("ยี่สิบเอ็ดบาทห้าสิบสตางค์"))
    XCTAssertTrue(thai.contains("ยี่สิบเอ็ดจุดห้าศูนย์"))
}
```

- [ ] **Step 2: Run the focused tests and verify they fail for missing cards**

Run:

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ThaiLifeDerivedData test -only-testing:ThaiLifeTests/WordFamilyTests
```

Expected: FAIL because the two new IDs are not yet in `word_families.json`.

---

### Task 2: Add the number and currency card content

**Files:**
- Modify: `ThaiLife/Resources/Content/word_families.json`

**Interfaces:**
- Consumes: `WordFamily` and `WordFamilyMember` Codable shape.
- Produces: Two additional JSON records loaded by `ContentRepository.loadWordFamilies()`.

- [ ] **Step 1: Add the 0–100 number card**

Add this record to the JSON array:

```json
{
  "id": "family-numbers-100",
  "rootThai": "ตัวเลข",
  "rootRomanization": "tua-lêek sǔun-thʉ̌ng-nʉ̀ng-rɔ́ɔi",
  "rootMeaningZhHans": "数字 0–100",
  "rootAudioID": "",
  "usageNote": "0–10 需要逐个记忆。11–19 通常由 สิบ 加个位组成；个位 1 放在十位后使用 เอ็ด，例如 สิบเอ็ด。20 是特殊形式 ยี่สิบ。21–99 通常按‘十位 + สิบ + 个位’组合，个位 1 使用 เอ็ด。100 读作 หนึ่งร้อย。有规律的数字不逐个列出。",
  "category": "basics",
  "itemCount": 20,
  "items": [
    { "id": "number-0", "thai": "ศูนย์", "romanization": "sǔun", "meaningZhHans": "0", "audioID": "audio-number-0" },
    { "id": "number-1", "thai": "หนึ่ง", "romanization": "nʉ̀ng", "meaningZhHans": "1", "audioID": "audio-number-1" },
    { "id": "number-2", "thai": "สอง", "romanization": "sɔ̌ɔng", "meaningZhHans": "2", "audioID": "audio-number-2" },
    { "id": "number-3", "thai": "สาม", "romanization": "sǎam", "meaningZhHans": "3", "audioID": "audio-number-3" },
    { "id": "number-4", "thai": "สี่", "romanization": "sìi", "meaningZhHans": "4", "audioID": "audio-number-4" },
    { "id": "number-5", "thai": "ห้า", "romanization": "hâa", "meaningZhHans": "5", "audioID": "audio-number-5" },
    { "id": "number-6", "thai": "หก", "romanization": "hòk", "meaningZhHans": "6", "audioID": "audio-number-6" },
    { "id": "number-7", "thai": "เจ็ด", "romanization": "jèt", "meaningZhHans": "7", "audioID": "audio-number-7" },
    { "id": "number-8", "thai": "แปด", "romanization": "bpɛ̀ɛt", "meaningZhHans": "8", "audioID": "audio-number-8" },
    { "id": "number-9", "thai": "เก้า", "romanization": "gâo", "meaningZhHans": "9", "audioID": "audio-number-9" },
    { "id": "number-10", "thai": "สิบ", "romanization": "sìp", "meaningZhHans": "10", "audioID": "audio-number-10" },
    { "id": "number-11", "thai": "สิบเอ็ด", "romanization": "sìp-èt", "meaningZhHans": "11", "audioID": "audio-number-11" },
    { "id": "number-20", "thai": "ยี่สิบ", "romanization": "yîi-sìp", "meaningZhHans": "20", "audioID": "audio-number-20" },
    { "id": "number-21", "thai": "ยี่สิบเอ็ด", "romanization": "yîi-sìp-èt", "meaningZhHans": "21", "audioID": "audio-number-21" },
    { "id": "number-30", "thai": "สามสิบ", "romanization": "sǎam-sìp", "meaningZhHans": "30", "audioID": "audio-number-30" },
    { "id": "number-40", "thai": "สี่สิบ", "romanization": "sìi-sìp", "meaningZhHans": "40", "audioID": "audio-number-40" },
    { "id": "number-50", "thai": "ห้าสิบ", "romanization": "hâa-sìp", "meaningZhHans": "50", "audioID": "audio-number-50" },
    { "id": "number-70", "thai": "เจ็ดสิบ", "romanization": "jèt-sìp", "meaningZhHans": "70", "audioID": "audio-number-70" },
    { "id": "number-90", "thai": "เก้าสิบ", "romanization": "gâo-sìp", "meaningZhHans": "90", "audioID": "audio-number-90" },
    { "id": "number-100", "thai": "หนึ่งร้อย", "romanization": "nʉ̀ng-rɔ́ɔi", "meaningZhHans": "100", "audioID": "audio-number-100" }
  ]
}
```

- [ ] **Step 2: Add the Thai baht and satang card**

Add this record immediately after the number card:

```json
{
  "id": "family-currency-thb",
  "rootThai": "บาท",
  "rootRomanization": "ngoen-bàat-lɛ́-sà-taang",
  "rootMeaningZhHans": "泰铢与萨当",
  "rootAudioID": "",
  "usageNote": "整数金额用‘数字 + บาท’。带小数的日常金额用‘整数 + บาท + 萨当数 + สตางค์’，例如 21.50 泰铢。只有小数部分时可以直接读萨当。强调数字本身的小数点时使用 จุด，并逐位读小数部分。有规律的金额不逐个列出。",
  "category": "basics",
  "itemCount": 8,
  "items": [
    { "id": "currency-1-baht", "thai": "หนึ่งบาท", "romanization": "nʉ̀ng bàat", "meaningZhHans": "1 泰铢", "audioID": "audio-currency-1-baht" },
    { "id": "currency-21-baht", "thai": "ยี่สิบเอ็ดบาท", "romanization": "yîi-sìp-èt bàat", "meaningZhHans": "21 泰铢", "audioID": "audio-currency-21-baht" },
    { "id": "currency-50-baht", "thai": "ห้าสิบบาท", "romanization": "hâa-sìp bàat", "meaningZhHans": "50 泰铢", "audioID": "audio-currency-50-baht" },
    { "id": "currency-100-baht", "thai": "หนึ่งร้อยบาท", "romanization": "nʉ̀ng-rɔ́ɔi bàat", "meaningZhHans": "100 泰铢", "audioID": "audio-currency-100-baht" },
    { "id": "currency-050-baht", "thai": "ห้าสิบสตางค์", "romanization": "hâa-sìp sà-taang", "meaningZhHans": "0.50 泰铢（50 萨当）", "audioID": "audio-currency-050-baht" },
    { "id": "currency-2150-baht", "thai": "ยี่สิบเอ็ดบาทห้าสิบสตางค์", "romanization": "yîi-sìp-èt bàat hâa-sìp sà-taang", "meaningZhHans": "21.50 泰铢", "audioID": "audio-currency-2150-baht" },
    { "id": "currency-325-baht", "thai": "สามบาทยี่สิบห้าสตางค์", "romanization": "sǎam bàat yîi-sìp-hâa sà-taang", "meaningZhHans": "3.25 泰铢", "audioID": "audio-currency-325-baht" },
    { "id": "currency-2150-decimal", "thai": "ยี่สิบเอ็ดจุดห้าศูนย์", "romanization": "yîi-sìp-èt jùt hâa sǔun", "meaningZhHans": "21.50（按小数点读）", "audioID": "audio-currency-2150-decimal" }
  ]
}
```

- [ ] **Step 3: Validate JSON shape and item counts**

Run:

```bash
python3 - <<'PY'
import json
p = 'ThaiLife/Resources/Content/word_families.json'
data = json.load(open(p))
for card_id in ('family-numbers-100', 'family-currency-thb'):
    card = next(card for card in data if card['id'] == card_id)
    assert card['itemCount'] == len(card['items'])
print('JSON cards valid')
PY
python3 tools/validate_content.py
```

Expected: JSON cards valid and content validation passes.

---

### Task 3: Run focused tests and project verification

**Files:**
- No source changes expected.

- [ ] **Step 1: Run WordFamily tests**

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ThaiLifeDerivedData test -only-testing:ThaiLifeTests/WordFamilyTests
```

Expected: PASS.

- [ ] **Step 2: Inspect the final diff for unrelated changes**

```bash
git diff --check
git diff -- ThaiLife/Resources/Content/word_families.json ThaiLifeTests/WordFamilyTests.swift
```

Expected: no whitespace errors; diff contains only the two cards and their tests.

- [ ] **Step 3: Build the app for the available simulator destination**

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ThaiLifeDerivedData build
```

Expected: BUILD SUCCEEDED.
