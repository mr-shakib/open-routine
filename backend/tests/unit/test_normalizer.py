from __future__ import annotations

import pytest

from open_routine.ingestion.normalizer import (
    ROOM_TYPE_COMPUTER_LAB,
    ROOM_TYPE_ELECTRICAL_LAB,
    ROOM_TYPE_PHYSICS_LAB,
    ROOM_TYPE_THEORY,
    normalise_room,
    normalise_whitespace,
    split_name_initial,
)


class TestRoomNormalisation:
    def test_strips_the_embedded_newline_artifact(self) -> None:
        """The app we studied ships `"KT-503\\n  (COM LAB)"` as a dictionary key."""
        assert normalise_room("KT-503\n  (COM LAB)") == ("KT-503", ROOM_TYPE_COMPUTER_LAB)

    def test_plain_room_is_theory(self) -> None:
        assert normalise_room("KT-515") == ("KT-515", ROOM_TYPE_THEORY)

    def test_physics_lab(self) -> None:
        assert normalise_room("G1-020\n(Physics Lab)") == ("G1-020", ROOM_TYPE_PHYSICS_LAB)

    def test_multi_line_electrical_annotation(self) -> None:
        raw = "KT-301\n(Electrical\nCircuits Lab and\nBasic Electronics\nLab)"
        assert normalise_room(raw) == ("KT-301", ROOM_TYPE_ELECTRICAL_LAB)

    @pytest.mark.parametrize("room", ["KT-517(A)", "KT-318(B)", "KT-801(B)"])
    def test_a_bracketed_room_suffix_is_kept(self, room: str) -> None:
        """`KT-517(A)` is a room name, not a room with an annotation."""
        assert normalise_room(room) == (room, ROOM_TYPE_THEORY)

    def test_blank(self) -> None:
        assert normalise_room("") == ("", ROOM_TYPE_THEORY)


def test_normalise_whitespace_collapses_newlines_and_nbsp() -> None:
    # Built from a code point so the literal stays plain ASCII.
    nbsp_input = "a\n  b\t" + chr(0xA0) + "c"
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
