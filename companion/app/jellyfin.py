"""Asks Jellyfin to scan its libraries (`POST /Library/Refresh`)."""
from __future__ import annotations

from typing import Optional

import httpx

from .config import Settings


def rescan(settings: Settings) -> Optional[str]:
    """None on success, or a warning to show. Never raises."""
    if not (settings.jellyfin_url and settings.jellyfin_api_key):
        return "Jellyfin isn't configured here, so the library wasn't rescanned."
    try:
        r = httpx.post(settings.jellyfin_url + "/Library/Refresh",
                       headers={"X-Emby-Token": settings.jellyfin_api_key}, timeout=15)
        r.raise_for_status()
    except Exception as e:
        return "Saved, but the Jellyfin rescan failed (%s)." % type(e).__name__
    return None
