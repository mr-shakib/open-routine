"""Resolving which routine revision a query runs against."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.core.errors import NoActiveRoutineError, NotFoundError
from open_routine.models import Routine


async def get_active_routine(session: AsyncSession, department: str) -> Routine:
    routine = await session.scalar(
        select(Routine).where(Routine.department == department.lower(), Routine.is_active.is_(True))
    )
    if routine is None:
        raise NoActiveRoutineError(department)
    return routine


async def get_routine(session: AsyncSession, routine_id: int) -> Routine:
    routine = await session.get(Routine, routine_id)
    if routine is None:
        raise NotFoundError(f"Routine {routine_id} not found")
    return routine


async def list_routines(session: AsyncSession, department: str | None = None) -> list[Routine]:
    stmt = select(Routine).order_by(Routine.department, Routine.published_at.desc())
    if department:
        stmt = stmt.where(Routine.department == department.lower())
    return list((await session.scalars(stmt)).all())
