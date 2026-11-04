"""Accepts single-video YouTube links only."""
from __future__ import annotations

import re
from typing import Optional
from urllib.parse import parse_qs, urlparse

ALLOWED_HOSTS = {
    "youtube.com",
    "www.youtube.com",
    "m.youtube.com",
    "music.youtube.com",
    "youtu.be",
}

_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")


class InvalidLink(ValueError):
    """The message is shown to the user as is."""


def video_id_from_url(raw: str) -> str:
    """Returns the video id, or raises InvalidLink with a clear reason."""
    raw = (raw or "").strip()
    if not raw:
        raise InvalidLink("Paste a YouTube link.")
    if "://" not in raw:
        raw = "https://" + raw
    try:
        u = urlparse(raw)
    except ValueError:
        raise InvalidLink("That isn't a valid link.")
    if u.scheme not in ("http", "https") or not u.hostname:
        raise InvalidLink("That isn't a valid link.")
    host = u.hostname.lower()
    if host not in ALLOWED_HOSTS:
        raise InvalidLink("That isn't a YouTube link.")

    query = parse_qs(u.query)
    path = u.path.rstrip("/")
    video: Optional[str] = None
    if host == "youtu.be":
        video = path.lstrip("/").split("/")[0] if path else None
    elif path == "/watch":
        video = (query.get("v") or [None])[0]
    elif path.startswith(("/shorts/", "/live/", "/embed/")):
        video = path.split("/")[2] if path.count("/") >= 2 else None
    elif path == "/playlist" or ("list" in query and not path.startswith("/watch")):
        raise InvalidLink("That's a playlist. Paste a link to a single video.")
    elif path.startswith(("/channel/", "/@", "/c/", "/user/")):
        raise InvalidLink("That's a channel. Paste a link to a single video.")

    if not video or not _ID.match(video):
        raise InvalidLink("That link doesn't point at a single YouTube video.")
    return video
