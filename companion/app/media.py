"""Converting, tagging, cover art and file naming."""
from __future__ import annotations

import io
import re
import subprocess
from pathlib import Path
from typing import Optional

import httpx
from mutagen.id3 import APIC, ID3, TALB, TIT2, TPE1, TPE2
from PIL import Image

from .config import Settings

# MP3 at 320 kbit/s constant bitrate: the highest the format allows, and the
# size is predictable. (V0 would be smaller at near-identical quality; change
# MP3_ARGS to ["-q:a", "0"] for that.)
MP3_ARGS = ["-codec:a", "libmp3lame", "-b:a", "320k"]

COVER_SIZE = 1000  # px, longest side after the square crop


class MediaError(Exception):
    """A message that is safe to show to the user."""


def sanitize(name: str, max_bytes: int = 180) -> str:
    """A string safe to use as a file name on any filesystem."""
    name = re.sub(r'[\x00-\x1f/\\:*?"<>|]', "", name)
    name = " ".join(name.split()).strip(" .")
    while len(name.encode("utf-8")) > max_bytes:
        name = name[:-1]
    return name.strip(" .") or "Unknown"


def target_path(music_dir: Path, artist: str, title: str) -> Path:
    path = music_dir / ("%s - %s.mp3" % (sanitize(artist), sanitize(title)))
    if path.resolve().parent != music_dir.resolve():
        raise MediaError("Refusing to write outside the music folder.")
    return path


def convert_to_mp3(src: Path, dest: Path, settings: Settings) -> None:
    cmd = [settings.ffmpeg_path, "-y", "-loglevel", "error", "-i", str(src), "-vn",
           "-map_metadata", "-1"] + MP3_ARGS + [str(dest)]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    except FileNotFoundError:
        raise MediaError("ffmpeg isn't installed on the server.")
    except subprocess.TimeoutExpired:
        raise MediaError("Converting took too long.")
    if r.returncode != 0:
        raise MediaError("ffmpeg failed: " + ((r.stderr or "").strip().splitlines() or ["no details"])[-1][:200])


def square_cover(data: bytes) -> bytes:
    """Centre-crops an image to a square and returns it as JPEG bytes."""
    img = Image.open(io.BytesIO(data))
    img = img.convert("RGB")
    side = min(img.size)
    left, top = (img.width - side) // 2, (img.height - side) // 2
    img = img.crop((left, top, left + side, top + side))
    if side > COVER_SIZE:
        img = img.resize((COVER_SIZE, COVER_SIZE), Image.LANCZOS)
    out = io.BytesIO()
    img.save(out, "JPEG", quality=92)
    return out.getvalue()


def fetch_cover(url: Optional[str]) -> Optional[bytes]:
    """The square JPEG cover, or None when there's no usable thumbnail
    (a missing cover shouldn't fail the whole job)."""
    if not url:
        return None
    try:
        r = httpx.get(url, timeout=20, follow_redirects=True)
        r.raise_for_status()
        return square_cover(r.content)
    except Exception:
        return None


def write_tags(path: Path, artist: str, album_artist: str, title: str,
               cover: Optional[bytes]) -> None:
    """ID3 tags: title, artist, albumartist, album (= title) and the cover."""
    try:
        tags = ID3()
    except Exception:
        tags = ID3()
    tags.add(TIT2(encoding=3, text=title))
    tags.add(TPE1(encoding=3, text=artist))
    tags.add(TPE2(encoding=3, text=album_artist))
    tags.add(TALB(encoding=3, text=title))
    if cover:
        tags.add(APIC(encoding=3, mime="image/jpeg", type=3, desc="Cover", data=cover))
    tags.save(str(path), v2_version=3)
