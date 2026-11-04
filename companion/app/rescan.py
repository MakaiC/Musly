"""Tells whichever media server is configured to pick up the new file."""
from __future__ import annotations

from typing import Optional

from . import jellyfin, navidrome
from .config import Settings


def rescan_library(settings: Settings) -> Optional[str]:
    """None on success, or a warning. Never raises: the file is already saved."""
    backend = settings.library_backend
    if backend == "navidrome":
        return navidrome.rescan(settings)
    if backend == "jellyfin":
        return jellyfin.rescan(settings)
    return "No media server is configured, so the library wasn't rescanned."
