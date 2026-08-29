from __future__ import annotations

from fastapi import APIRouter

from open_routine.api.deps import DepartmentQuery, SessionDep
from open_routine.ingestion.lattice import DAYS, SLOTS
from open_routine.schemas import ClassSessionOut, RoutineOut, SnapshotResponse
from open_routine.services import room_service, routine_service

router = APIRouter(prefix="/routines", tags=["routines"])


@router.get("", response_model=list[RoutineOut], summary="List routine revisions")
async def list_routines(session: SessionDep, department: str | None = None) -> list[RoutineOut]:
    rows = await routine_service.list_routines(session, department)
    return [RoutineOut.model_validate(r) for r in rows]


@router.get("/current", response_model=RoutineOut, summary="The active revision")
async def current(session: SessionDep, department: DepartmentQuery = "cse") -> RoutineOut:
    """Which revision is live.

    Clients poll this and re-download the snapshot when ``version`` changes.
    """
    return RoutineOut.model_validate(await routine_service.get_active_routine(session, department))


@router.get(
    "/{routine_id}/snapshot",
    response_model=SnapshotResponse,
    summary="Download an entire routine",
)
async def snapshot(session: SessionDep, routine_id: int) -> SnapshotResponse:
    """The whole routine in one payload.

    This is what makes the client offline-first: it downloads this once, writes
    it to its local database, and answers every query without the network until
    the routine version changes.
    """
    routine = await routine_service.get_routine(session, routine_id)
    await session.refresh(routine, ["sessions"])
    return SnapshotResponse(
        routine=RoutineOut.model_validate(routine),
        slots=list(SLOTS),
        days=list(DAYS),
        rooms=await room_service.all_rooms(session, routine_id),
        sessions=[ClassSessionOut.model_validate(s) for s in routine.sessions],
    )
