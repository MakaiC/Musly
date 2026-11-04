"""Asks Navidrome to rescan its library (Subsonic `startScan`)."""
from __future__ import annotations

import hashlib
import secrets
from typing import Optional

import httpx

from .config import Settings


def rescan(settings: Settings) -> Optional[str]:
    """Returns None on success, or a warning to show the user. Never raises:
    the file is already saved, so a failed rescan isn't a failed job."""
    if not settings.can_rescan:
        return "Navidrome isn't configured here, so the library wasn't rescanned."
    salt = secrets.token_hex(8)
    token = hashlib.md5((settings.navidrome_password + salt).encode("utf-8")).hexdigest()
    params = {"u": settings.navidrome_user, "t": token, "s": salt,
              "v": "1.16.1", "c": "navinix-companion", "f": "json"}
    try:
        r = httpx.get(settings.navidrome_url + "/rest/startScan.view", params=params, timeout=15)
        r.raise_for_status()
        body = r.json().get("subsonic-response", {})
        if body.get("status") != "ok":
            return "Saved, but Navidrome refused the rescan: %s" % (body.get("error", {}).get("message", "unknown error"))
    except Exception as e:  # network, bad JSON, HTTP error
        return "Saved, but the Navidrome rescan failed (%s)." % type(e).__name__
    return None
