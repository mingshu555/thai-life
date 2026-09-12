#!/usr/bin/env python3
"""Generate Thai TTS assets using Google Cloud Text-to-Speech.

The derived ``<audioID>-example`` assets are synthesized from the complete
``example`` sentence. Segment glosses are never sent to TTS.

Prerequisites:
  1. Set GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON key.
  2. Install: pip install -r tools/requirements.txt

Usage:
  python3 tools/generate_audio.py --dry-run --examples-only
  python3 tools/generate_audio.py --examples-only --force

Credentials are NEVER bundled, committed, logged, or entered in the iPhone app.
"""

import argparse
import json
import os
import sys

from segment_audio import menu_segment_audio_requests, segment_audio_requests

try:
    from google.cloud import texttospeech
    HAS_TTS = True
except ImportError:
    HAS_TTS = False
    print("Warning: google-cloud-texttospeech not installed. Run: pip install -r tools/requirements.txt")


ITEMS_PATH = "ThaiLife/Resources/Content/items.json"
AUDIO_DIR = "ThaiLife/Resources/Audio"
THAI_MENU_PATH = "ThaiLife/Resources/Content/thai_menu_reference.json"
VOICE_NAME = "th-TH-Standard-A"
# Google Translate-like naturalness is better for these isolated short number
# words with the higher-definition Thai voice. Keep this override narrow so the
# existing content pack voice remains stable.
VOICE_OVERRIDES = {
    "audio-numbers-word-011": "th-TH-Chirp3-HD-Kore",  # สิบ
    "audio-numbers-chunk-001": "th-TH-Chirp3-HD-Kore",  # สิบเอ็ด
}
SPEAKING_RATE_OVERRIDES = {
    "audio-numbers-word-011": 0.8,
    "audio-numbers-chunk-001": 0.8,
}


