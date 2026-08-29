"""Parse one routine cell into its parts.

A populated cell fuses three facts into a scrap of text::

    CSE414(62_E1)
    SRH

The course code carries *what* the class is and *who attends* in one token, and
a second line carries the teacher's initial. Room and day come from the row, and
the time slot from the column, so the cell itself only needs these.

``course_code`` is deliberately kept fused. ``batch`` and ``section`` are derived
*alongside* it, never by destroying the original token.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

#: The parenthetical in a course code: CSE414(62_E1) -> 62_E1
SECTION_RE = re.compile(r"\(([^)]+)\)")

#: A section, optionally with a lab subsection: 62_E1 -> ("62_E", "1")
BATCH_RE = re.compile(r"^(\d+_[A-Z])(\d+)?$", re.IGNORECASE)

#: A course token: letters, digits, then a parenthesised section.
COURSE_RE = re.compile(r"\b([A-Z]{2,6}\s?\d{3,4}[A-Z]?)\s*\(([^)]+)\)", re.IGNORECASE)

#: A bare teacher initial: 2-5 uppercase letters standing alone.
INITIAL_RE = re.compile(r"^[A-Z]{2,5}$")

#: Elective courses are prefixed "T" (TCSE412, TCSE332).
OPTIONAL_PREFIX = "TCSE"

#: Reserved sentinel for an unassigned teacher.
TBA = "TBA"


@dataclass(frozen=True, slots=True)
class ParsedCell:
    """The structured content of one populated routine cell."""

    course_code: str  #: fused source token, e.g. "CSE414(62_E1)"
    batch: str  #: "62_E"
    section: str  #: "62_E1"
    teacher: str  #: "SRH", or "TBA"
    is_lab: bool  #: the section carries a subsection suffix
    is_optional: bool  #: elective course
    room_override: str | None = None  #: room named inside the cell, if any


def split_section(section: str) -> tuple[str, str | None]:
    """Split a section into ``(batch, subsection)``.

    ``"62_E1" -> ("62_E", "1")`` and ``"62_E" -> ("62_E", None)``. A section that
    does not match the pattern is returned unchanged with no subsection, so an
    unfamiliar naming scheme degrades rather than raising.
    """
    match = BATCH_RE.match(section.strip())
    if not match:
        return section.strip(), None
    return match.group(1).upper(), match.group(2)


def parse_cell(text: str) -> ParsedCell | None:
    """Parse a cell's text, or return ``None`` if it holds no class.

    Blank cells, and cells holding only punctuation or a dash placeholder, are
    treated as empty.
    """
    if not text:
        return None
    cleaned = text.replace("\xa0", " ").strip()
    if not cleaned or cleaned in {"-", "--", "N/A", "x", "X"}:
        return None

    course_match = COURSE_RE.search(cleaned)
    if not course_match:
        return None

    code_part = course_match.group(1).replace(" ", "").upper()
    section_raw = course_match.group(2).strip().upper()
    course_code = f"{code_part}({section_raw})"

    batch, subsection = split_section(section_raw)

    # Everything that is not the course token is a candidate for the initial.
    remainder = cleaned[: course_match.start()] + " " + cleaned[course_match.end() :]
    teacher = _find_initial(remainder)

    return ParsedCell(
        course_code=course_code,
        batch=batch,
        section=section_raw,
        teacher=teacher,
        is_lab=subsection is not None,
        is_optional=code_part.startswith(OPTIONAL_PREFIX),
        room_override=_find_room(remainder),
    )


def _find_initial(text: str) -> str:
    """Pick the teacher initial out of a cell's leftover text."""
    for token in re.split(r"[\s,;/|]+", text.strip()):
        token = token.strip(".:-()").upper()
        if not token or token == TBA:
            continue
        # Skip anything that looks like a room rather than an initial.
        if _ROOM_RE.match(token):
            continue
        if INITIAL_RE.match(token):
            return token
    return TBA


#: Room codes seen in published routines: KT-503, G1-007, CTBA-02.
_ROOM_RE = re.compile(r"^[A-Z]{1,4}\d?-\d{2,4}(\([AB]\))?$", re.IGNORECASE)


def _find_room(text: str) -> str | None:
    """Return a room code written inside the cell, if there is one."""
    for token in re.split(r"[\s,;/|]+", text.strip()):
        token = token.strip(".:").upper()
        if _ROOM_RE.match(token):
            return token
    return None
