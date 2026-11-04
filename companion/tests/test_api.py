import io
import time
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from mutagen.id3 import ID3
from PIL import Image

from app import jobs as jobs_mod
from app import jellyfin, main, media, navidrome, rescan, ytdl
from app.config import ConfigError, Settings, load_settings

TOKEN = "x" * 20
AUTH = {"Authorization": "Bearer " + TOKEN}
VID = "dQw4w9WgXcQ"
URL = "https://www.youtube.com/watch?v=" + VID
TITLE = "Cochise & Pradabagshawty - IMGEEKED, IM HIGH, IM FCKED UP ＊snippet＊ (EXTENDED EDIT) (HQ)"


def fake_info(url, settings):
    return ytdl.VideoInfo(VID, TITLE, "Cochise", 187, "https://img/x.jpg")


def jpeg(w=320, h=180, colour=(200, 30, 30)):
    buf = io.BytesIO()
    Image.new("RGB", (w, h), colour).save(buf, "JPEG")
    return buf.getvalue()


@pytest.fixture
def env(tmp_path, monkeypatch):
    music = tmp_path / "music"
    music.mkdir()
    settings = Settings(token=TOKEN, music_dir=music, navidrome_url="http://navidrome:4533",
                        navidrome_user="u", navidrome_password="p")
    calls = {"yt": [], "ffmpeg": [], "rescan": 0}

    monkeypatch.setattr(ytdl, "extract_info", fake_info)
    monkeypatch.setattr(ytdl, "version", lambda s: "2026.10.01")

    def fake_download(url, dest, s, on_progress):
        calls["yt"].append(url)
        on_progress(0.5)
        f = dest / (VID + ".webm")
        f.write_bytes(b"audio")
        on_progress(1.0)
        return f

    def fake_convert(src, dest, s):
        calls["ffmpeg"].append((src.name, dest.name))
        dest.write_bytes(b"\xff\xfb\x90\x00" + b"\x00" * 64)  # not real audio

    monkeypatch.setattr(ytdl, "download_audio", fake_download)
    monkeypatch.setattr(media, "convert_to_mp3", fake_convert)
    monkeypatch.setattr(media, "fetch_cover", lambda url: media.square_cover(jpeg()))

    def fake_rescan(s):
        calls["rescan"] += 1
        return None

    monkeypatch.setattr(rescan, "rescan_library", fake_rescan)
    client = TestClient(main.create_app(settings))
    return client, settings, calls


def wait_done(client, job_id):
    for _ in range(100):
        j = client.get("/jobs/" + job_id, headers=AUTH).json()
        if j["status"] in ("done", "failed"):
            return j
        time.sleep(0.02)
    raise AssertionError("job did not finish")


# ---- auth --------------------------------------------------------------

def test_health_needs_no_token(env):
    client, *_ = env
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["ytDlpVersion"] == "2026.10.01"
    assert "version" in r.json()


@pytest.mark.parametrize("headers", [{}, {"Authorization": "Bearer nope"}, {"Authorization": TOKEN},
                                     {"Authorization": "Basic " + TOKEN}])
def test_everything_else_needs_the_token(env, headers):
    client, *_ = env
    for method, path, body in [("post", "/validate", {"url": URL}), ("post", "/download", {"url": URL}),
                               ("get", "/jobs/abc", None)]:
        r = getattr(client, method)(path, headers=headers, **({"json": body} if body else {}))
        assert r.status_code == 401, path
        assert r.json()["code"] == "unauthorized"


# ---- validate ----------------------------------------------------------

def test_validate_returns_preview(env):
    client, *_ = env
    r = client.post("/validate", json={"url": URL}, headers=AUTH)
    assert r.status_code == 200
    body = r.json()
    assert body["valid"] is True
    assert body["videoId"] == VID
    assert body["durationSeconds"] == 187
    assert body["thumbnailUrl"] == "https://img/x.jpg"
    assert body["parsed"] == {"artist": "Cochise & Pradabagshawty", "albumArtist": "Cochise",
                              "title": "IMGEEKED, IM HIGH, IM FCKED UP"}
    assert body["alreadyExists"] is False


