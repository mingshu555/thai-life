#!/usr/bin/env python3
"""Validate the Thai Life content pack against schema and relationship rules.

Usage: python3 tools/validate_content.py
"""

import hashlib
import json
import sys
import os

try:
    from .generate_content import (
        CHUNK_BREAKDOWN_PATH,
        DIALOGUE_BREAKDOWN_PATH,
        EXAMPLE_COVERAGE_PATH,
        EXAMPLE_SOURCE_PATH,
        WORD_BREAKDOWN_PATH,
        load_chunk_breakdowns,
        load_dialogue_breakdowns,
        load_word_breakdowns,
        validate_chunk_breakdowns,
        validate_dialogue_breakdowns,
        validate_example_source,
        validate_word_breakdowns,
    )
except ImportError:
    from generate_content import (
        CHUNK_BREAKDOWN_PATH,
        DIALOGUE_BREAKDOWN_PATH,
        EXAMPLE_COVERAGE_PATH,
        EXAMPLE_SOURCE_PATH,
        WORD_BREAKDOWN_PATH,
        load_chunk_breakdowns,
        load_dialogue_breakdowns,
        load_word_breakdowns,
        validate_chunk_breakdowns,
        validate_dialogue_breakdowns,
        validate_example_source,
        validate_word_breakdowns,
    )


EXPECTED_COUNTS = {
    "basics": 160,
    "social": 90,
    "numbers": 110,
    "food_dining": 148,
    "shopping": 80,
    "home_living": 90,
    "transport": 100,
    "phone_network": 60,
    "health": 80,
    "safety": 50,
    "weather_leisure": 70,
    "airport": 50,
    "hotel": 60,
    "local_errands": 70,
    "google_maps": 62,
    "core_function": 124,
}

CATEGORY_NAMES = {
    "basics": "开口基础",
    "social": "社交与人际",
    "numbers": "数字、时间与数量",
    "food_dining": "饮食与点餐",
    "shopping": "购物与付款",
    "home_living": "家与日常生活",
    "transport": "交通与问路",
    "phone_network": "手机、网络与服务",
    "health": "身体、健康与药店",
    "safety": "安全与紧急求助",
    "weather_leisure": "天气、休闲与生活习惯",
    "airport": "机场与入境",
    "hotel": "酒店与景点",
    "local_errands": "本地办事",
    "google_maps": "Google地图常用词",
    "core_function": "核心功能词",
}

VALID_KINDS = {"word", "chunk", "sentence", "dialogue"}


def validate_manifest(items, manifest, items_bytes):
    errors = []
    if manifest.get("itemCount") != len(items):
        errors.append(f"Manifest itemCount={manifest.get('itemCount')} != actual={len(items)}")

    checksum = hashlib.sha256(items_bytes).hexdigest()
    if manifest.get("checksumSHA256") != checksum:
        errors.append(
            f"Manifest checksumSHA256={manifest.get('checksumSHA256')} != actual={checksum}"
        )

    return errors


def validate_chunk_breakdown_item(item: dict) -> list[str]:
    item_id = item.get("id", "<unknown>")
    breakdown = item.get("chunkBreakdown")
    if item.get("kind") != "chunk":
        return [f"Chunk breakdown unexpected for non-chunk: {item_id}"] if breakdown is not None else []
    if not isinstance(breakdown, dict):
        return [f"Chunk breakdown missing: {item_id}"]

    errors = []
    expected = "".join(str(item.get("thai", "")).split())
    for layer in ("combinations", "minimal"):
        segments = breakdown.get(layer)
        if not isinstance(segments, list) or not segments:
            errors.append(f"Chunk breakdown {layer} empty: {item_id}")
            continue
        reconstructed = []
        for segment in segments:
            if (
                not isinstance(segment, dict)
                or not isinstance(segment.get("thai"), str)
                or not segment["thai"].strip()
                or not isinstance(segment.get("gloss"), str)
                or not segment["gloss"].strip()
            ):
                errors.append(f"Chunk breakdown {layer} invalid segment: {item_id}")
                break
            reconstructed.append(segment["thai"])
        else:
            if "".join("".join(reconstructed).split()) != expected:
                errors.append(f"Chunk breakdown {layer} reconstruction failed: {item_id}")
    return errors



