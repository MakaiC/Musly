"""yt-dlp, run as a subprocess by absolute path (or `python -m yt_dlp`).

A subprocess rather than the Python API so the service can use the pipx
install of yt-dlp that the server keeps up to date, without importing it into
this virtualenv."""
from __future__ import annotations

import json
import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List, Optional

from .config import Settings


class YtDlpError(Exception):
    """Carries a message that is safe to show to the user."""


@dataclass
class VideoInfo:
    video_id: str
    title: str
    channel: str
    duration: int
    thumbnail_url: Optional[str]


def _env(settings: Settings) -> Dict[str, str]:
    env = dict(os.environ)
    if settings.deno_path:
        env["PATH"] = str(Path(settings.deno_path).parent) + os.pathsep + env.get("PATH", "")
    return env


def _base(settings: Settings) -> List[str]:
    cmd = settings.yt_dlp_command() + ["--no-playlist", "--no-warnings", "--no-colors"]
    if settings.deno_path:
        cmd += ["--js-runtimes", "deno:" + settings.deno_path]
    return cmd


_REASONS = [
    (r"private video", "That video is private."),
    (r"sign in to confirm your age|age-restricted|confirm your age", "That video is age-restricted and can't be downloaded."),
    (r"available in your (country|region)|blocked it in your (country|region)|geo.?restrict", "That video is blocked in the server's region."),
    (r"members-only|join this channel", "That video is for channel members only."),
    (r"video unavailable|this video is not available|has been removed|no longer available|does not exist|account associated.*terminated", "That video is unavailable."),
    (r"live event|is live|premieres in", "Live streams and premieres can't be downloaded."),
    (r"sign in to confirm you.re not a bot", "YouTube asked the server to prove it's not a bot. Update yt-dlp and check Deno is installed."),
    (r"unsupported url", "That isn't a video link YouTube can serve."),
]


def explain_failure(stderr: str) -> str:
    low = (stderr or "").lower()
    for pattern, message in _REASONS:
        if re.search(pattern, low):
            return message
    lines = [l for l in (stderr or "").strip().splitlines() if l.strip()]
    return "yt-dlp failed: " + (lines[-1][:200] if lines else "no details")


def _run(cmd: List[str], settings: Settings, timeout: int) -> "subprocess.CompletedProcess[str]":
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=_env(settings))
    except FileNotFoundError:
        raise YtDlpError("yt-dlp isn't installed where the service looks for it (YT_DLP_PATH).")
    except subprocess.TimeoutExpired:
        raise YtDlpError("YouTube took too long to answer.")


def version(settings: Settings) -> str:
    try:
        r = _run(settings.yt_dlp_command() + ["--version"], settings, 20)
    except YtDlpError:
        return "unavailable"
    return r.stdout.strip() or "unavailable"


def best_thumbnail(thumbs: List[dict]) -> Optional[str]:
    """The largest thumbnail; ties go to yt-dlp's own preference."""
    usable = [t for t in thumbs or [] if t.get("url")]
    if not usable:
        return None
    usable.sort(key=lambda t: ((t.get("width") or 0) * (t.get("height") or 0), t.get("preference") or 0))
    return usable[-1]["url"]


def extract_info(url: str, settings: Settings) -> VideoInfo:
    """`extract_info(download=False)`: what the link is, without downloading."""
    r = _run(_base(settings) + ["--dump-single-json", "--skip-download", url], settings, 60)
    if r.returncode != 0:
        raise YtDlpError(explain_failure(r.stderr))
    try:
        data = json.loads(r.stdout)
    except ValueError:
        raise YtDlpError("yt-dlp returned something unreadable.")
    if data.get("_type") == "playlist" or data.get("entries"):
        raise YtDlpError("That's a playlist. Paste a link to a single video.")
    if data.get("is_live") or data.get("live_status") in ("is_live", "is_upcoming"):
        raise YtDlpError("Live streams and premieres can't be downloaded.")
    return VideoInfo(
        video_id=data.get("id") or "",
        title=data.get("title") or "",
        channel=data.get("channel") or data.get("uploader") or "",
        duration=int(data.get("duration") or 0),
        thumbnail_url=best_thumbnail(data.get("thumbnails") or []) or data.get("thumbnail"),
    )


_PROGRESS = re.compile(r"^PROGRESS (\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?|NA)\s+(\d+(?:\.\d+)?|NA)")


def download_audio(url: str, dest_dir: Path, settings: Settings,
                   on_progress: Callable[[float], None]) -> Path:
    """Downloads the best audio stream into [dest_dir]; returns the file."""
    template = "PROGRESS %(progress.downloaded_bytes)s %(progress.total_bytes)s %(progress.total_bytes_estimate)s"
    cmd = _base(settings) + [
        "-f", "bestaudio", "--newline", "--progress", "--progress-template", "download:" + template,
        "-o", str(dest_dir / "%(id)s.%(ext)s"), "--print", "after_move:filepath", url,
    ]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=_env(settings))
    except FileNotFoundError:
        raise YtDlpError("yt-dlp isn't installed where the service looks for it (YT_DLP_PATH).")
    final = None
    assert proc.stdout is not None
    for line in proc.stdout:
        line = line.strip()
        m = _PROGRESS.match(line)
        if m:
            done = float(m.group(1))
            total = next((float(g) for g in m.groups()[1:] if g != "NA"), 0.0)
            if total > 0:
                on_progress(min(1.0, done / total))
        elif line and os.path.sep in line:
            final = line
    stderr = proc.stderr.read() if proc.stderr else ""
    if proc.wait() != 0 or not final or not Path(final).exists():
        raise YtDlpError(explain_failure(stderr))
    return Path(final)
