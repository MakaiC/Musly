"""Turns a video title and channel into tags. Pure functions, unit-tested."""
from __future__ import annotations

import re
from dataclasses import dataclass

# Everything from the first of these onward is dropped from the song part.
_CUT_CHARS = "([*＊|–—"  # ( [ * full-width * | en dash em dash

# A trailing "(pt. 2)" / "(part 2)" belongs to the song name and is kept.
_PART = re.compile(r"\((?:pt\.?|part)\s*\d+\)", re.IGNORECASE)

_ARTIST_SPLIT = re.compile(r"\s+x\s+|\s*&\s*|,\s*|\s+feat\.?\s+|\s+ft\.?\s+", re.IGNORECASE)


@dataclass(frozen=True)
class ParsedTitle:
    artist: str
    album_artist: str
    title: str


def clean_song(text: str) -> str:
    """Cuts the decoration off a song title, keeping a "(pt. N)" suffix."""
    out = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "(":
            m = _PART.match(text, i)
            if m:
                out.append(m.group(0))
                i = m.end()
                continue
        if ch in _CUT_CHARS:
            break
        out.append(ch)
        i += 1
    return " ".join("".join(out).split())


def first_artist(artist: str) -> str:
    """The album artist: the first name of a collab."""
    for part in _ARTIST_SPLIT.split(artist):
        part = part.strip()
        if part:
            return part
    return artist.strip()


def parse_title(title: str, channel: str = "") -> ParsedTitle:
    raw = " ".join((title or "").split())
    channel = (channel or "").strip()
    if channel.endswith(" - Topic"):
        channel = channel[: -len(" - Topic")].strip()

    if " - " in raw:
        left, right = raw.split(" - ", 1)
        artist = left.strip() or channel
        song = clean_song(right)
    else:
        artist = channel
        song = clean_song(raw)

    if not song:
        song = raw  # nothing survived the cleaning: use the title as it is
    if not artist:
        artist = "Unknown Artist"
    return ParsedTitle(artist=artist, album_artist=first_artist(artist) or artist, title=song)
