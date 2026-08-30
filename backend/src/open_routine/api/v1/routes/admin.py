"""Write endpoints. Guarded by a bearer token; disabled when none is configured."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

from fastapi import APIRouter, File, Form, UploadFile

from open_routine.api.deps import AdminDep, SessionDep
from open_routine.core.errors import ValidationError
from open_routine.ingestion import ingest_pdf
from open_routine.ingestion.normalizer import split_name_initial
from open_routine.schemas import IngestionResponse, RoutineOut
from open_routine.services import routine_service, teacher_service

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/ingest", response_model=IngestionResponse, summary="Ingest a routine workbook")
async def ingest(
    session: SessionDep,
    _: AdminDep,
    file: UploadFile = File(description="The published routine PDF."),
    department: str = Form("cse"),
    version: str | None = Form(
        None, description="Routine revision. Read from the PDF header if omitted."
    ),
    semester: str | None = Form(None),
    activate: bool = Form(True),
) -> IngestionResponse:
    """Import a routine revision and make it active.

    The import is all-or-nothing: the new revision only becomes active once every
    cell has been parsed and written, so clients never see a partial routine.

    The version is read from the document's own header unless given explicitly.
    """
    suffix = Path(file.filename or "routine.pdf").suffix or ".pdf"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp_path = Path(tmp.name)
    try:
        report = await ingest_pdf(
            session,
            tmp_path,
            department=department,
            version=version,
            semester=semester,
            activate=activate,
        )
    finally:
        tmp_path.unlink(missing_ok=True)
    return IngestionResponse.model_validate(report.as_dict())


@router.post("/teachers", summary="Load the faculty directory")
async def load_teachers(
    session: SessionDep,
    _: AdminDep,
    file: UploadFile = File(description="Faculty directory JSON."),
) -> dict[str, int]:
    """Replace the faculty directory.

    Accepts either this project's shape (``initial``/``name``) or the
    ``Name_Initial`` shape the university publishes.

    Only what the app displays is stored -- name, designation, department,
    office room and photo. Phone numbers and email addresses present in the
    source file are deliberately dropped rather than served.
    """
    try:
        raw = json.loads((await file.read()).decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValidationError(f"Could not read the directory as JSON: {exc}") from exc

    if not isinstance(raw, list):
        raise ValidationError("Expected a JSON array of faculty records.")

    records: list[dict[str, str | None]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        if "Name_Initial" in item:
            name, initial = split_name_initial(str(item["Name_Initial"]))
            records.append(
                {
                    "initial": initial,
                    "name": name,
                    "designation": item.get("Designation"),
                    "department": item.get("Department"),
                    "office_room": item.get("Assigned Room Number"),
                    "image_url": item.get("Image"),
                }
            )
        else:
            records.append(
                {
                    k: item.get(k)
                    for k in (
                        "initial",
                        "name",
                        "designation",
                        "department",
                        "office_room",
                        "image_url",
                    )
                }
            )

    written = await teacher_service.upsert_teachers(session, records)
    await session.commit()
    return {"received": len(raw), "stored": written}


@router.post(
    "/routines/{routine_id}/activate",
    response_model=RoutineOut,
    summary="Publish a routine revision",
)
async def activate(session: SessionDep, _: AdminDep, routine_id: int) -> RoutineOut:
    """Make this revision the one clients receive.

    Separate from importing on purpose: an import can be inspected first, and a
    bad one simply never gets published. Switching back to an earlier revision
    is the same call, so a rollback is one click rather than a re-upload.
    """
    return RoutineOut.model_validate(await routine_service.activate_routine(session, routine_id))


@router.delete("/routines/{routine_id}", summary="Delete a routine revision")
async def remove(session: SessionDep, _: AdminDep, routine_id: int) -> dict[str, str]:
    """Delete a revision that is not live."""
    await routine_service.delete_routine(session, routine_id)
    return {"status": "deleted"}
