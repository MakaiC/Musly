"""Settings, read from environment variables (systemd's EnvironmentFile sets
them in production; see companion.env.example)."""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Mapping, Optional


class ConfigError(RuntimeError):
    pass


@dataclass(frozen=True)
class Settings:
    token: str
    music_dir: Path
    navidrome_url: str = ""
    navidrome_user: str = ""
    navidrome_password: str = ""
    # Absolute path to yt-dlp. Empty: run it as `python -m yt_dlp`.
    yt_dlp_path: str = ""
    # Absolute path to deno (yt-dlp's JS runtime for YouTube). Empty: rely on PATH.
    deno_path: str = ""
    ffmpeg_path: str = "ffmpeg"
    work_dir: Optional[Path] = None

    def yt_dlp_command(self) -> List[str]:
        return [self.yt_dlp_path] if self.yt_dlp_path else [sys.executable, "-m", "yt_dlp"]

    @property
    def can_rescan(self) -> bool:
        return bool(self.navidrome_url and self.navidrome_user and self.navidrome_password)


def load_settings(env: Optional[Mapping[str, str]] = None) -> Settings:
    env = os.environ if env is None else env
    token = env.get("COMPANION_TOKEN", "").strip()
    if len(token) < 16:
        raise ConfigError("COMPANION_TOKEN must be set to a secret of at least 16 characters")
    music = env.get("MUSIC_DIR", "").strip()
    if not music:
        raise ConfigError("MUSIC_DIR must be set (for example /opt/navidrome/music)")
    music_dir = Path(music)
    if not music_dir.is_dir():
        raise ConfigError("MUSIC_DIR %s is not a directory" % music_dir)
    if not os.access(music_dir, os.W_OK):
        raise ConfigError("MUSIC_DIR %s is not writable by this user" % music_dir)
    work = env.get("WORK_DIR", "").strip()
    return Settings(
        token=token,
        music_dir=music_dir,
        navidrome_url=env.get("NAVIDROME_URL", "").strip().rstrip("/"),
        navidrome_user=env.get("NAVIDROME_USER", "").strip(),
        navidrome_password=env.get("NAVIDROME_PASSWORD", ""),
        yt_dlp_path=env.get("YT_DLP_PATH", "").strip(),
        deno_path=env.get("DENO_PATH", "").strip(),
        ffmpeg_path=env.get("FFMPEG_PATH", "").strip() or "ffmpeg",
        work_dir=Path(work) if work else None,
    )