def validate_word_breakdown_item(item: dict) -> list[str]:
    item_id = item.get("id", "<unknown>")
    breakdown = item.get("wordBreakdown")
    if item.get("kind") != "word":
        return [f"Word breakdown unexpected for non-word: {item_id}"] if breakdown is not None else []
    if breakdown is None:
        return []
    if not isinstance(breakdown, dict):
        return [f"Word breakdown invalid: {item_id}"]

    errors = []
    expected = "".join(str(item.get("thai", "")).split())
    layers = {}
    for layer in ("combinations", "minimal"):
        segments = breakdown.get(layer)
        if not isinstance(segments, list) or not segments:
            errors.append(f"Word breakdown {layer} empty: {item_id}")
            continue
        if len(segments) < 2:
            errors.append(f"Word breakdown {layer} too small: {item_id}")
            continue
        reconstructed = []
        invalid = False
        for segment in segments:
            if (
                not isinstance(segment, dict)
                or not isinstance(segment.get("thai"), str)
                or not segment["thai"].strip()
                or not isinstance(segment.get("gloss"), str)
                or not segment["gloss"].strip()
            ):
                errors.append(f"Word breakdown {layer} invalid segment: {item_id}")
                invalid = True
                break
            reconstructed.append(segment["thai"])
        if invalid:
            continue
        if "".join("".join(reconstructed).split()) != expected:
            errors.append(f"Word breakdown {layer} reconstruction failed: {item_id}")
        else:
            layers[layer] = segments

    combinations = layers.get("combinations")
    minimal = layers.get("minimal")
    if combinations and minimal:
        rest = ["".join(segment["thai"].split()) for segment in minimal]
        ok = True
        for combo in combinations:
            target = "".join(combo["thai"].split())
            acc = ""
            used = 0
            while used < len(rest) and acc != target:
                acc += rest[used]
                used += 1
                if len(acc) > len(target):
                    ok = False
                    break
            if acc != target:
                ok = False
                break
            rest = rest[used:]
        if not ok or rest:
            errors.append(f"Word breakdown minimal does not refine combinations: {item_id}")

    example = item.get("example") or ""
    if str(example).strip() and combinations:
        headword = expected
        if headword not in "".join(str(example).split()):
            errors.append(f"Word breakdown example missing headword: {item_id}")
        segments = item.get("segments") or []
        if any("".join(str(segment.get("thai", "")).split()) == headword for segment in segments if isinstance(segment, dict)):
            errors.append(f"Word breakdown example still unsplit: {item_id}")
        span = None
        for start in range(len(segments)):
            acc = ""
            for end in range(start, len(segments)):
                acc += "".join(str(segments[end].get("thai", "")).split())
                if acc == headword:
                    span = segments[start : end + 1]
                    break
                if len(acc) > len(headword):
                    break
            if span is not None:
                break
        if span is None:
            errors.append(f"Word breakdown example missing headword: {item_id}")
        elif [segment.get("thai") for segment in span] != [combo["thai"] for combo in combinations] or [
            segment.get("gloss") for segment in span
        ] != [combo["gloss"] for combo in combinations]:
            errors.append(f"Word breakdown example span mismatch: {item_id}")
    return errors