def test_validate_rejects_non_youtube_without_calling_yt_dlp(env, monkeypatch):
    client, *_ = env
    monkeypatch.setattr(ytdl, "extract_info", lambda *a: pytest.fail("must not be called"))
    r = client.post("/validate", json={"url": "https://vimeo.com/1"}, headers=AUTH)
    assert r.status_code == 422
    assert r.json()["valid"] is False and "YouTube" in r.json()["error"]


def test_validate_rejects_playlists(env):
    client, *_ = env
    r = client.post("/validate", json={"url": "https://www.youtube.com/playlist?list=PL1"}, headers=AUTH)
    assert r.status_code == 422 and "playlist" in r.json()["error"]


def test_validate_reports_yt_dlp_failures(env, monkeypatch):
    client, *_ = env

    def boom(url, s):
        raise ytdl.YtDlpError("That video is private.")

    monkeypatch.setattr(ytdl, "extract_info", boom)
    r = client.post("/validate", json={"url": URL}, headers=AUTH)
    assert r.status_code == 422 and r.json()["error"] == "That video is private."


def test_explain_failure_messages():
    assert "private" in ytdl.explain_failure("ERROR: [youtube] x: Private video. Sign in")
    assert "region" in ytdl.explain_failure("The uploader has not made this video available in your country")
    assert "unavailable" in ytdl.explain_failure("ERROR: Video unavailable")
    assert "age" in ytdl.explain_failure("Sign in to confirm your age")
    assert ytdl.explain_failure("weird\nlast line").endswith("last line")


def test_best_thumbnail_prefers_the_largest():
    thumbs = [{"url": "a", "width": 120, "height": 90}, {"url": "b", "width": 1280, "height": 720},
              {"url": "c"}]
    assert ytdl.best_thumbnail(thumbs) == "b"
    assert ytdl.best_thumbnail([]) is None


# ---- download ----------------------------------------------------------

def test_download_pipeline_end_to_end(env):
    client, settings, calls = env
    r = client.post("/download", json={"url": URL}, headers=AUTH)
    assert r.status_code == 200
    job = wait_done(client, r.json()["jobId"])
    assert job["status"] == "done", job
    assert job["progress"] == 1.0
    assert job["file"] == "Cochise & Pradabagshawty - IMGEEKED, IM HIGH, IM FCKED UP.mp3"
    assert job["warning"] is None

    out = settings.music_dir / job["file"]
    assert out.exists()
    tags = ID3(str(out))
    assert str(tags["TIT2"]) == "IMGEEKED, IM HIGH, IM FCKED UP"
    assert str(tags["TPE1"]) == "Cochise & Pradabagshawty"
    assert str(tags["TPE2"]) == "Cochise"
    assert str(tags["TALB"]) == "IMGEEKED, IM HIGH, IM FCKED UP"
    cover = tags.getall("APIC")[0]
    assert cover.type == 3 and cover.mime == "image/jpeg"
    assert Image.open(io.BytesIO(cover.data)).size[0] == Image.open(io.BytesIO(cover.data)).size[1]
    assert calls["rescan"] == 1
    assert list(settings.music_dir.iterdir()) == [out], "no temp files left in the library"


def test_duplicate_refused_unless_forced(env):
    client, settings, calls = env
    first = client.post("/download", json={"url": URL}, headers=AUTH).json()["jobId"]
    assert wait_done(client, first)["status"] == "done"

    v = client.post("/validate", json={"url": URL}, headers=AUTH).json()
    assert v["alreadyExists"] is True

    r = client.post("/download", json={"url": URL}, headers=AUTH)
    assert r.status_code == 409 and r.json()["code"] == "already_exists"

    r = client.post("/download", json={"url": URL, "force": True}, headers=AUTH)
    assert r.status_code == 200
    assert wait_done(client, r.json()["jobId"])["status"] == "done"


