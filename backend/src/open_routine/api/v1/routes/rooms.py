from __future__ import annotations

from fastapi import APIRouter

from open_routine.api.deps import DayDep, DepartmentQuery, SessionDep, SlotDep
from open_routine.schemas import ClassSessionOut, FreeRoomsResponse, RoomSearchResponse, RoutineOut
from open_routine.services import room_service, routine_service

router = APIRouter(prefix="/rooms", tags=["rooms"])


@router.get("/free", response_model=FreeRoomsResponse, summary="Empty rooms at a time slot")
async def free_rooms(
    session: SessionDep,
    slot: SlotDep,
    department: DepartmentQuery = "cse",
) -> FreeRoomsResponse:
    """Which rooms are free at one slot, for every working day.

    ``free = all rooms - occupied rooms``, where occupancy is equality on the
    slot label. The room universe comes from the routine itself, so a room that
    hosts no class is not reported.
    """
    routine = await routine_service.get_active_routine(session, department)
    by_day = await room_service.free_rooms_all_days(session, routine.id, slot)
    return FreeRoomsResponse(
        routine=RoutineOut.model_validate(routine),
        time_slot=slot,
        rooms_by_day=by_day,
        total_rooms=len(await room_service.all_rooms(session, routine.id)),
    )


@router.get("/{room}", response_model=RoomSearchResponse, summary="What is in a room")
async def room_search(
    session: SessionDep,
    room: str,
    day: DayDep,
    slot: SlotDep,
    department: DepartmentQuery = "cse",
) -> RoomSearchResponse:
    """Which class occupies a room on a given day and slot.

    An index seek on ``(routine_id, room, day, time_slot)``. An empty result
    means the room is free.
    """
    routine = await routine_service.get_active_routine(session, department)
    rows = await room_service.find_in_room(session, routine.id, room, day, slot)
    return RoomSearchResponse(
        routine=RoutineOut.model_validate(routine),
        room=room.upper(),
        day=day,
        time_slot=slot,
        occupied=bool(rows),
        sessions=[ClassSessionOut.model_validate(s) for s in rows],
    )
