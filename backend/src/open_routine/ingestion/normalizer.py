"""Clean values lifted straight out of spreadsheet cells.

Cell text arrives with the artifacts of its origin. The app we studied never
stripped them: its published room list contains keys like ``"KT-503\\n  (COM
LAB)"`` -- an embedded newline surviving into a dictionary key. We normalise at
ingestion so every downstream comparison is on clean data.
"""

from __future__ import annotations

import re

#: Room type markers that appear appended to a room's name in the sheet.
_LAB_MARKERS = ("COM LAB", "COMPUTER LAB", "LAB")

ROOM_TYPE_THEORY = "Theory"
ROOM_TYPE_COMPUTER_LAB = "Computer Lab"


def normalise_whitespace(value: str) -> str:
    """Collapse newlines, non-breaking spaces and runs of whitespace."""
    if not value:
        return ""
    return " ".join(value.replace("\xa0", " ").split())


def normalise_room(raw: str) -> tuple[str, str]:
    """Split a room cell into ``(room, room_type)``.

    ``"KT-503\\n  (COM LAB)"`` becomes ``("KT-503", "Computer Lab")``. A room with
    no marker is Theory.
    """
    flat = normalise_whitespace(raw).upper()
    if not flat:
        return "", ROOM_TYPE_THEORY

    room_type = ROOM_TYPE_THEORY
    for marker in _LAB_MARKERS:
        # Match the marker only when parenthesised or trailing, so a room
        # legitimately named "LAB-2" is not misread.
        pattern = re.compile(rf"\(?\s*{re.escape(marker)}\s*\)?\s*$")
        if pattern.search(flat):
            room_type = ROOM_TYPE_COMPUTER_LAB
            flat = pattern.sub("", flat).strip()
            break

    return flat.strip(" -"), room_type


def normalise_initial(raw: str) -> str:
    """Uppercase a teacher initial and strip surrounding punctuation."""
    return normalise_whitespace(raw).strip(".:-()").upper()


#: Faculty directory names embed the initial: "Dr. Sheak Rashed Haider Noori (SRH)".
_NAME_INITIAL_RE = re.compile(r"^(.*?)\s*\(([A-Z]{2,5})\)\s*$")


def split_name_initial(raw: str) -> tuple[str, str | None]:
    """Split ``"Full Name (INI)"`` into ``("Full Name", "INI")``.

    Returns ``(name, None)`` when no initial is present, so a malformed
    directory entry is kept rather than dropped.
    """
    flat = normalise_whitespace(raw)
    match = _NAME_INITIAL_RE.match(flat)
    if not match:
        return flat, None
    return match.group(1).strip(), match.group(2).upper()