def test_rescan_failure_is_a_warning_not_a_failure(env, monkeypatch):
    client, *_ = env
    monkeypatch.setattr(rescan, "rescan_library", lambda s: "Saved, but the Navidrome rescan failed (ConnectError).")
    job = wait_done(client, client.post("/download", json={"url": URL}, headers=AUTH).json()["jobId"])
    assert job["status"] == "done" and "rescan failed" in job["warning"]


def test_failed_download_reports_error_and_leaves_nothing(env, monkeypatch):
    client, settings, _ = env

    def boom(*a, **k):
        raise ytdl.YtDlpError("That video is unavailable.")

    monkeypatch.setattr(ytdl, "download_audio", boom)
    job = wait_done(client, client.post("/download", json={"url": URL}, headers=AUTH).json()["jobId"])
    assert job["status"] == "failed" and job["error"] == "That video is unavailable."
    assert list(settings.music_dir.iterdir()) == []


def test_ffmpeg_failure_fails_the_job(env, monkeypatch):
    client, settings, _ = env

    def boom(*a):
        raise media.MediaError("ffmpeg isn't installed on the server.")

    monkeypatch.setattr(media, "convert_to_mp3", boom)
    job = wait_done(client, client.post("/download", json={"url": URL}, headers=AUTH).json()["jobId"])
    assert job["status"] == "failed" and "ffmpeg" in job["error"]


def test_missing_cover_still_succeeds(env, monkeypatch):
    client, settings, _ = env
    monkeypatch.setattr(media, "fetch_cover", lambda url: None)
    job = wait_done(client, client.post("/download", json={"url": URL}, headers=AUTH).json()["jobId"])
    assert job["status"] == "done"
    assert ID3(str(settings.music_dir / job["file"])).getall("APIC") == []


def test_unknown_job(env):
    client, *_ = env
    assert client.get("/jobs/nope", headers=AUTH).status_code == 404


# ---- media helpers -----------------------------------------------------

def test_square_cover_centre_crops():
    # Left third red, middle green, right third blue; a 3:1 image crops to the green middle.
    img = Image.new("RGB", (300, 100))
    for x in range(300):
        for y in range(100):
            img.putpixel((x, y), (255, 0, 0) if x < 100 else (0, 255, 0) if x < 200 else (0, 0, 255))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    out = Image.open(io.BytesIO(media.square_cover(buf.getvalue())))
    assert out.size == (100, 100) and out.format == "JPEG"
    r, g, b = out.getpixel((50, 50))
    assert g > 200 and r < 60 and b < 60


def test_square_cover_downsizes_large_images():
    out = Image.open(io.BytesIO(media.square_cover(jpeg(3000, 2000))))
    assert out.size == (media.COVER_SIZE, media.COVER_SIZE)


@pytest.mark.parametrize("raw,clean", [
    ("AC/DC: Back In Black?", "ACDC Back In Black"),
    ("..hidden..", "hidden"),
    ('a<b>c|d"e', "abcde"),
    ("  many   spaces  ", "many spaces"),
    ("", "Unknown"),
    ("../../etc/passwd", "etcpasswd"),
])
def test_sanitize(raw, clean):
    assert media.sanitize(raw) == clean


def test_sanitize_caps_length_in_bytes():
    assert len(media.sanitize("é" * 300).encode()) <= 180


def test_target_path_stays_inside_music_dir(tmp_path):
    p = media.target_path(tmp_path, "../../x", "y/z")
    assert p.parent == tmp_path and p.name == "x - yz.mp3"


def test_rescan_uses_token_and_salt_auth(monkeypatch, tmp_path):
    seen = {}

    class R:
        def raise_for_status(self): pass
        def json(self): return {"subsonic-response": {"status": "ok"}}

    def fake_get(url, params, timeout):
        seen.update(url=url, params=params)
        return R()

    monkeypatch.setattr(navidrome.httpx, "get", fake_get)
    s = Settings(token=TOKEN, music_dir=tmp_path, navidrome_url="http://n:4533", navidrome_user="u",
                 navidrome_password="p")
    assert navidrome.rescan(s) is None
    p = seen["params"]
    import hashlib
    assert seen["url"] == "http://n:4533/rest/startScan.view"
    assert p["t"] == hashlib.md5(("p" + p["s"]).encode()).hexdigest()
    assert "p" not in p and "password" not in p


