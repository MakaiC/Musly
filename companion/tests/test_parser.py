import pytest

from app.parser import first_artist, parse_title


def test_snippet_example_keeps_part_number():
    p = parse_title("Cochise - JACKSON (pt. 2) *snippet* (EXTENDED EDIT) (Prod. @proddreamz , @NateMorganYt & Eliyf)")
    assert (p.artist, p.title, p.album_artist) == ("Cochise", "JACKSON (pt. 2)", "Cochise")


def test_collab_and_fullwidth_asterisk():
    p = parse_title("Cochise & Pradabagshawty - IMGEEKED, IM HIGH, IM FCKED UP ＊snippet＊ (EXTENDED EDIT) (HQ)")
    assert p.artist == "Cochise & Pradabagshawty"
    assert p.album_artist == "Cochise"
    assert p.title == "IMGEEKED, IM HIGH, IM FCKED UP"


def test_no_separator_uses_channel_and_whole_title():
    p = parse_title("Some Song (Official Video)", "The Band")
    assert (p.artist, p.title) == ("The Band", "Some Song")


def test_topic_channel_suffix_is_stripped():
    assert parse_title("Plain Title", "Artist Name - Topic").artist == "Artist Name"


def test_no_special_characters_untouched():
    p = parse_title("Artist - Plain Song Name")
    assert (p.artist, p.title) == ("Artist", "Plain Song Name")
    assert p.album == "Plain Song Name" if hasattr(p, "album") else True


@pytest.mark.parametrize("raw,song", [
    ("A - Song [Live]", "Song"),
    ("A - Song | Official", "Song"),
    ("A - Song – Remastered", "Song"),
    ("A - Song — Remastered", "Song"),
    ("A - Song (Part 3) (HQ)", "Song (Part 3)"),
    ("A - Song (PT 4)", "Song (PT 4)"),
    ("A - Song (pt. 2)", "Song (pt. 2)"),
    ("A - Song (Pt.2) [x]", "Song (Pt.2)"),
    ("A - Song (feat. B)", "Song"),
])
def test_cutting(raw, song):
    assert parse_title(raw).title == song


def test_capitalisation_untouched():
    assert parse_title("aRtIsT - sOnG").title == "sOnG"


def test_only_first_separator_splits():
    p = parse_title("A - B - C")
    assert (p.artist, p.title) == ("A", "B - C")


def test_empty_song_falls_back_to_raw_title():
    p = parse_title("(Intro) - (Official Audio)", "Chan")
    assert p.title == "(Intro) - (Official Audio)"
    p = parse_title("[Live]", "Chan")
    assert p.title == "[Live]"


def test_empty_everything():
    p = parse_title("", "")
    assert p.artist == "Unknown Artist"


@pytest.mark.parametrize("artist,first", [
    ("Cochise & Pradabagshawty", "Cochise"),
    ("A, B", "A"),
    ("A x B", "A"),
    ("A X B", "A"),
    ("A feat. B", "A"),
    ("A ft. B", "A"),
    ("Max Richter", "Max Richter"),
    ("Brooklyn", "Brooklyn"),  # an x inside a word is not a separator
])
def test_first_artist(artist, first):
    assert first_artist(artist) == first
