#!/usr/bin/env python3
"""Generate and validate the audio manifest.

Reads all MP3 files in Resources/Audio/, verifies them against items.json,
and writes audio-manifest.json with SHA-256, byte count, and duration.

Usage: python3 tools/generate_audio_manifest.py
"""

import json
import os
import sys

from segment_audio import menu_segment_audio_requests, segment_audio_requests
import hashlib
import struct
import subprocess


ITEMS_PATH = "ThaiLife/Resources/Content/items.json"
WORD_FAMILIES_PATH = "ThaiLife/Resources/Content/word_families.json"
THAI_MENU_PATH = "ThaiLife/Resources/Content/thai_menu_reference.json"
AUDIO_DIR = "ThaiLife/Resources/Audio"
MANIFEST_PATH = "ThaiLife/Resources/Audio/audio-manifest.json"


def get_mp3_duration(filepath):
    """Return (duration, is_mp3); reject mislabeled Ogg/Opus files."""
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration,format_name",
             "-of", "json", filepath],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            fmt = data.get("format", {})
            duration = float(fmt.get("duration", 0))
            format_names = set((fmt.get("format_name") or "").split(","))
            return (duration if duration > 0 else None, "mp3" in format_names)
    except Exception:
        pass
    return (None, False)


def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    with open(ITEMS_PATH, "r", encoding="utf-8") as f:
        items = json.load(f)

    expected_ids = set()
    audio_thai = {}
    for item in items:
        audio_id = item["audioID"]
        expected_ids.add(audio_id)
        audio_thai[audio_id] = item["thai"]
        if item.get("example"):
            example_id = f"{audio_id}-example"
            expected_ids.add(example_id)
            audio_thai[example_id] = item["example"]

    for segment_audio_id, segment_thai in segment_audio_requests(items):
        expected_ids.add(segment_audio_id)
        audio_thai[segment_audio_id] = segment_thai

    # Word-family cards are supplemental content and use the same Audio bundle.
    # Include their explicit audio IDs so generated family assets are audited
    # instead of being reported as orphan files.
    family_audio_count = 0
    if os.path.exists(WORD_FAMILIES_PATH):
        with open(WORD_FAMILIES_PATH, "r", encoding="utf-8") as f:
            families = json.load(f)
        for family in families:
            root_audio_id = (family.get("rootAudioID") or "").strip()
            if root_audio_id:
                expected_ids.add(root_audio_id)
                audio_thai[root_audio_id] = family["rootThai"]
                family_audio_count += 1
            for member in family.get("items", []):
                audio_id = (member.get("audioID") or "").strip()
                if not audio_id:
                    continue
                expected_ids.add(audio_id)
                audio_thai[audio_id] = member["thai"]
                family_audio_count += 1

    # Standalone menu cards use complete dish-name audio and are not ContentItems.
    menu_audio_count = 0
    if os.path.exists(THAI_MENU_PATH):
        with open(THAI_MENU_PATH, "r", encoding="utf-8") as f:
            menu_reference = json.load(f)
        menu_cards = menu_reference.get("cards", [])
        for card in menu_cards:
            audio_id = (card.get("audioID") or "").strip()
            if not audio_id:
                continue
            expected_ids.add(audio_id)
            audio_thai[audio_id] = card["thai"]
            menu_audio_count += 1
        for segment_audio_id, segment_thai in menu_segment_audio_requests(menu_cards):
            expected_ids.add(segment_audio_id)
            audio_thai[segment_audio_id] = segment_thai

    print(
        f"Expected {len(expected_ids)} audio files "
        f"(including complete example sentences, independently playable segments, and {family_audio_count} word-family references and {menu_audio_count} menu cards)"
    )

    # Find all MP3 files
    audio_files = {}
    if os.path.isdir(AUDIO_DIR):
        for fname in os.listdir(AUDIO_DIR):
            if fname.endswith(".mp3"):
                aid = fname[:-4]  # strip .mp3
                audio_files[aid] = os.path.join(AUDIO_DIR, fname)

    print(f"Found {len(audio_files)} MP3 files on disk")

    # Check for missing
    missing = expected_ids - set(audio_files.keys())
    if missing:
        print(f"WARNING: {len(missing)} missing audio files")
        for m in sorted(missing)[:10]:
            print(f"  - {m}")
        if len(missing) > 10:
            print(f"  ... and {len(missing) - 10} more")

    # Check for orphans
    orphans = set(audio_files.keys()) - expected_ids
    if orphans:
        print(f"WARNING: {len(orphans)} orphan audio files (no matching content)")
        for o in sorted(orphans)[:10]:
            print(f"  - {o}")

    # Build manifest for existing files
    import concurrent.futures

    def process_file(item):
        aid, filepath = item
        byte_count = os.path.getsize(filepath)
        checksum = sha256_file(filepath)
        duration, is_mp3 = get_mp3_duration(filepath)
        return aid, byte_count, checksum, duration, is_mp3

    manifest = []
    undecodable = []
    invalid_format = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as executor:
        results = list(executor.map(process_file, sorted(audio_files.items())))

    for aid, byte_count, checksum, duration, is_mp3 in results:
        if not is_mp3:
            invalid_format.append(aid)
        if duration is None:
            undecodable.append(aid)
            duration = 0.0
        manifest.append({
            "audioID": aid,
            "relativePath": f"Audio/{aid}.mp3",
            "sha256": checksum,
            "byteCount": byte_count,
            "durationSeconds": round(duration, 3),
        })

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump({
            "version": 1,
            "audioCount": len(manifest),
            "generatedAt": "",
            "entries": manifest,
        }, f, ensure_ascii=False, indent=2)

    print(f"Wrote {MANIFEST_PATH} with {len(manifest)} entries")

    # Fail on wrong container/codec or undecodable files
    if invalid_format:
        print(f"\nERROR: {len(invalid_format)} files are not MP3 containers", file=sys.stderr)
        for item in invalid_format[:10]:
            print(f"  - {item}", file=sys.stderr)
        sys.exit(1)
    if undecodable:
        print(f"\nERROR: {len(undecodable)} undecodable/zero-duration audio files", file=sys.stderr)
        for u in undecodable[:10]:
            print(f"  - {u}", file=sys.stderr)
        sys.exit(1)

    # Audit summary
    if missing:
        print(f"\nERROR: {len(missing)} missing audio files", file=sys.stderr)
        sys.exit(1)
    if orphans:
        print(f"\nERROR: {len(orphans)} orphan audio files", file=sys.stderr)
        sys.exit(1)

    print(f"audited {len(manifest)} audio assets")

    # Cross-text hash check: same audio file must not serve different Thai text
    from collections import defaultdict
    hash_texts = defaultdict(set)
    for e in manifest:
        hash_texts[e["sha256"]].add(audio_thai.get(e["audioID"], ""))
    cross = [(h, list(t)) for h, t in hash_texts.items() if len(t) > 1]
    if cross:
        print(f"\nERROR: {len(cross)} cross-text hash collisions (same audio for different text)", file=sys.stderr)
        for h, texts in cross[:3]:
            print(f"  hash={h[:16]}... texts={texts[:3]}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