def test_rescan_never_raises(monkeypatch, tmp_path):
    def boom(*a, **k):
        raise RuntimeError("down")

    monkeypatch.setattr(navidrome.httpx, "get", boom)
    s = Settings(token=TOKEN, music_dir=tmp_path, navidrome_url="http://n", navidrome_user="u",
                 navidrome_password="p")
    assert "rescan failed" in navidrome.rescan(s)
    assert "isn't configured" in navidrome.rescan(Settings(token=TOKEN, music_dir=tmp_path))


# ---- config ------------------------------------------------------------

def test_config_requires_token_and_music_dir(tmp_path):
    with pytest.raises(ConfigError):
        load_settings({"MUSIC_DIR": str(tmp_path)})
    with pytest.raises(ConfigError):
        load_settings({"COMPANION_TOKEN": "short", "MUSIC_DIR": str(tmp_path)})
    with pytest.raises(ConfigError):
        load_settings({"COMPANION_TOKEN": TOKEN})
    with pytest.raises(ConfigError):
        load_settings({"COMPANION_TOKEN": TOKEN, "MUSIC_DIR": str(tmp_path / "missing")})
    s = load_settings({"COMPANION_TOKEN": TOKEN, "MUSIC_DIR": str(tmp_path), "YT_DLP_PATH": "/x/yt-dlp",
                       "NAVIDROME_URL": "http://n:4533/"})
    assert s.yt_dlp_command() == ["/x/yt-dlp"] and s.navidrome_url == "http://n:4533"


# ---- other media servers -----------------------------------------------

def test_jellyfin_rescan(monkeypatch, tmp_path):
    seen = {}

    class R:
        def raise_for_status(self): pass

    def fake_post(url, headers, timeout):
        seen.update(url=url, headers=headers)
        return R()

    monkeypatch.setattr(jellyfin.httpx, "post", fake_post)
    s = Settings(token=TOKEN, music_dir=tmp_path, jellyfin_url="http://jf:8096", jellyfin_api_key="KEY")
    assert rescan.rescan_library(s) is None
    assert seen == {"url": "http://jf:8096/Library/Refresh", "headers": {"X-Emby-Token": "KEY"}}

    def boom(*a, **k):
        raise RuntimeError("down")

    monkeypatch.setattr(jellyfin.httpx, "post", boom)
    assert "Jellyfin rescan failed" in rescan.rescan_library(s)


def test_backend_choice(tmp_path):
    base = dict(token=TOKEN, music_dir=tmp_path)
    assert Settings(**base).library_backend == "none"
    assert Settings(navidrome_url="http://n", **base).library_backend == "navidrome"
    assert Settings(jellyfin_url="http://j", **base).library_backend == "jellyfin"
    assert Settings(navidrome_url="http://n", jellyfin_url="http://j",
                    library_backend_setting="jellyfin", **base).library_backend == "jellyfin"
    assert "No media server" in rescan.rescan_library(Settings(**base))
    assert "No media server" in rescan.rescan_library(
        Settings(navidrome_url="http://n", library_backend_setting="none", **base))


def test_config_reads_jellyfin_and_checks_backend(tmp_path):
    env = {"COMPANION_TOKEN": TOKEN, "MUSIC_DIR": str(tmp_path), "JELLYFIN_URL": "http://j:8096/",
           "JELLYFIN_API_KEY": "k"}
    s = load_settings(env)
    assert s.library_backend == "jellyfin" and s.jellyfin_url == "http://j:8096"
    with pytest.raises(ConfigError):
        load_settings(dict(env, LIBRARY_BACKEND="plex"))
