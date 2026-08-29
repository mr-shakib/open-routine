"""Write endpoints. Guarded by a bearer token; disabled when none is configured."""

from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import APIRouter, File, Form, UploadFile

from open_routine.api.deps import AdminDep, SessionDep
from open_routine.ingestion import ingest_pdf
from open_routine.schemas import IngestionResponse

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
