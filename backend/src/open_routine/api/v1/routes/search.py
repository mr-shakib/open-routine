from __future__ import annotations

from fastapi import APIRouter, Query

from open_routine.api.deps import DepartmentQuery, SessionDep
from open_routine.schemas import AutocompleteResponse, TeacherSuggestion
from open_routine.services import routine_service, search_service

router = APIRouter(prefix="/search", tags=["search"])


@router.get("/autocomplete", response_model=AutocompleteResponse, summary="Typeahead")
async def autocomplete(
    session: SessionDep,
    q: str = Query(min_length=1, description="Partial batch, initial or room."),
    department: DepartmentQuery = "cse",
) -> AutocompleteResponse:
    """Suggest batches, teachers and rooms that exist in the active routine.

    Only values actually present in the routine are suggested, so a suggestion
    can never lead to an empty result.
    """
    routine = await routine_service.get_active_routine(session, department)
    return AutocompleteResponse(
        query=q,
        batches=await search_service.suggest_batches(session, routine.id, q),
        teachers=[
            TeacherSuggestion(**t)
            for t in await search_service.suggest_teachers(session, routine.id, q)
        ],
        rooms=await search_service.suggest_rooms(session, routine.id, q),
    )
