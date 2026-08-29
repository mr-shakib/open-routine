"""Faculty directory lookups."""

from __future__ import annotations

import logging

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.models import Teacher

logger = logging.getLogger(__name__)


async def get_teacher(session: AsyncSession, initial: str) -> Teacher | None:
    result: Teacher | None = await session.scalar(
        select(Teacher).where(func.upper(Teacher.initial) == initial.strip().upper())
    )
    return result


async def list_teachers(session: AsyncSession, department: str | None = None) -> list[Teacher]:
    stmt = select(Teacher).order_by(Teacher.name)
    if department:
        stmt = stmt.where(func.lower(Teacher.department) == department.lower())
    return list((await session.scalars(stmt)).all())


async def upsert_teachers(session: AsyncSession, records: list[dict[str, str | None]]) -> int:
    """Insert or update directory entries, keyed on the initial."""
    existing = {t.initial: t for t in await list_teachers(session)}
    written = 0
    for record in records:
        initial = (record.get("initial") or "").strip().upper()
        if not initial:
            continue
        teacher = existing.get(initial)
        if teacher is not None and teacher.name != (record.get("name") or teacher.name):
            # The published directory really does contain collisions (two "SAS"
            # entries at the time of writing). The routine identifies teachers by
            # initial alone, so this is ambiguous at the source -- surface it
            # rather than silently keeping whichever record was loaded last.
            logger.warning(
                "Duplicate teacher initial %r: %r will be replaced by %r",
                initial,
                teacher.name,
                record.get("name"),
            )
        if teacher is None:
            teacher = Teacher(initial=initial, name=record.get("name") or initial)
            session.add(teacher)
            existing[initial] = teacher
        teacher.name = record.get("name") or teacher.name
        teacher.designation = record.get("designation")
        teacher.department = record.get("department")
        teacher.office_room = record.get("office_room")
        teacher.image_url = record.get("image_url")
        written += 1
    await session.flush()
    return written
