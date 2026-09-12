"""Shared deterministic IDs and request discovery for independently playable Thai segments."""

from __future__ import annotations

import hashlib
import re
import unicodedata
from collections.abc import Iterable


def normalized_thai(text: str) -> str:
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", text)).strip()


def audio_id_for(text: str) -> str:
    return "audio-segment-" + hashlib.sha256(normalized_thai(text).encode("utf-8")).hexdigest()


def segment_audio_requests(items: Iterable[dict]) -> list[tuple[str, str]]:
    by_id: dict[str, str] = {}

    def add(segment: dict) -> None:
        thai = segment.get("thai") if isinstance(segment, dict) else None
        if not isinstance(thai, str) or not normalized_thai(thai):
            return
        audio_id = audio_id_for(thai)
        existing = by_id.get(audio_id)
        if existing is not None and normalized_thai(existing) != normalized_thai(thai):
            raise ValueError(f"segment audio ID collision: {audio_id}")
        by_id[audio_id] = thai

    for item in items:
        for segment in item.get("segments", []):
            add(segment)
        breakdown = item.get("chunkBreakdown") or {}
        for layer in ("combinations", "minimal"):
            for segment in breakdown.get(layer, []):
                add(segment)
        for turn in item.get("dialogueBreakdown") or []:
            for segment in turn.get("segments", []):
                add(segment)
    return sorted(by_id.items())


def menu_segment_audio_requests(cards: Iterable[dict]) -> list[tuple[str, str]]:
    """Return deduplicated audio requests for independently tappable menu breakdown parts."""
    by_id: dict[str, str] = {}

    def add(part: dict) -> None:
        thai = part.get("thai") if isinstance(part, dict) else None
        if not isinstance(thai, str) or not normalized_thai(thai):
            return
        audio_id = audio_id_for(thai)
        existing = by_id.get(audio_id)
        if existing is not None and normalized_thai(existing) != normalized_thai(thai):
            raise ValueError(f"menu segment audio ID collision: {audio_id}")
        by_id[audio_id] = thai

    for card in cards:
        breakdown = card.get("breakdown") or {}
        for layer in ("combinations", "minimal"):
            for part in breakdown.get(layer, []):
                add(part)
    return sorted(by_id.items())