def validate_dialogue_breakdown_item(item: dict) -> list[str]:
    item_id = item.get("id", "<unknown>")
    breakdown = item.get("dialogueBreakdown")
    if item.get("kind") != "dialogue":
        return [f"Dialogue breakdown unexpected for non-dialogue: {item_id}"] if breakdown is not None else []
    if not isinstance(breakdown, list) or not breakdown:
        return [f"Dialogue breakdown missing: {item_id}"]
    thai_lines = str(item.get("thai", "")).split("\n")
    meaning_lines = str(item.get("meaningZhHans", "")).split("\n")
    if len(thai_lines) != len(breakdown) or len(meaning_lines) != len(breakdown):
        return [f"Dialogue breakdown line count mismatch: {item_id}"]
    errors = []
    for index, turn in enumerate(breakdown):
        if not isinstance(turn, dict) or set(turn) != {"speaker", "thai", "meaningZhHans", "segments"}:
            errors.append(f"Dialogue breakdown invalid turn: {item_id}:{index}")
            continue
        prefix = f"{turn.get('speaker')}:"
        if not thai_lines[index].startswith(prefix) or not meaning_lines[index].startswith(prefix):
            errors.append(f"Dialogue breakdown speaker mismatch: {item_id}:{index}")
            continue
        if thai_lines[index][len(prefix):].strip() != turn.get("thai", "").strip() or meaning_lines[index][len(prefix):].strip() != turn.get("meaningZhHans", "").strip():
            errors.append(f"Dialogue breakdown line mismatch: {item_id}:{index}")
        segments = turn.get("segments")
        if not isinstance(segments, list) or not segments or any(not isinstance(segment, dict) or not str(segment.get("thai", "")).strip() or not str(segment.get("gloss", "")).strip() for segment in segments):
            errors.append(f"Dialogue breakdown invalid segments: {item_id}:{index}")
        elif "".join("".join(segment["thai"] for segment in segments).split()) != "".join(turn["thai"].split()):
            errors.append(f"Dialogue breakdown segment reconstruction failed: {item_id}:{index}")
    return errors


