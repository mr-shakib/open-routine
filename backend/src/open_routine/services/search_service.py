"""Typeahead over batches, teachers and rooms."""

from __future__ import annotations

from sqlalchemy import distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.ingestion.cell_parser import TBA
from open_routine.models import ClassSession, Teacher

MAX_SUGGESTIONS = 10


async def suggest_batches(session: AsyncSession, routine_id: int, query: str) -> list[str]:
    rows = await session.scalars(
        select(distinct(ClassSession.batch))
        .where(
            ClassSession.routine_id == routine_id,
            ClassSession.batch.ilike(f"%{query.strip()}%"),
        )
        .order_by(ClassSession.batch)
        .limit(MAX_SUGGESTIONS)
    )
    return list(rows.all())


async def suggest_teachers(
    session: AsyncSession, routine_id: int, query: str
) -> list[dict[str, str]]:
    """Initials that actually teach in this routine, with names when known."""
    initials = await session.scalars(
        select(distinct(ClassSession.teacher))
        .where(
            ClassSession.routine_id == routine_id,
            ClassSession.teacher.ilike(f"%{query.strip()}%"),
            ClassSession.teacher != TBA,
        )
        .order_by(ClassSession.teacher)
        .limit(MAX_SUGGESTIONS)
    )
    found = list(initials.all())
    if not found:
        return []

    names = {
        t.initial: t.name
        for t in await session.scalars(
            select(Teacher).where(func.upper(Teacher.initial).in_([i.upper() for i in found]))
        )
    }
    return [{"initial": i, "name": names.get(i.upper(), i)} for i in found]


async def suggest_rooms(session: AsyncSession, routine_id: int, query: str) -> list[str]:
    rows = await session.scalars(
        select(distinct(ClassSession.room))
        .where(
            ClassSession.routine_id == routine_id,
            ClassSession.room.ilike(f"%{query.strip()}%"),
        )
        .order_by(ClassSession.room)
        .limit(MAX_SUGGESTIONS)
    )
    return list(rows.all())
