"""Download jobs: one worker thread, so they run one at a time."""
from __future__ import annotations

import shutil
import tempfile
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional

from . import media, navidrome, ytdl
from .config import Settings
from .parser import ParsedTitle


@dataclass
class Job:
    id: str
    status: str = "queued"  # queued|downloading|converting|tagging|done|failed
    progress: float = 0.0
    error: Optional[str] = None
    file: Optional[str] = None
    warning: Optional[str] = None

    def public(self) -> dict:
        return {"status": self.status, "progress": round(self.progress, 3), "error": self.error,
                "file": self.file, "warning": self.warning}


class JobManager:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._jobs: Dict[str, Job] = {}
        self._lock = threading.Lock()
        self._pool = ThreadPoolExecutor(max_workers=1, thread_name_prefix="job")

    def get(self, job_id: str) -> Optional[Job]:
        with self._lock:
            return self._jobs.get(job_id)

    def submit(self, url: str, info: ytdl.VideoInfo, parsed: ParsedTitle) -> Job:
        job = Job(id=uuid.uuid4().hex)
        with self._lock:
            self._jobs[job.id] = job
            while len(self._jobs) > 200:  # forget the oldest
                self._jobs.pop(next(iter(self._jobs)))
        self._pool.submit(self._run, job, url, info, parsed)
        return job

    def _set(self, job: Job, **fields) -> None:
        with self._lock:
            for k, v in fields.items():
                setattr(job, k, v)

    def _run(self, job: Job, url: str, info: ytdl.VideoInfo, parsed: ParsedTitle) -> None:
        work = Path(tempfile.mkdtemp(prefix="companion-", dir=self.settings.work_dir))
        try:
            target = media.target_path(self.settings.music_dir, parsed.artist, parsed.title)
            self._set(job, status="downloading", progress=0.02)
            src = ytdl.download_audio(url, work, self.settings,
                                      lambda f: self._set(job, progress=0.02 + 0.78 * f))
            self._set(job, status="converting", progress=0.82)
            tmp_mp3 = work / "out.mp3"
            media.convert_to_mp3(src, tmp_mp3, self.settings)

            self._set(job, status="tagging", progress=0.93)
            cover = media.fetch_cover(info.thumbnail_url)
            media.write_tags(tmp_mp3, parsed.artist, parsed.album_artist, parsed.title, cover)

            # Only now does anything appear in the library, and atomically.
            shutil.move(str(tmp_mp3), str(target))
            warning = navidrome.rescan(self.settings)
            self._set(job, status="done", progress=1.0, file=target.name, warning=warning)
        except (ytdl.YtDlpError, media.MediaError) as e:
            self._set(job, status="failed", error=str(e))
        except Exception as e:  # never leave a job stuck
            self._set(job, status="failed", error="Unexpected error: %s" % type(e).__name__)
        finally:
            shutil.rmtree(work, ignore_errors=True)
