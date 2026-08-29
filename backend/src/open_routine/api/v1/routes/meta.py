from __future__ import annotations

from fastapi import APIRouter

from open_routine.api.deps import SessionDep
from open_routine.ingestion.lattice import DAYS, SLOTS
from open_routine.schemas import LatticeResponse, TeacherOut
from open_routine.services import teacher_service

router = APIRouter(prefix="/meta", tags=["meta"])


@router.get("/lattice", response_model=LatticeResponse, summary="The routine grid axes")
async def lattice() -> LatticeResponse:
    """The six working days and six time slots every class snaps to.

    These are constants of the routine format, not of any one revision.
    """
    return LatticeResponse(days=list(DAYS), slots=list(SLOTS))


@router.get("/teachers", response_model=list[TeacherOut], summary="Faculty directory")
async def teachers(session: SessionDep, department: str | None = None) -> list[TeacherOut]:
    rows = await teacher_service.list_teachers(session, department)
    return [TeacherOut.model_validate(r) for r in rows]
