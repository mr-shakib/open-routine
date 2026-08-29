from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import text

from open_routine import __version__
from open_routine.api.deps import SessionDep

router = APIRouter(tags=["health"])


@router.get("/health", summary="Liveness and database check")
async def health(session: SessionDep) -> dict[str, object]:
    await session.execute(text("SELECT 1"))
    return {"status": "ok", "version": __version__}
