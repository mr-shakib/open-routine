from __future__ import annotations

import pytest

from open_routine.ingestion.normalizer import (
    ROOM_TYPE_COMPUTER_LAB,
    ROOM_TYPE_THEORY,
    normalise_room,
    normalise_whitespace,
    split_name_initial,
)


def test_strips_the_embedded_newline_artifact() -> None:
    """The app we studied leaves `"KT-503\\n  (COM LAB)"` in its room keys."""
    room, room_type = normalise_room("KT-503\n  (COM LAB)")
    assert room == "KT-503"
    assert room_type == ROOM_TYPE_COMPUTER_LAB


def test_plain_room_is_theory() -> None:
    assert normalise_room("KT-515") == ("KT-515", ROOM_TYPE_THEORY)


def test_room_named_lab_is_not_misread_as_a_lab_marker() -> None:
    room, room_type = normalise_room("LAB-2")
    assert room == "LAB-2"
    assert room_type == ROOM_TYPE_THEORY


def test_normalise_whitespace_collapses_newlines_and_nbsp() -> None:
    nbsp_input = "a\n  b\t\u00a0c"
    assert normalise_whitespace(nbsp_input) == "a b c"


@pytest.mark.parametrize(
    ("raw", "name", "initial"),
    [
        ("Dr. Sheak Rashed Haider Noori (SRH)", "Dr. Sheak Rashed Haider Noori", "SRH"),
        ("Someone Without An Initial", "Someone Without An Initial", None),
    ],
)
def test_split_name_initial(raw: str, name: str, initial: str | None) -> None:
    assert split_name_initial(raw) == (name, initial)
