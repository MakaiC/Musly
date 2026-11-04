"""The companion service's HTTP API."""
from __future__ import annotations

import hmac
from typing import Optional

from fastapi import Depends, FastAPI, Header
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from . import __version__, media, ytdl
from .config import Settings, load_settings
from .jobs import JobManager
from .parser import parse_title
from .urls import InvalidLink, video_id_from_url


class UrlBody(BaseModel):
    url: str


class DownloadBody(BaseModel):
    url: str
    force: bool = False


def error(status: int, code: str, message: str, **extra) -> JSONResponse:
    body = {"error": message, "code": code}
    body.update(extra)
    return JSONResponse(status_code=status, content=body)


def create_app(settings: Optional[Settings] = None) -> FastAPI:
    settings = settings or load_settings()
    app = FastAPI(title="Navinix companion", version=__version__)
    jobs = JobManager(settings)
    app.state.jobs = jobs
    app.state.settings = settings

    def require_token(authorization: Optional[str] = Header(default=None)) -> Optional[JSONResponse]:
        scheme, _, supplied = (authorization or "").partition(" ")
        ok = scheme.lower() == "bearer" and hmac.compare_digest(
            supplied.strip().encode("utf-8"), settings.token.encode("utf-8"))
        if not ok:
            raise _Unauthorized()
        return None

    class _Unauthorized(Exception):
        pass

    @app.exception_handler(_Unauthorized)
    async def _unauthorized(_request, _exc):
        resp = error(401, "unauthorized", "Missing or wrong token.")
        resp.headers["WWW-Authenticate"] = "Bearer"
        return resp

    def inspect(url: str):
        """Validates a link; returns (video id, info, parsed, exists, target) or a JSONResponse."""
        try:
            video_id = video_id_from_url(url)
        except InvalidLink as e:
            return error(422, "invalid_link", str(e), valid=False)
        try:
            info = ytdl.extract_info(url, settings)
        except ytdl.YtDlpError as e:
            return error(422, "invalid_link", str(e), valid=False)
        parsed = parse_title(info.title, info.channel)
        try:
            target = media.target_path(settings.music_dir, parsed.artist, parsed.title)
        except media.MediaError as e:
            return error(500, "server", str(e))
        return video_id, info, parsed, target.exists(), target

    @app.get("/health")
    def health():
        return {"version": __version__, "ytDlpVersion": ytdl.version(settings)}

    @app.post("/validate", dependencies=[Depends(require_token)])
    def validate(body: UrlBody):
        result = inspect(body.url)
        if isinstance(result, JSONResponse):
            return result
        video_id, info, parsed, exists, _ = result
        return {
            "valid": True,
            "videoId": info.video_id or video_id,
            "title": info.title,
            "channel": info.channel,
            "durationSeconds": info.duration,
            "thumbnailUrl": info.thumbnail_url,
            "parsed": {"artist": parsed.artist, "albumArtist": parsed.album_artist, "title": parsed.title},
            "alreadyExists": exists,
        }

    @app.post("/download", dependencies=[Depends(require_token)])
    def download(body: DownloadBody):
        result = inspect(body.url)
        if isinstance(result, JSONResponse):
            return result
        _, info, parsed, exists, target = result
        if exists and not body.force:
            return error(409, "already_exists", "%s is already in the library." % target.name)
        job = jobs.submit(body.url, info, parsed)
        return {"jobId": job.id}

    @app.get("/jobs/{job_id}", dependencies=[Depends(require_token)])
    def job_status(job_id: str):
        job = jobs.get(job_id)
        if job is None:
            return error(404, "not_found", "Unknown job.")
        return job.public()

    return app
