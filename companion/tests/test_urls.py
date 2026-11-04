import pytest

from app.urls import InvalidLink, video_id_from_url

VID = "dQw4w9WgXcQ"


@pytest.mark.parametrize("url", [
    "https://www.youtube.com/watch?v=" + VID,
    "https://youtube.com/watch?v=" + VID + "&t=30s",
    "http://m.youtube.com/watch?v=" + VID,
    "https://music.youtube.com/watch?v=" + VID,
    "https://youtu.be/" + VID,
    "https://youtu.be/" + VID + "?si=abc",
    "youtu.be/" + VID,
    "https://www.youtube.com/shorts/" + VID,
    "https://www.youtube.com/watch?v=" + VID + "&list=PL123",  # one video, list ignored
    "  https://www.youtube.com/watch?v=" + VID + "  ",
])
def test_accepts(url):
    assert video_id_from_url(url) == VID


@pytest.mark.parametrize("url,fragment", [
    ("https://vimeo.com/123", "YouTube"),
    ("https://evil.com/watch?v=" + VID, "YouTube"),
    ("https://www.youtube.com.evil.com/watch?v=" + VID, "YouTube"),
    ("https://notyoutube.com/watch?v=" + VID, "YouTube"),
    ("ftp://www.youtube.com/watch?v=" + VID, "valid"),
    ("https://www.youtube.com/playlist?list=PL123", "playlist"),
    ("https://www.youtube.com/@someone", "channel"),
    ("https://www.youtube.com/watch", "single"),
    ("https://www.youtube.com/watch?v=short", "single"),
    ("https://youtu.be/", "single"),
    ("", "Paste"),
    ("not a url", "YouTube"),
])
def test_rejects(url, fragment):
    with pytest.raises(InvalidLink) as e:
        video_id_from_url(url)
    assert fragment in str(e.value)