def validate():
    items_path = os.path.join(
        os.path.dirname(__file__), "..", "ThaiLife", "Resources", "Content", "items.json"
    )
    manifest_path = os.path.join(
        os.path.dirname(__file__), "..", "ThaiLife", "Resources", "Content", "content-manifest.json"
    )

    with open(items_path, "rb") as f:
        items_bytes = f.read()
    items = json.loads(items_bytes)

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    errors = []

    # Source/coverage contract. The source is intentionally checked here as
    # well as by the generator so a generated artifact cannot drift silently.
    if not EXAMPLE_SOURCE_PATH.exists():
        errors.append(f"Missing example source: {EXAMPLE_SOURCE_PATH}")
    elif not EXAMPLE_COVERAGE_PATH.exists():
        errors.append(f"Missing example coverage: {EXAMPLE_COVERAGE_PATH}")
    else:
        try:
            with EXAMPLE_SOURCE_PATH.open(encoding="utf-8") as source_file:
                example_source = json.load(source_file)
            with EXAMPLE_COVERAGE_PATH.open(encoding="utf-8") as coverage_file:
                example_coverage = json.load(coverage_file)
            validate_example_source(example_source, example_coverage, items)
            output_by_id = {item["id"]: item for item in items}
            for record in example_source["items"]:
                output = output_by_id[record["id"]]
                if output.get("example") != record["example"]:
                    errors.append(f"Generated example drifted: {record['id']}")
                if output.get("exampleMeaning") != record["exampleMeaning"]:
                    errors.append(f"Generated exampleMeaning drifted: {record['id']}")
                if output.get("segments") != record["segments"]:
                    errors.append(f"Generated segments drifted: {record['id']}")
        except (OSError, json.JSONDecodeError, ValueError, KeyError) as error:
            errors.append(f"Example source/coverage validation failed: {error}")

    # Chunk breakdown source contract and generated-output parity.
    if not CHUNK_BREAKDOWN_PATH.exists():
        errors.append(f"Missing chunk breakdown source: {CHUNK_BREAKDOWN_PATH}")
    else:
        try:
            chunk_source = load_chunk_breakdowns(CHUNK_BREAKDOWN_PATH)
            chunk_records = validate_chunk_breakdowns(chunk_source, items)
            for item in items:
                if item.get("kind") == "chunk" and item.get("chunkBreakdown") != chunk_records[item["id"]]:
                    errors.append(f"Generated chunk breakdown drifted: {item['id']}")
        except (OSError, json.JSONDecodeError, ValueError, KeyError) as error:
            errors.append(f"Chunk breakdown source validation failed: {error}")

    # Dialogue breakdown source contract and generated-output parity.
    if not DIALOGUE_BREAKDOWN_PATH.exists():
        errors.append(f"Missing dialogue breakdown source: {DIALOGUE_BREAKDOWN_PATH}")
    else:
        try:
            dialogue_source = load_dialogue_breakdowns(DIALOGUE_BREAKDOWN_PATH)
            dialogue_records = validate_dialogue_breakdowns(dialogue_source, items)
            for item in items:
                if item.get("kind") == "dialogue" and item.get("dialogueBreakdown") != dialogue_records[item["id"]]:
                    errors.append(f"Generated dialogue breakdown drifted: {item['id']}")
        except (OSError, json.JSONDecodeError, ValueError, KeyError) as error:
            errors.append(f"Dialogue breakdown source validation failed: {error}")

    # Word breakdown source contract and generated-output parity.
    if not WORD_BREAKDOWN_PATH.exists():
        errors.append(f"Missing word breakdown source: {WORD_BREAKDOWN_PATH}")
    else:
        try:
            word_source = load_word_breakdowns(WORD_BREAKDOWN_PATH)
            word_records = validate_word_breakdowns(word_source, items)
            for item in items:
                expected = word_records.get(item["id"]) if item.get("kind") == "word" else None
                actual = item.get("wordBreakdown")
                if expected is None:
                    if actual is not None:
                        errors.append(f"Generated word breakdown unexpected: {item['id']}")
                elif actual != expected:
                    errors.append(f"Generated word breakdown drifted: {item['id']}")
        except (OSError, json.JSONDecodeError, ValueError, KeyError) as error:
            errors.append(f"Word breakdown source validation failed: {error}")

    # Manifest check
    errors.extend(validate_manifest(items, manifest, items_bytes))

    # 1. Exact count
    if len(items) != 1404:
        errors.append(f"Total items: {len(items)} != 1404")

    # 2. Category counts
    counts = {}
    for item in items:
        cat = item.get("category", "")
        counts[cat] = counts.get(cat, 0) + 1
    for cat, expected in EXPECTED_COUNTS.items():
        actual = counts.get(cat, 0)
        if actual != expected:
            errors.append(f"Category {cat} ({CATEGORY_NAMES.get(cat, cat)}): {actual} != {expected}")

    # 3. Schema validation
    ids = set()
    for item in items:
        item_id = item.get("id", "")
        if not item_id:
            errors.append("Item missing id")
            continue
        if item_id in ids:
            errors.append(f"Duplicate id: {item_id}")
        ids.add(item_id)

        if not item.get("thai", "").strip():
            errors.append(f"Empty thai: {item_id}")
        if not item.get("romanization", "").strip() and item.get("kind") != "dialogue":
            errors.append(f"Empty romanization: {item_id}")
        if not item.get("meaningZhHans", "").strip():
            errors.append(f"Empty meaningZhHans: {item_id}")
        if not item.get("audioID", "").strip():
            errors.append(f"Empty audioID: {item_id}")
        if item.get("kind") not in VALID_KINDS:
            errors.append(f"Invalid kind '{item.get('kind')}' for: {item_id}")
        if item.get("category") not in EXPECTED_COUNTS:
            errors.append(f"Invalid category '{item.get('category')}' for: {item_id}")
        if not item.get("sourceID", "").strip():
            errors.append(f"Empty sourceID: {item_id}")
        if not isinstance(item.get("frequencyTier"), int) or item["frequencyTier"] < 0:
            errors.append(f"Invalid frequencyTier for: {item_id}")

        errors.extend(validate_chunk_breakdown_item(item))
        errors.extend(validate_dialogue_breakdown_item(item))
        errors.extend(validate_word_breakdown_item(item))
    # 4. Relationship integrity
    for item in items:
        item_id = item["id"]
        for pre_id in item.get("prerequisiteIDs", []):
            if pre_id == item_id:
                errors.append(f"Self-referencing prerequisite: {item_id}")
            elif pre_id not in ids:
                errors.append(f"Unknown prerequisite: {item_id} -> {pre_id}")
        for rel_id in item.get("relatedIDs", []):
            if rel_id not in ids:
                errors.append(f"Unknown related: {item_id} -> {rel_id}")

    # 5. Circular prerequisite detection
    adj = {item["id"]: item.get("prerequisiteIDs", []) for item in items}
    visited = set()
    stack = set()
    path = []

    def dfs(node):
        visited.add(node)
        stack.add(node)
        path.append(node)
        for nxt in adj.get(node, []):
            if nxt not in visited:
                if dfs(nxt):
                    return True
            elif nxt in stack:
                path.append(nxt)
                return True
        stack.discard(node)
        path.pop()
        return False

    for item in items:
        if item["id"] not in visited:
            path = []
            if dfs(item["id"]):
                errors.append(f"Circular prerequisite: {' -> '.join(path)}")
                break

    # 6. Segment reconstruction and structure validation
    for item in items:
        segments = item.get("segments", [])
        if not segments:
            continue

        for s in segments:
            if not isinstance(s, dict) or "thai" not in s or "gloss" not in s:
                errors.append(f"Invalid segment structure in {item['id']}: {s}")
                continue

        reconstructed = "".join(s.get("thai", "") for s in segments)
        example = (item.get("example") or "").strip()

        if example:
            if reconstructed.replace(" ", "") != example.replace(" ", ""):
                errors.append(
                    f"Segment reconstruction failed for example in {item['id']}: "
                    f"expected '{example}', got '{reconstructed}'"
                )
        else:
            if reconstructed.replace(" ", "") != item["thai"].replace(" ", ""):
                errors.append(
                    f"Segment reconstruction failed for headword in {item['id']}: "
                    f"expected '{item['thai']}', got '{reconstructed}'"
                )

    # 7. Placeholder detection
    placeholder_patterns = [
        "(练习)", "(practice)", "复习是学习的重要部分", "ทบทวน",
        "ประโยคตัวอย่าง", "实用表达 ",
    ]
    for item in items:
        for pat in placeholder_patterns:
            if pat in item["thai"] or pat.lower() in item.get("romanization", "").lower():
                errors.append(f"Placeholder content detected: {item['id']}: '{item['thai'][:50]}'")

    # 8. Duplicate Thai text detection
    from collections import Counter
    thai_counts = Counter((item["category"], item["thai"]) for item in items)
    dup_count = sum(1 for c in thai_counts.values() if c > 1)
    if dup_count > 0:
        errors.append(f"Duplicate Thai texts in same category: {dup_count} texts appear more than once")

    # 9. Mechanical exampleMeaning detection (matching ContentValidator.swift)
    import re
    for item in items:
        example = (item.get("example") or "").strip()
        ex_meaning = item.get("exampleMeaning")
        segments = item.get("segments", [])
        if example and not ex_meaning:
            errors.append(f"Missing exampleMeaning for {item['id']}")
        if ex_meaning and not example:
            errors.append(f"exampleMeaning without example for {item['id']}")
        if ex_meaning and segments:
            gloss_concat = "".join(s.get("gloss", "") for s in segments if isinstance(s, dict))
            norm_ex = re.sub(r"\([^)]*\)", "", ex_meaning).replace(" ", "")
            norm_gloss = re.sub(r"\([^)]*\)", "", gloss_concat).replace(" ", "")
            if norm_ex and norm_ex == norm_gloss:
                errors.append(f"Mechanical exampleMeaning in {item['id']}: '{ex_meaning}'")

    if errors:
        print("VALIDATION FAILED:")
        for e in errors:
            print(f"  ✗ {e}")
        sys.exit(1)

    print(f"validated {len(items)} items across {len(EXPECTED_COUNTS)} categories")


if __name__ == "__main__":
    validate()
