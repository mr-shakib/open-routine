"""Student and teacher schedule queries.

Both are index seeks. In the app we studied these were O(1) dictionary lookups
into a pre-inverted index that stored every class twice; here the ``(routine_id,
batch)`` and ``(routine_id, teacher)`` indexes give the same access pattern from
a single copy of each row.
"""

from __future__ import annotations

from sqlalchemy import Select, case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.ingestion.cell_parser import TBA
from open_routine.ingestion.lattice import DAY_INDEX, DAYS
from open_routine.models import ClassSession


def _ordered(stmt: Select[tuple[ClassSession]]) -> Select[tuple[ClassSession]]:
    """Order by day of week, then by start time within the day.

    Day order is expressed as a CASE so the database returns academic-week order
    directly (Saturday first), rather than the lexical order a plain sort gives.
    ``start_min`` orders within a day; it is never used to decide occupancy.
    """
    day_rank = case(
        {day: index for index, day in enumerate(DAYS)},
        value=ClassSession.day,
        else_=len(DAYS),
    )
    return stmt.order_by(day_rank, ClassSession.start_min)


async def get_student_schedule(
    session: AsyncSession,
    routine_id: int,
    batch: str,
    *,
    include_optional: bool = True,
) -> list[ClassSession]:
    """Every class for one batch. Index: ``(routine_id, batch)``."""
    stmt = select(ClassSession).where(
        ClassSession.routine_id == routine_id,
        func.upper(ClassSession.batch) == batch.strip().upper(),
    )
    if not include_optional:
        stmt = stmt.where(ClassSession.is_optional.is_(False))
    rows = list((await session.scalars(_ordered(stmt))).all())
    return sort_by_day_then_time(rows)


async def get_teacher_schedule(
    session: AsyncSession,
    routine_id: int,
    initial: str,
    *,
    include_optional: bool = True,
) -> list[ClassSession]:
    """Every class taught by one initial. Index: ``(routine_id, teacher)``.

    The initial is normalised at ingestion, so this needs no name resolution.
    """
    stmt = select(ClassSession).where(
        ClassSession.routine_id == routine_id,
        func.upper(ClassSession.teacher) == initial.strip().upper(),
    )
    if not include_optional:
        stmt = stmt.where(ClassSession.is_optional.is_(False))
    rows = list((await session.scalars(_ordered(stmt))).all())
    return sort_by_day_then_time(rows)


def sort_by_day_then_time(rows: list[ClassSession]) -> list[ClassSession]:
    """Sort into academic-week order.

    Day order is explicit, never lexical: the week starts on Saturday here.
    """
    return sorted(rows, key=lambda r: (DAY_INDEX.get(r.day, len(DAYS)), r.start_min))


def group_by_day(rows: list[ClassSession]) -> dict[str, list[ClassSession]]:
    """Bucket a schedule into the six working days, empty days included."""
    grouped: dict[str, list[ClassSession]] = {day: [] for day in DAYS}
    for row in sort_by_day_then_time(rows):
        grouped.setdefault(row.day, []).append(row)
    return grouped


async def distinct_teachers(session: AsyncSession, routine_id: int, batch: str) -> list[str]:
    """Initials teaching a batch, for the faculty strip. ``TBA`` excluded."""
    rows = await session.scalars(
        select(ClassSession.teacher)
        .where(
            ClassSession.routine_id == routine_id,
            func.upper(ClassSession.batch) == batch.strip().upper(),
            ClassSession.teacher != TBA,
        )
        .distinct()
    )
    return sorted(set(rows.all()))
