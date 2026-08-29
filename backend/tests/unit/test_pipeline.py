from __future__ import annotations

from pathlib import Path

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.core.errors import IngestionError
from open_routine.ingestion import ingest_workbook
from open_routine.models import ClassSession, Routine


async def test_ingest_creates_sessions(session: AsyncSession, workbook: Path) -> None:
    report = await ingest_workbook(session, workbook, department="cse", version="5.1")
    assert report.sessions_created == 12
    assert report.skipped_count == 0

    total = await session.scalar(select(func.count()).select_from(ClassSession))
    assert total == 12


async def test_ingest_activates_the_new_revision(session: AsyncSession, workbook: Path) -> None:
    await ingest_workbook(session, workbook, department="cse", version="5.1")
    routine = await session.scalar(select(Routine).where(Routine.version == "5.1"))
    assert routine is not None
    assert routine.is_active is True


async def test_only_one_revision_is_active_per_department(
    session: AsyncSession, workbook: Path
) -> None:
    await ingest_workbook(session, workbook, department="cse", version="5.1")
    await ingest_workbook(session, workbook, department="cse", version="5.2")

    active = list(
        (
            await session.scalars(
                select(Routine).where(Routine.department == "cse", Routine.is_active.is_(True))
            )
        ).all()
    )
    assert [r.version for r in active] == ["5.2"]


async def test_reingesting_a_version_replaces_it(session: AsyncSession, workbook: Path) -> None:
    await ingest_workbook(session, workbook, department="cse", version="5.1")
    await ingest_workbook(session, workbook, department="cse", version="5.1")

    routines = list((await session.scalars(select(Routine))).all())
    assert len(routines) == 1
    total = await session.scalar(select(func.count()).select_from(ClassSession))
    assert total == 12  # not doubled


async def test_derived_fields_are_populated(session: AsyncSession, workbook: Path) -> None:
    await ingest_workbook(session, workbook, department="cse", version="5.1")
    row = await session.scalar(
        select(ClassSession).where(ClassSession.course_code == "CSE414(62_E1)")
    )
    assert row is not None
    assert row.batch == "62_E"
    assert row.section == "62_E1"
    assert row.is_lab is True
    assert row.room_type == "Computer Lab"
    assert row.start_min < row.end_min


async def test_broken_sheet_is_rejected(session: AsyncSession, broken_workbook: Path) -> None:
    with pytest.raises(IngestionError):
        await ingest_workbook(session, broken_workbook, department="cse", version="1.0")


async def test_ingest_requires_department_and_version(
    session: AsyncSession, workbook: Path
) -> None:
    with pytest.raises(IngestionError):
        await ingest_workbook(session, workbook, department="", version="5.1")
