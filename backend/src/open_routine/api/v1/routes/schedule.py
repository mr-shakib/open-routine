from __future__ import annotations

from fastapi import APIRouter, Query

from open_routine.api.deps import DepartmentQuery, SessionDep
from open_routine.schemas import ClassSessionOut, RoutineOut, ScheduleResponse
from open_routine.services import routine_service, schedule_service

router = APIRouter(prefix="/schedule", tags=["schedule"])


@router.get(
    "/student/{batch}",
    response_model=ScheduleResponse,
    summary="A batch's weekly schedule",
)
async def student_schedule(
    session: SessionDep,
    batch: str,
    department: DepartmentQuery = "cse",
    include_optional: bool = Query(True, description='Include elective ("TCSE") courses.'),
) -> ScheduleResponse:
    """Every class for one batch, e.g. ``60_C``.

    An index seek on ``(routine_id, batch)``, then grouped into the six working
    days in academic-week order.
    """
    routine = await routine_service.get_active_routine(session, department)
    rows = await schedule_service.get_student_schedule(
        session, routine.id, batch, include_optional=include_optional
    )
    grouped = schedule_service.group_by_day(rows)
    return ScheduleResponse(
        routine=RoutineOut.model_validate(routine),
        query=batch.upper(),
        count=len(rows),
        days={d: [ClassSessionOut.model_validate(s) for s in v] for d, v in grouped.items()},
        teachers=await schedule_service.distinct_teachers(session, routine.id, batch),
    )


@router.get(
    "/teacher/{initial}",
    response_model=ScheduleResponse,
    summary="A teacher's weekly schedule",
)
async def teacher_schedule(
    session: SessionDep,
    initial: str,
    department: DepartmentQuery = "cse",
    include_optional: bool = Query(True, description='Include elective ("TCSE") courses.'),
) -> ScheduleResponse:
    """Every class taught by one initial, e.g. ``SRH``.

    The initial is normalised at ingestion, so this is a direct index seek with
    no name resolution.
    """
    routine = await routine_service.get_active_routine(session, department)
    rows = await schedule_service.get_teacher_schedule(
        session, routine.id, initial, include_optional=include_optional
    )
    grouped = schedule_service.group_by_day(rows)
    return ScheduleResponse(
        routine=RoutineOut.model_validate(routine),
        query=initial.upper(),
        count=len(rows),
        days={d: [ClassSessionOut.model_validate(s) for s in v] for d, v in grouped.items()},
        teachers=[initial.upper()] if rows else [],
    )
