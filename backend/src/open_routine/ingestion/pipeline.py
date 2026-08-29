"""Turn a routine spreadsheet into rows, and swap it in atomically.

    .xlsx -> validate lattice -> walk grid -> parse cells -> normalise -> swap

The swap is the important part. A new revision is written to a *new* routine row
and only becomes active once the entire import has succeeded, so a client never
observes a half-imported routine.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.core.errors import IngestionError
from open_routine.ingestion.cell_parser import parse_cell
from open_routine.ingestion.grid_reader import RawCell, read_grid
from open_routine.ingestion.lattice import slot_bounds
from open_routine.models import ClassSession, Routine

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class IngestionReport:
    """What an import did, and what it could not make sense of."""

    department: str
    version: str
    cells_read: int = 0
    sessions_created: int = 0
    skipped_cells: list[dict[str, object]] = field(default_factory=list)
    routine_id: int | None = None

    @property
    def skipped_count(self) -> int:
        return len(self.skipped_cells)

    def as_dict(self) -> dict[str, object]:
        return {
            "department": self.department,
            "version": self.version,
            "routine_id": self.routine_id,
            "cells_read": self.cells_read,
            "sessions_created": self.sessions_created,
            "skipped": self.skipped_count,
            # Bounded: a broken sheet must not produce an unbounded response.
            "skipped_sample": self.skipped_cells[:20],
        }


def build_sessions(cells: list[RawCell], report: IngestionReport) -> list[dict[str, object]]:
    """Parse raw cells into session dicts, recording anything unparseable.

    A cell that cannot be parsed is *reported*, not silently dropped: silent
    drops are how a routine ends up quietly missing classes.
    """
    rows: list[dict[str, object]] = []
    for cell in cells:
        parsed = parse_cell(cell.text)
        if parsed is None:
            report.skipped_cells.append(
                {
                    "row": cell.row,
                    "column": cell.column,
                    "day": cell.day,
                    "time_slot": cell.time_slot,
                    "room": cell.room,
                    "text": cell.text[:120],
                }
            )
            continue

        start_min, end_min = slot_bounds(cell.time_slot)
        rows.append(
            {
                "day": cell.day,
                "time_slot": cell.time_slot,
                "room": parsed.room_override or cell.room,
                "room_type": cell.room_type,
                "course_code": parsed.course_code,
                "course_title": None,
                "teacher": parsed.teacher,
                "batch": parsed.batch,
                "section": parsed.section,
                "is_lab": parsed.is_lab,
                "is_optional": parsed.is_optional,
                "start_min": start_min,
                "end_min": end_min,
            }
        )
    return rows


async def ingest_workbook(
    session: AsyncSession,
    path: str | Path,
    *,
    department: str,
    version: str,
    semester: str | None = None,
    sheet: str | None = None,
    activate: bool = True,
) -> IngestionReport:
    """Ingest one routine workbook and, by default, make it the active revision."""
    department = department.strip().lower()
    version = version.strip()
    if not department or not version:
        raise IngestionError("Both a department and a routine version are required")

    report = IngestionReport(department=department, version=version)

    cells = read_grid(path, sheet=sheet)
    report.cells_read = len(cells)
    if not cells:
        raise IngestionError(
            "No populated cells found. The sheet appears to be empty.",
            detail={"path": str(path)},
        )

    rows = build_sessions(cells, report)
    if not rows:
        raise IngestionError(
            "No cell could be parsed into a class. The cell format is probably "
            "not what the parser expects.",
            detail={"cells_read": report.cells_read, "sample": report.skipped_cells[:5]},
        )

    routine = await _replace_routine(
        session,
        department=department,
        version=version,
        semester=semester,
        source_filename=Path(path).name,
        rows=rows,
    )

    if activate:
        await _activate(session, routine)

    await session.commit()

    report.routine_id = routine.id
    report.sessions_created = len(rows)
    logger.info(
        "Ingested %s v%s: %d sessions from %d cells (%d skipped)",
        department,
        version,
        report.sessions_created,
        report.cells_read,
        report.skipped_count,
    )
    return report


async def _replace_routine(
    session: AsyncSession,
    *,
    department: str,
    version: str,
    semester: str | None,
    source_filename: str,
    rows: list[dict[str, object]],
) -> Routine:
    """Create the routine row, replacing any earlier import of the same version."""
    existing = await session.scalar(
        select(Routine).where(Routine.department == department, Routine.version == version)
    )
    if existing is not None:
        # Re-ingesting a version is a correction, so the old rows must go.
        # Deleting them explicitly rather than relying on ON DELETE CASCADE keeps
        # this correct on any backend, including SQLite with foreign keys off.
        await session.execute(delete(ClassSession).where(ClassSession.routine_id == existing.id))
        await session.delete(existing)
        await session.flush()

    routine = Routine(
        department=department,
        version=version,
        semester=semester,
        source_filename=source_filename,
        is_active=False,
        published_at=datetime.now(UTC),
        session_count=len(rows),
    )
    session.add(routine)
    await session.flush()

    session.add_all([ClassSession(routine_id=routine.id, **row) for row in rows])
    await session.flush()
    return routine


async def _activate(session: AsyncSession, routine: Routine) -> None:
    """Make ``routine`` the single active revision for its department."""
    await session.execute(
        update(Routine)
        .where(Routine.department == routine.department, Routine.id != routine.id)
        .values(is_active=False)
    )
    routine.is_active = True
    await session.flush()
