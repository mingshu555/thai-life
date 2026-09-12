"""Unit tests for bounded Google TTS request selection.

These tests deliberately exercise request construction only; no credentials or
Google API calls are required.
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_audio import audio_requests, menu_audio_requests


class GenerateAudioRequestTests(unittest.TestCase):
    def setUp(self):
        self.items = [
            {
                "audioID": "audio-food_dining-word-060",
                "thai": "มะม่วง",
                "example": "ผมชอบมะม่วงครับ",
            },
            {
                "audioID": "audio-food_dining-word-061",
                "thai": "ทุเรียน",
            },
        ]

    def test_audio_id_filter_returns_only_requested_primary_content_item(self):
        self.assertEqual(
            list(audio_requests(self.items, audio_ids={"audio-food_dining-word-060"})),
            [("audio-food_dining-word-060", "มะม่วง")],
        )

    def test_audio_id_filter_rejects_unknown_content_audio_id(self):
        with self.assertRaisesRegex(ValueError, "unknown primary audio ID"):
            list(audio_requests(self.items, audio_ids={"audio-food_dining-word-999"}))

    def test_audio_id_filter_cannot_be_combined_with_examples_or_segments(self):
        target = {"audio-food_dining-word-060"}
        with self.assertRaisesRegex(ValueError, "cannot be combined"):
            list(audio_requests(self.items, examples_only=True, audio_ids=target))
        with self.assertRaisesRegex(ValueError, "cannot be combined"):
            list(audio_requests(self.items, segments_only=True, audio_ids=target))

    def test_menu_segment_requests_are_supported_separately(self):
        cards = [{
            "audioID": "thai-menu-test",
            "thai": "ผัดไทย",
            "breakdown": {
                "combinations": [{"thai": "ผัด", "glossZhHans": "炒"}],
                "minimal": [{"thai": "ผัด", "glossZhHans": "炒"}],
            },
        }]
        requests = menu_audio_requests(cards, segments_only=True)
        self.assertEqual(len(requests), 1)
        self.assertEqual(requests[0][1], "ผัด")
        self.assertTrue(requests[0][0].startswith("audio-segment-"))


if __name__ == "__main__":
    unittest.main()
