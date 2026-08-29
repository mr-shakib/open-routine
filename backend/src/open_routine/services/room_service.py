"""Room occupancy: empty-slot search and room lookup.

Both rest on the lattice property. A class occupies exactly one slot, so
occupancy is decided by equality on the slot *label*::

    ClassSession.time_slot == slot

There is no interval arithmetic here, and there must never be. If the source
data ever stops being a fixed lattice, this module needs rewriting -- not
patching -- because ``start_min``/``end_min`` are display values, not truth.
"""

from __future__ import annotations

from sqlalchemy import distinct, select
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.ingestion.lattice import DAYS
from open_routine.models import ClassSession


async def all_rooms(session: AsyncSession, routine_id: int) -> list[str]:
    """Every room appearing anywhere in this routine.

    The room universe is derived from the routine itself, exactly as the app we
    studied does it. A room that hosts no class cannot be reported free, because
    nothing tells us it exists.
    """
    rows = await session.scalars(
        select(distinct(ClassSession.room))
        .where(ClassSession.routine_id == routine_id)
        .order_by(ClassSession.room)
    )
    return list(rows.all())


async def occupied_rooms(session: AsyncSession, routine_id: int, day: str, slot: str) -> set[str]:
    """Rooms busy in one lattice cell. Index: ``(routine_id, day, time_slot)``."""
    rows = await session.scalars(
        select(distinct(ClassSession.room)).where(
            ClassSession.routine_id == routine_id,
            ClassSession.day == day,
            ClassSession.time_slot == slot.strip(),
        )
    )
    return set(rows.all())


async def free_rooms_for_day(
    session: AsyncSession, routine_id: int, day: str, slot: str
) -> list[str]:
    """``all rooms - occupied rooms`` for one day and slot."""
    universe = set(await all_rooms(session, routine_id))
    return sorted(universe - await occupied_rooms(session, routine_id, day, slot))


async def free_rooms_all_days(
    session: AsyncSession, routine_id: int, slot: str
) -> dict[str, list[str]]:
    """Free rooms for every working day at one slot, in a single pass.

    Answering all six days at once matches how the feature is actually used --
    "when is this room free this week" -- and costs one extra query, not six.
    """
    universe = set(await all_rooms(session, routine_id))

    rows = await session.execute(
        select(ClassSession.day, ClassSession.room)
        .where(
            ClassSession.routine_id == routine_id,
            ClassSession.time_slot == slot.strip(),
        )
        .distinct()
    )
    occupied: dict[str, set[str]] = {day: set() for day in DAYS}
    for day, room in rows.all():
        occupied.setdefault(day, set()).add(room)

    return {day: sorted(universe - occupied.get(day, set())) for day in DAYS}


async def find_in_room(
    session: AsyncSession, routine_id: int, room: str, day: str, slot: str
) -> list[ClassSession]:
    """What occupies a room in one lattice cell.

    Index: ``(routine_id, room, day, time_slot)`` -- an index seek, where the app
    we studied did a full linear scan and returned only the first match. Here all
    matches are returned, so a genuine double-booking in the published routine is
    surfaced rather than hidden.
    """
    rows = await session.scalars(
        select(ClassSession).where(
            ClassSession.routine_id == routine_id,
            ClassSession.room == room.strip().upper(),
            ClassSession.day == day,
            ClassSession.time_slot == slot.strip(),
        )
    )
    return list(rows.all())
