"""Shared FastAPI dependencies."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.core.config import Settings, get_settings
from open_routine.core.errors import AuthError, ValidationError
from open_routine.db.session import get_session
from open_routine.ingestion.lattice import DAYS, SLOTS, normalise_day, normalise_slot

SessionDep = Annotated[AsyncSession, Depends(get_session)]
SettingsDep = Annotated[Settings, Depends(get_settings)]

DepartmentQuery = Annotated[
    str, Query(description="Department code, e.g. 'cse'.", examples=["cse"])
]


def valid_day(
    day: Annotated[str, Query(description="Working day.", examples=["Sunday"])],
) -> str:
    resolved = normalise_day(day)
    if resolved is None:
        raise ValidationError(f"Unknown day {day!r}", detail={"allowed": list(DAYS)})
    return resolved


def valid_slot(
    slot: Annotated[
        str, Query(alias="slot", description="Time-slot label.", examples=["08:30-10:00"])
    ],
) -> str:
    resolved = normalise_slot(slot)
    if resolved is None:
        raise ValidationError(f"Unknown time slot {slot!r}", detail={"allowed": list(SLOTS)})
    return resolved


DayDep = Annotated[str, Depends(valid_day)]
SlotDep = Annotated[str, Depends(valid_slot)]


async def require_admin(
    settings: SettingsDep,
    authorization: Annotated[str | None, Header()] = None,
) -> None:
    """Guard write endpoints with a bearer token.

    An unset token disables writes entirely rather than leaving them open, so a
    deployment that forgets to configure one fails closed.
    """
    if not settings.admin_token:
        raise AuthError("Write endpoints are disabled because OPEN_ROUTINE_ADMIN_TOKEN is not set.")
    expected = f"Bearer {settings.admin_token}"
    if not authorization or authorization != expected:
        raise AuthError("A valid admin bearer token is required.")


AdminDep = Annotated[None, Depends(require_admin)]
