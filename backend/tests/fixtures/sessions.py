"""Seed a routine straight into the database.

Query tests should not depend on the PDF reader: if parsing breaks, the parser
tests should fail, not every service and API test.
"""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.ingestion.lattice import slot_bounds
from open_routine.models import ClassSession, Routine

#: (day, slot, room, room_type, course_code, teacher, batch, section, is_lab)
SESSIONS: list[tuple[str, str, str, str, str, str, str, str, bool]] = [
    (
        "Saturday",
        "08:30-10:00",
        "KT-503",
        "Computer Lab",
        "CSE322(66_B1)",
        "AAM",
        "66_B",
        "66_B1",
        True,
    ),
    (
        "Saturday",
        "10:00-11:30",
        "KT-503",
        "Computer Lab",
        "CSE322(66_B1)",
        "AAM",
        "66_B",
        "66_B1",
        True,
    ),
    ("Saturday", "08:30-10:00", "KT-515", "Theory", "CSE315(66_E)", "AS", "66_E", "66_E", False),
    ("Saturday", "01:00-02:30", "KT-515", "Theory", "TCSE412(61_A)", "SAH", "61_A", "61_A", False),
    (
        "Saturday",
        "11:30-01:00",
        "G1-007",
        "Computer Lab",
        "CSE322(66_B2)",
        "AAM",
        "66_B",
        "66_B2",
        True,
    ),
    (
        "Sunday",
        "10:00-11:30",
        "KT-503",
        "Computer Lab",
        "CSE322(66_B1)",
        "AAM",
        "66_B",
        "66_B1",
        True,
    ),
    ("Sunday", "08:30-10:00", "KT-515", "Theory", "CSE315(66_E)", "AS", "66_E", "66_E", False),
    ("Sunday", "10:00-11:30", "KT-515", "Theory", "CSE321(66_E)", "TBA", "66_E", "66_E", False),
    ("Monday", "02:30-04:00", "KT-801(A)", "Theory", "CSE315(66_E)", "MAH", "66_E", "66_E", False),
    ("Tuesday", "04:00-05:30", "KT-515", "Theory", "CSE213(RE_A)", "NAE", "RE_A", "RE_A", False),
    (
        "Wednesday",
        "08:30-10:00",
        "G1-007",
        "Computer Lab",
        "CSE322(66_B2)",
        "AAM",
        "66_B",
        "66_B2",
        True,
    ),
    (
        "Thursday",
        "11:30-01:00",
        "KT-503",
        "Computer Lab",
        "CSE321(66_E)",
        "AS",
        "66_E",
        "66_E",
        False,
    ),
]


async def seed_routine(
    session: AsyncSession, *, department: str = "cse", version: str = "5"
) -> Routine:
    routine = Routine(
        department=department,
        version=version,
        semester="Summer 2026",
        source_filename="CSE Class Routine V5 Summer-2026.pdf",
        is_active=True,
        published_at=datetime.now(UTC),
        session_count=len(SESSIONS),
    )
    session.add(routine)
    await session.flush()

    for day, slot, room, room_type, code, teacher, batch, section, is_lab in SESSIONS:
        start, end = slot_bounds(slot)
        session.add(
            ClassSession(
                routine_id=routine.id,
                day=day,
                time_slot=slot,
                room=room,
                room_type=room_type,
                course_code=code,
                teacher=teacher,
                batch=batch,
                section=section,
                is_lab=is_lab,
                is_optional=code.startswith("TCSE"),
                start_min=start,
                end_min=end,
            )
        )
    await session.commit()
    return routine