def load_items():
    with open(ITEMS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def load_menu_cards():
    with open(THAI_MENU_PATH, "r", encoding="utf-8") as f:
        return json.load(f).get("cards", [])


def menu_audio_requests(cards, segments_only=False):
    if segments_only:
        return menu_segment_audio_requests(cards)
    return [(card["audioID"], card["thai"]) for card in cards]


def audio_requests(items, examples_only=False, segments_only=False, audio_ids=None):
    """Yield selected primary/example requests or deduplicated visual segments.

    ``audio_ids`` deliberately selects only top-level content-item audio IDs.
    It is used for bounded re-generation of a known set of main-word assets;
    example and segment modes use different ID schemes and cannot be mixed.
    """
    requested_ids = set(audio_ids or [])
    if requested_ids and (examples_only or segments_only):
        raise ValueError("--audio-id cannot be combined with --examples-only or --segments-only")

    if requested_ids:
        known_ids = {item["audioID"] for item in items}
        unknown_ids = requested_ids - known_ids
        if unknown_ids:
            unknown_list = ", ".join(sorted(unknown_ids))
            raise ValueError(f"unknown primary audio ID(s): {unknown_list}")

    if segments_only:
        yield from segment_audio_requests(items)
        return

    for item in items:
        audio_id = item["audioID"]
        if requested_ids and audio_id not in requested_ids:
            continue
        if requested_ids:
            yield audio_id, item["thai"]
            continue
        if not examples_only:
            yield audio_id, item["thai"]
        example = item.get("example")
        if example:
            yield f"{audio_id}-example", example


def generate_audio(items, dry_run=False, examples_only=False, segments_only=False, force=False, audio_ids=None, menu_cards=None, menu_only=False, menu_segments_only=False):
    if examples_only and segments_only:
        raise ValueError("--examples-only and --segments-only cannot be combined")
    if menu_only and menu_segments_only:
        raise ValueError("--menu-only and --menu-segments-only cannot be combined")
    if menu_only or menu_segments_only:
        if examples_only or segments_only or audio_ids:
            raise ValueError("menu modes cannot be combined with item modes")
        requests = list(menu_audio_requests(menu_cards or [], segments_only=menu_segments_only))
    else:
        requests = list(
            audio_requests(
                items,
                examples_only=examples_only,
                segments_only=segments_only,
                audio_ids=audio_ids,
            )
        )
    print(f"Prepared {len(requests)} audio requests")

    if dry_run:
        for audio_id, thai_text in requests:
            output_path = os.path.join(AUDIO_DIR, f"{audio_id}.mp3")
            if force or not os.path.exists(output_path):
                print(f"  [DRY RUN] Would generate: {audio_id}")
        return 0

    if not HAS_TTS:
        print("ERROR: google-cloud-texttospeech not installed.")
        print("Install with: pip install -r tools/requirements.txt")
        sys.exit(1)

    if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        print("ERROR: GOOGLE_APPLICATION_CREDENTIALS not set.")
        print("Set it to a Google Cloud service-account JSON key path and try again.")
        sys.exit(1)

    os.makedirs(AUDIO_DIR, exist_ok=True)
    client = texttospeech.TextToSpeechClient()

    generated = 0
    skipped = 0
    failed = 0
    for index, (audio_id, thai_text) in enumerate(requests, start=1):
        output_path = os.path.join(AUDIO_DIR, f"{audio_id}.mp3")
        if os.path.exists(output_path) and not force:
            skipped += 1
            continue

        try:
            voice = texttospeech.VoiceSelectionParams(
                language_code="th-TH",
                name=VOICE_OVERRIDES.get(audio_id, VOICE_NAME),
            )
            audio_config = texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.MP3,
                speaking_rate=SPEAKING_RATE_OVERRIDES.get(audio_id, 1.0),
            )
            response = client.synthesize_speech(
                input=texttospeech.SynthesisInput(text=thai_text),
                voice=voice,
                audio_config=audio_config,
            )
            tmp_path = output_path + ".tmp"
            with open(tmp_path, "wb") as out:
                out.write(response.audio_content)
            os.replace(tmp_path, output_path)
            generated += 1
            if index % 50 == 0:
                print(f"  Generated {index}/{len(requests)}...")
        except Exception as error:
            print(f"  FAILED {audio_id}: {error}")
            failed += 1

    print(f"\nGenerated {generated} audio files, skipped {skipped}, {failed} failed")
    return generated


def main():
    parser = argparse.ArgumentParser(description="Generate Thai TTS audio assets")
    parser.add_argument("--dry-run", action="store_true", help="Print requests without credentials or API calls")
    parser.add_argument("--examples-only", action="store_true", help="Generate only complete example sentences")
    parser.add_argument("--segments-only", action="store_true", help="Generate only deduplicated visual segment MP3s")
    parser.add_argument("--menu-only", action="store_true", help="Generate complete audio for every standalone Thai menu card")
    parser.add_argument("--menu-segments-only", action="store_true", help="Generate audio for every tappable Thai menu breakdown part")
    parser.add_argument(
        "--audio-id",
        action="append",
        dest="audio_ids",
        metavar="AUDIO_ID",
        help="Generate only this primary content audio ID; repeat for multiple IDs",
    )
    parser.add_argument("--force", action="store_true", help="Replace existing MP3 files atomically")
    args = parser.parse_args()

    items = load_items()
    menu_cards = load_menu_cards() if (args.menu_only or args.menu_segments_only) else None
    print(f"Loaded {len(items)} items from {ITEMS_PATH}")
    if menu_cards is not None:
        print(f"Loaded {len(menu_cards)} standalone menu cards from {THAI_MENU_PATH}")
    generate_audio(
        items,
        dry_run=args.dry_run,
        examples_only=args.examples_only,
        segments_only=args.segments_only,
        force=args.force,
        audio_ids=args.audio_ids,
        menu_cards=menu_cards,
        menu_only=args.menu_only,
        menu_segments_only=args.menu_segments_only,
    )


if __name__ == "__main__":
    main()
