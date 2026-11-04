"""ytdl.py against a stand-in yt-dlp executable (a small script)."""
import json
import stat
import sys

import pytest

from app import ytdl
from app.config import Settings

FAKE = '''#!{py}
import json, sys
args = sys.argv[1:]
if "--version" in args:
    print("2026.10.01"); sys.exit(0)
url = args[-1]
if "private" in url:
    sys.stderr.write("ERROR: [youtube] x: Private video. Sign in if you've been granted access\\n"); sys.exit(1)
if "--dump-single-json" in args:
    if "playlist" in url:
        print(json.dumps({{"_type": "playlist", "entries": [{{}}]}})); sys.exit(0)
    print(json.dumps({{"id": "dQw4w9WgXcQ", "title": "A - B (HQ)", "channel": "Chan", "duration": 61.0,
        "thumbnails": [{{"url": "small", "width": 10, "height": 10}}, {{"url": "big", "width": 1280, "height": 720}}]}}))
    sys.exit(0)
out = args[args.index("-o") + 1].replace("%(id)s", "dQw4w9WgXcQ").replace("%(ext)s", "webm")
open(out, "wb").write(b"x")
print("PROGRESS 50 100 NA")
print("PROGRESS 100 NA 100")
print(out)
'''


@pytest.fixture
def settings(tmp_path):
    exe = tmp_path / "yt-dlp"
    exe.write_text(FAKE.format(py=sys.executable))
    exe.chmod(exe.stat().st_mode | stat.S_IEXEC)
    music = tmp_path / "music"
    music.mkdir()
    return Settings(token="x" * 20, music_dir=music, yt_dlp_path=str(exe))


def test_version(settings):
    assert ytdl.version(settings) == "2026.10.01"


def test_extract_info(settings):
    info = ytdl.extract_info("https://www.youtube.com/watch?v=dQw4w9WgXcQ", settings)
    assert (info.video_id, info.title, info.channel, info.duration, info.thumbnail_url) == (
        "dQw4w9WgXcQ", "A - B (HQ)", "Chan", 61, "big")


def test_extract_info_errors(settings):
    with pytest.raises(ytdl.YtDlpError, match="private"):
        ytdl.extract_info("https://youtu.be/private", settings)
    with pytest.raises(ytdl.YtDlpError, match="playlist"):
        ytdl.extract_info("https://youtu.be/playlist", settings)


def test_missing_binary(tmp_path):
    s = Settings(token="x" * 20, music_dir=tmp_path, yt_dlp_path=str(tmp_path / "nope"))
    with pytest.raises(ytdl.YtDlpError, match="YT_DLP_PATH"):
        ytdl.extract_info("https://youtu.be/dQw4w9WgXcQ", s)
    assert ytdl.version(s) == "unavailable"


def test_download_audio_reports_progress(settings, tmp_path):
    seen = []
    f = ytdl.download_audio("https://youtu.be/dQw4w9WgXcQ", tmp_path, settings, seen.append)
    assert f.name == "dQw4w9WgXcQ.webm" and f.exists()
    assert seen == [0.5, 1.0]


def test_download_failure(settings, tmp_path):
    with pytest.raises(ytdl.YtDlpError, match="private"):
        ytdl.download_audio("https://youtu.be/private", tmp_path, settings, lambda f: None)
