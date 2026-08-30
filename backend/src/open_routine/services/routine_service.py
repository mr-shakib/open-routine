"""Resolving which routine revision a query runs against."""

from __future__ import annotations

from sqlalchemy import delete as sa_delete
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.core.errors import NoActiveRoutineError, NotFoundError, ValidationError
from open_routine.models import ClassSession, Routine


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


async def activate_routine(session: AsyncSession, routine_id: int) -> Routine:
    """Make one revision the live one for its department.

    Publishing is deliberately separate from importing. A routine that parsed
    badly is worse than no new routine at all, so an import can be reviewed
    before anybody's app starts serving it.
    """
    routine = await get_routine(session, routine_id)
    if routine.session_count == 0:
        raise ValidationError(
            "Refusing to publish a routine with no classes in it.",
            detail={"routine_id": routine_id},
        )

    await session.execute(
        update(Routine)
        .where(Routine.department == routine.department, Routine.id != routine.id)
        .values(is_active=False)
    )
    routine.is_active = True
    await session.commit()
    return routine


async def delete_routine(session: AsyncSession, routine_id: int) -> None:
    """Remove a revision and its classes.

    The live revision cannot be deleted: doing so would leave every client
    asking for a routine that no longer exists.
    """
    routine = await get_routine(session, routine_id)
    if routine.is_active:
        raise ValidationError(
            "This revision is live. Publish another one first, then delete it.",
            detail={"routine_id": routine_id},
        )

    await session.execute(sa_delete(ClassSession).where(ClassSession.routine_id == routine.id))
    await session.delete(routine)
    await session.commit()
