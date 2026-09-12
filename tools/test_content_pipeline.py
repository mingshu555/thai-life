import copy
import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from tools.validate_content import validate_manifest

from tools.generate_content import (
    CHUNK_BREAKDOWN_PATH,
    DIALOGUE_BREAKDOWN_PATH,
    EXAMPLE_COVERAGE_PATH,
    EXAMPLE_SOURCE_PATH,
    ROOT,
    WORD_BREAKDOWN_PATH,
    apply_chunk_breakdowns,
    apply_dialogue_breakdowns,
    apply_example_overlay,
    apply_existing_baseline_metadata,
    apply_word_breakdowns,
    generate_base_items,
    generate_to_paths,
    load_chunk_breakdowns,
    load_dialogue_breakdowns,
    load_example_coverage,
    load_example_source,
    load_word_breakdowns,
    serialize_generated_items,
    _validate_generated_output,
    validate_chunk_breakdowns,
    validate_dialogue_breakdowns,
    validate_example_source,
    validate_word_breakdowns,
)


class ContentPipelineTests(unittest.TestCase):
    def test_food_dining_words_are_grouped_as_base_food_then_fruit_then_drinks(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            output_root = Path(temp_dir)
            content_dir = output_root / "ThaiLife" / "Resources" / "Content"
            content_dir.mkdir(parents=True)
            shutil.copy(
                ROOT / "ThaiLife/Resources/Content/items.json",
                content_dir / "items.json",
            )

            generate_to_paths(load_example_source(), load_example_coverage(), output_root)
            items = json.loads((content_dir / "items.json").read_text(encoding="utf-8"))
            word_ids = [
                item["id"]
                for item in items
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

            self.assertEqual(word_ids[: len(expected_prefix)], expected_prefix)
            self.assertEqual(
                [item["id"] for item in items if item["id"] == "food_dining-word-060"],
                ["food_dining-word-060"],
            )


class ExampleContentPipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = load_example_source(EXAMPLE_SOURCE_PATH)
        cls.coverage = load_example_coverage(EXAMPLE_COVERAGE_PATH)
        cls.base_items = generate_base_items()

    @staticmethod
    def approved_source():
        source = copy.deepcopy(ExampleContentPipelineTests.source)
        for record in source["items"]:
            record["exampleMeaning"] = "这是一条例句。"
            record["review"] = {
                "status": "approved",
                "reviewedBy": "author-yaohuix",
                "reviewedAt": "2026-08-03",
            }
        return source

    def test_reports_stale_manifest_checksum(self):
        items_bytes = b'[{"id":"only-for-checksum"}]'
        expected_checksum = hashlib.sha256(items_bytes).hexdigest()
        errors = validate_manifest(
            items=[{"id": "only-for-checksum"}],
            manifest={"itemCount": 1, "checksumSHA256": "stale-checksum"},
            items_bytes=items_bytes,
        )

        self.assertEqual(
            errors,
            [
                "Manifest checksumSHA256=stale-checksum "
                f"!= actual={expected_checksum}"
            ],
        )

    def test_rejects_missing_coverage_id(self):
        source = self.approved_source()
        source["items"].pop()
        with self.assertRaises(ValueError):
            validate_example_source(source, self.coverage, self.base_items)

    def test_rejects_extra_or_unknown_coverage_id(self):
        source = self.approved_source()
        source["items"][0]["id"] = "unknown-word-001"
        with self.assertRaises(ValueError):
            validate_example_source(source, self.coverage, self.base_items)

    def test_rejects_unapproved_translation(self):
        source = copy.deepcopy(self.source)
        source["items"][0]["review"]["status"] = "needs-review"
        with self.assertRaises(ValueError):
            validate_example_source(source, self.coverage, self.base_items)

    def test_rejects_invalid_review_date(self):
        source = self.approved_source()
        source["items"][0]["review"]["reviewedAt"] = "2026-02-30"
        with self.assertRaises(ValueError):
            validate_example_source(source, self.coverage, self.base_items)

    def test_rejects_mechanical_gloss_after_parenthetical_normalization(self):
        source = self.approved_source()
        coverage = copy.deepcopy(self.coverage)
        record = source["items"][0]
        for index, segment in enumerate(record["segments"], start=1):
            segment["gloss"] = chr(ord("甲") + index)
        record["exampleMeaning"] = "".join(segment["gloss"] for segment in record["segments"]) + "(男)"
        baseline_payload = [
            {"id": item["id"], "example": item["example"], "segments": item["segments"]}
            for item in source["items"]
        ]
        coverage["baselineExampleSegmentsSHA256"] = hashlib.sha256(
            json.dumps(baseline_payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        ).hexdigest()
        with self.assertRaises(ValueError):
            validate_example_source(source, coverage, self.base_items)

    def test_rejects_unknown_source_coverage_record_review_and_segment_fields(self):
        mutations = [
            ("source", lambda source, coverage: source.update({"unexpected": True})),
            ("coverage", lambda source, coverage: coverage.update({"unexpected": True})),
            ("record", lambda source, coverage: source["items"][0].update({"unexpected": True})),
            ("review", lambda source, coverage: source["items"][0]["review"].update({"unexpected": True})),
            ("segment", lambda source, coverage: source["items"][0]["segments"][0].update({"unexpected": True})),
        ]
        for name, mutate in mutations:
            with self.subTest(name=name):
                source = self.approved_source()
                coverage = copy.deepcopy(self.coverage)
                mutate(source, coverage)
                if name == "segment":
                    baseline_payload = [
                        {"id": item["id"], "example": item["example"], "segments": item["segments"]}
                        for item in source["items"]
                    ]
                    coverage["baselineExampleSegmentsSHA256"] = hashlib.sha256(
                        json.dumps(baseline_payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
                    ).hexdigest()
                with self.assertRaises(ValueError):
                    validate_example_source(source, coverage, self.base_items)

    def test_rejects_example_or_segments_drift(self):
        source = self.approved_source()
        source["items"][0]["example"] += "!"
        with self.assertRaises(ValueError):
            validate_example_source(source, self.coverage, self.base_items)

    def test_rejects_mechanical_gloss_translation(self):
        source = self.approved_source()
        source["items"][0]["exampleMeaning"] = "".join(
            segment["gloss"] for segment in source["items"][0]["segments"]
        )
        with self.assertRaises(ValueError):
            validate_example_source(source, self.coverage, self.base_items)

    def test_accepts_natural_translation_without_gloss_concatenation(self):
        source = self.approved_source()
        source["items"][0]["exampleMeaning"] = "你好，最近还好吗？"
        validate_example_source(source, self.coverage, self.base_items)

    def test_overlay_copies_only_example_fields(self):
        source = self.approved_source()
        output = apply_example_overlay(self.base_items, source, self.coverage)
        output_by_id = {item["id"]: item for item in output}
        source_by_id = {item["id"]: item for item in source["items"]}
        base_by_id = {item["id"]: item for item in self.base_items}

        item_id = "basics-word-001"
        self.assertEqual(output_by_id[item_id]["example"], source_by_id[item_id]["example"])
        self.assertEqual(output_by_id[item_id]["segments"], source_by_id[item_id]["segments"])
        self.assertEqual(output_by_id[item_id]["exampleMeaning"], source_by_id[item_id]["exampleMeaning"])
        self.assertEqual(output_by_id[item_id]["meaningZhHans"], base_by_id[item_id]["meaningZhHans"])

    def test_preserves_existing_content_version_baseline(self):
        current_items = json.loads(
            Path("ThaiLife/Resources/Content/items.json").read_text(encoding="utf-8")
        )
        merged = apply_existing_baseline_metadata(self.base_items, current_items)
        current_by_id = {item["id"]: item for item in current_items}
        merged_by_id = {item["id"]: item for item in merged}
        self.assertEqual(merged_by_id["basics-word-031"]["contentVersion"], current_by_id["basics-word-031"]["contentVersion"])
        self.assertEqual(merged_by_id["basics-word-001"]["example"], current_by_id["basics-word-001"]["example"])
        self.assertEqual(merged_by_id["basics-word-001"]["segments"], current_by_id["basics-word-001"]["segments"])
        self.assertEqual(merged_by_id["basics-sent-086"]["segments"], current_by_id["basics-sent-086"]["segments"])

    def test_rejects_unexpected_existing_content_drift(self):
        current_items = json.loads(
            Path("ThaiLife/Resources/Content/items.json").read_text(encoding="utf-8")
        )
        current_items[0]["meaningZhHans"] = "unexpected drift"
        with self.assertRaises(ValueError):
            apply_existing_baseline_metadata(self.base_items, current_items)

    def test_rejects_generated_example_without_meaning(self):
        source = self.approved_source()
        output = apply_example_overlay(self.base_items, source, self.coverage)
        output[0]["exampleMeaning"] = ""
        with self.assertRaises(ValueError):
            _validate_generated_output(output, source, self.coverage)

    def test_rejects_generated_meaning_without_example(self):
        source = self.approved_source()
        output = apply_example_overlay(self.base_items, source, self.coverage)
        output[0]["example"] = ""
        with self.assertRaises(ValueError):
            _validate_generated_output(output, source, self.coverage)

    def test_invalid_source_is_rejected_before_any_output_write(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            output_root = Path(temp_dir)
            items_path = output_root / "ThaiLife/Resources/Content/items.json"
            manifest_path = output_root / "ThaiLife/Resources/Content/content-manifest.json"
            source = copy.deepcopy(self.source)
            source["items"][0]["review"]["status"] = "needs-review"

            with self.assertRaises(ValueError):
                generate_to_paths(source, self.coverage, output_root)

            self.assertFalse(items_path.exists())
            self.assertFalse(manifest_path.exists())

    def test_serialization_is_deterministic(self):
        source = self.approved_source()
        first = serialize_generated_items(apply_example_overlay(self.base_items, source, self.coverage))
        second = serialize_generated_items(apply_example_overlay(self.base_items, source, self.coverage))
        self.assertEqual(hashlib.sha256(first).hexdigest(), hashlib.sha256(second).hexdigest())



class ChunkBreakdownPipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base_items = generate_base_items()

    def test_rejects_missing_chunk_breakdown_record(self):
        source = copy.deepcopy(load_chunk_breakdowns(CHUNK_BREAKDOWN_PATH))
        source["items"].pop()

        with self.assertRaisesRegex(ValueError, "chunk breakdown IDs do not match generated chunk IDs"):
            validate_chunk_breakdowns(source, self.base_items)

    def test_rejects_unknown_or_duplicate_chunk_breakdown_id(self):
        for replacement in ("unknown-chunk-001", "basics-chunk-001"):
            with self.subTest(replacement=replacement):
                source = copy.deepcopy(load_chunk_breakdowns(CHUNK_BREAKDOWN_PATH))
                source["items"][-1]["id"] = replacement
                with self.assertRaisesRegex(ValueError, "chunk breakdown IDs do not match generated chunk IDs"):
                    validate_chunk_breakdowns(source, self.base_items)

    def test_rejects_empty_chunk_breakdown_layer_or_gloss(self):
        for mutate in (
            lambda source: source["items"][0].update({"combinations": []}),
            lambda source: source["items"][0]["minimal"][0].update({"gloss": ""}),
        ):
            with self.subTest(mutate=mutate):
                source = copy.deepcopy(load_chunk_breakdowns(CHUNK_BREAKDOWN_PATH))
                mutate(source)
                with self.assertRaises(ValueError):
                    validate_chunk_breakdowns(source, self.base_items)

    def test_rejects_chunk_breakdown_that_does_not_reconstruct_thai(self):
        source = copy.deepcopy(load_chunk_breakdowns(CHUNK_BREAKDOWN_PATH))
        source["items"][0]["minimal"] = [{"thai": "ผิด", "gloss": "错误"}]

        with self.assertRaisesRegex(ValueError, "minimal does not reconstruct chunk"):
            validate_chunk_breakdowns(source, self.base_items)

    def test_overlay_attaches_breakdowns_only_to_chunks(self):
        breakdowns = validate_chunk_breakdowns(
            load_chunk_breakdowns(CHUNK_BREAKDOWN_PATH), self.base_items
        )
        output = apply_chunk_breakdowns(copy.deepcopy(self.base_items), breakdowns)

        self.assertEqual(sum("chunkBreakdown" in item for item in output if item["kind"] == "chunk"), 215)
        self.assertEqual(sum("chunkBreakdown" in item for item in output if item["kind"] != "chunk"), 0)

    def test_chunk_breakdown_validator_reports_non_reconstructing_minimal_layer(self):
        from tools.validate_content import validate_chunk_breakdown_item

        item = {
            "id": "basics-chunk-001",
            "kind": "chunk",
            "thai": "ขอโทษ",
            "chunkBreakdown": {
                "combinations": [{"thai": "ขอโทษ", "gloss": "抱歉"}],
                "minimal": [{"thai": "ขอ", "gloss": "请求"}],
            },
        }

        self.assertEqual(
            validate_chunk_breakdown_item(item),
            ["Chunk breakdown minimal reconstruction failed: basics-chunk-001"],
        )

    def test_chunk_breakdown_validator_rejects_missing_and_unexpected_breakdowns(self):
        from tools.validate_content import validate_chunk_breakdown_item

        self.assertEqual(
            validate_chunk_breakdown_item({"id": "chunk", "kind": "chunk", "thai": "คำ"}),
            ["Chunk breakdown missing: chunk"],
        )
        self.assertEqual(
            validate_chunk_breakdown_item({
                "id": "word",
                "kind": "word",
                "thai": "คำ",
                "chunkBreakdown": {},
            }),
            ["Chunk breakdown unexpected for non-chunk: word"],
        )



class WordBreakdownPipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base_items = generate_base_items()
        cls.word_item = next(item for item in cls.base_items if item["id"] == "airport-word-016")

    def _source(self, **overrides):
        record = {
            "id": "airport-word-016",
            "combinations": [
                {"thai": "หมายเลข", "gloss": "号码"},
                {"thai": "เที่ยวบิน", "gloss": "航班"},
            ],
            "minimal": [
                {"thai": "หมาย", "gloss": "标记"},
                {"thai": "เลข", "gloss": "数字"},
                {"thai": "เที่ยว", "gloss": "趟；班次"},
                {"thai": "บิน", "gloss": "飞"},
            ],
        }
        record.update(overrides)
        source = {
            "schemaVersion": 1,
            "locale": "zh-Hans",
            "recordCount": 1,
            "items": [record],
        }
        return source

    def test_rejects_unknown_word_breakdown_id(self):
        source = self._source(id="unknown-word-001")
        with self.assertRaisesRegex(ValueError, "unknown word breakdown ID"):
            validate_word_breakdowns(source, self.base_items)

    def test_rejects_denied_word_breakdown_id(self):
        source = self._source(id="basics-word-001")
        source["items"][0]["combinations"] = [
            {"thai": "สวัส", "gloss": "a"},
            {"thai": "ดี", "gloss": "b"},
        ]
        source["items"][0]["minimal"] = source["items"][0]["combinations"]
        with self.assertRaisesRegex(ValueError, "deny list"):
            validate_word_breakdowns(source, self.base_items)

    def test_rejects_unsorted_ids(self):
        source = {
            "schemaVersion": 1,
            "locale": "zh-Hans",
            "recordCount": 2,
            "items": [
                {
                    "id": "airport-word-019",
                    "combinations": [
                        {"thai": "ตรวจ", "gloss": "检查"},
                        {"thai": "คนเข้าเมือง", "gloss": "入境"},
                    ],
                    "minimal": [
                        {"thai": "ตรวจ", "gloss": "检查"},
                        {"thai": "คน", "gloss": "人"},
                        {"thai": "เข้า", "gloss": "进入"},
                        {"thai": "เมือง", "gloss": "城/国家"},
                    ],
                },
                {
                    "id": "airport-word-016",
                    "combinations": [
                        {"thai": "หมายเลข", "gloss": "号码"},
                        {"thai": "เที่ยวบิน", "gloss": "航班"},
                    ],
                    "minimal": [
                        {"thai": "หมาย", "gloss": "标记"},
                        {"thai": "เลข", "gloss": "数字"},
                        {"thai": "เที่ยว", "gloss": "趟；班次"},
                        {"thai": "บิน", "gloss": "飞"},
                    ],
                },
            ],
        }
        with self.assertRaisesRegex(ValueError, "unique and sorted"):
            validate_word_breakdowns(source, self.base_items)

    def test_rejects_single_segment_layer(self):
        source = self._source(combinations=[{"thai": "หมายเลขเที่ยวบิน", "gloss": "航班号"}])
        with self.assertRaisesRegex(ValueError, "at least 2 segments"):
            validate_word_breakdowns(source, self.base_items)

    def test_rejects_layer_that_does_not_reconstruct_word(self):
        source = self._source(minimal=[{"thai": "หมาย", "gloss": "标记"}, {"thai": "เลข", "gloss": "数字"}])
        with self.assertRaisesRegex(ValueError, "minimal does not reconstruct word"):
            validate_word_breakdowns(source, self.base_items)

    def test_rejects_minimal_that_does_not_refine_combinations(self):
        source = self._source(
            combinations=[
                {"thai": "หมายเลข", "gloss": "号码"},
                {"thai": "เที่ยวบิน", "gloss": "航班"},
            ],
            minimal=[
                {"thai": "หมายเลขเที่ยว", "gloss": "号码加趟"},
                {"thai": "บิน", "gloss": "飞"},
            ],
        )
        with self.assertRaisesRegex(ValueError, "minimal does not refine combinations"):
            validate_word_breakdowns(source, self.base_items)

    def test_rejects_example_that_still_uses_whole_headword(self):
        items = copy.deepcopy(self.base_items)
        for item in items:
            if item["id"] == "airport-word-016":
                item["example"] = "หมายเลขเที่ยวบินคุณคืออะไรครับ"
                item["segments"] = [
                    {"thai": "หมายเลขเที่ยวบิน", "gloss": "航班号"},
                    {"thai": "คุณ", "gloss": "你"},
                ]
        source = self._source()
        with self.assertRaisesRegex(ValueError, "one segment"):
            validate_word_breakdowns(source, items)

    def test_overlay_attaches_breakdowns_only_to_listed_words(self):
        from tools.generate_content import (
            append_extra_food_dining_words,
            append_google_maps_words,
        )

        items = append_google_maps_words(append_extra_food_dining_words(copy.deepcopy(self.base_items)))
        items = apply_example_overlay(items, load_example_source(), load_example_coverage())
        source = load_word_breakdowns(WORD_BREAKDOWN_PATH)
        breakdowns = validate_word_breakdowns(source, items)
        output = apply_word_breakdowns(copy.deepcopy(items), breakdowns)
        listed = {record["id"] for record in source["items"]}
        self.assertTrue(listed)
        self.assertEqual(
            {item["id"] for item in output if "wordBreakdown" in item},
            listed,
        )
        self.assertTrue(all(item["kind"] == "word" for item in output if "wordBreakdown" in item))

    def test_word_breakdown_validator_rejects_unexpected_and_unsplit_example(self):
        from tools.validate_content import validate_word_breakdown_item

        self.assertEqual(
            validate_word_breakdown_item({
                "id": "chunk",
                "kind": "chunk",
                "thai": "คำ",
                "wordBreakdown": {"combinations": [], "minimal": []},
            }),
            ["Word breakdown unexpected for non-word: chunk"],
        )
        self.assertEqual(
            validate_word_breakdown_item({"id": "word", "kind": "word", "thai": "คำ"}),
            [],
        )


class DialogueBreakdownPipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base_items = generate_base_items()

    def test_rejects_missing_dialogue_breakdown_record(self):
        source = copy.deepcopy(load_dialogue_breakdowns(DIALOGUE_BREAKDOWN_PATH))
        source["items"].pop()
        source["recordCount"] -= 1
        with self.assertRaisesRegex(ValueError, "dialogue breakdown IDs do not match generated dialogue IDs"):
            validate_dialogue_breakdowns(source, self.base_items)

    def test_rejects_dialogue_turn_with_nonreconstructing_segments(self):
        source = copy.deepcopy(load_dialogue_breakdowns(DIALOGUE_BREAKDOWN_PATH))
        source["items"][0]["turns"][0]["segments"] = [{"thai": "ผิด", "gloss": "错误"}]
        with self.assertRaisesRegex(ValueError, "segments do not reconstruct Thai"):
            validate_dialogue_breakdowns(source, self.base_items)

    def test_overlay_attaches_breakdowns_only_to_dialogues(self):
        breakdowns = validate_dialogue_breakdowns(load_dialogue_breakdowns(DIALOGUE_BREAKDOWN_PATH), self.base_items)
        output = apply_dialogue_breakdowns(copy.deepcopy(self.base_items), breakdowns)
        self.assertEqual(sum("dialogueBreakdown" in item for item in output if item["kind"] == "dialogue"), 11)
        self.assertEqual(sum("dialogueBreakdown" in item for item in output if item["kind"] != "dialogue"), 0)


class CoreFunctionWordsTests(unittest.TestCase):
    def test_appends_124_function_word_cards_with_examples(self):
        from tools.generate_content import append_core_function_words

        items = append_core_function_words([])
        self.assertEqual(len(items), 124)
        self.assertEqual({item["category"] for item in items}, {"core_function"})
        self.assertEqual(items[0]["id"], "core_function-word-001")
        self.assertEqual(items[0]["thai"], "เป็น")
        self.assertTrue(all(item["kind"] == "word" for item in items))
        self.assertTrue(all((item.get("example") or "").strip() for item in items))
        self.assertTrue(all((item.get("exampleMeaning") or "").strip() for item in items))
        self.assertTrue(all(item.get("segments") for item in items))
        for item in items:
            reconstructed = "".join(segment["thai"] for segment in item["segments"])
            self.assertEqual("".join(reconstructed.split()), "".join(item["example"].split()), item["id"])
            self.assertIn(item["thai"].replace(" ", ""), item["example"].replace(" ", ""), item["id"])


if __name__ == "__main__":
    unittest.main()

