from __future__ import annotations

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.core.errors import IngestionError
from open_routine.ingestion.pdf_reader import parse_tables
from open_routine.ingestion.pipeline import IngestionReport, build_sessions
from open_routine.models import ClassSession, Routine
from open_routine.services import routine_service
from tests.fixtures.rows import SAMPLE_TABLE
from tests.fixtures.sessions import seed_routine

CELLS = parse_tables([(1, [SAMPLE_TABLE])])


def _report() -> IngestionReport:
    return IngestionReport(department="cse", version="5")


class TestBuildSessions:
    def test_parses_cells_into_rows(self) -> None:
        report = _report()
        rows = build_sessions(CELLS, report)
        # 14 cells: 12 real classes, one "Reserved" hold, one unusable.
        assert len(rows) == 12
        assert report.skipped_count == 1
        assert report.reserved_cells == 1

    def test_reserved_is_reported_separately_from_failures(self) -> None:
        """A held room is deliberate; only real problems belong in `skipped`."""
        report = _report()
        build_sessions(CELLS, report)
        assert all("Reserved" not in str(s["text"]) for s in report.skipped_cells)

    def test_unparseable_cells_are_reported_not_dropped(self) -> None:
        report = _report()
        build_sessions(CELLS, report)
        assert report.skipped_cells[0]["room"] == "KT-804"
        assert report.skipped_cells[0]["day"] == "Saturday"

    def test_derives_batch_section_and_lab_flag(self) -> None:
        rows = {r["course_code"]: r for r in build_sessions(CELLS, _report())}
        lab = rows["CSE322(66_B1)"]
        assert lab["batch"] == "66_B"
        assert lab["section"] == "66_B1"
        assert lab["is_lab"] is True
        assert lab["room_type"] == "Computer Lab"

    def test_start_and_end_minutes_are_derived(self) -> None:
        for row in build_sessions(CELLS, _report()):
            assert int(str(row["start_min"])) < int(str(row["end_min"]))

    def test_recovers_the_missing_bracket_typo(self) -> None:
        codes = {r["course_code"] for r in build_sessions(CELLS, _report())}
        assert "CSE471(64_P)" in codes


class TestRoutineSwap:
    async def test_seed_creates_an_active_routine(self, session: AsyncSession) -> None:
        await seed_routine(session)
        routine = await routine_service.get_active_routine(session, "cse")
        assert routine.version == "5"
        assert routine.is_active is True

    async def test_only_one_revision_is_active_per_department(self, session: AsyncSession) -> None:
        await seed_routine(session, version="5")
        first = await routine_service.get_active_routine(session, "cse")
        first.is_active = False
        await seed_routine(session, version="6")
        await session.commit()

        active = list(
            (
                await session.scalars(
                    select(Routine).where(Routine.department == "cse", Routine.is_active.is_(True))
                )
            ).all()
        )
        assert [r.version for r in active] == ["6"]

    async def test_sessions_are_linked_to_their_routine(self, session: AsyncSession) -> None:
        routine = await seed_routine(session)
        count = await session.scalar(
            select(func.count())
            .select_from(ClassSession)
            .where(ClassSession.routine_id == routine.id)
        )
        assert count == routine.session_count


class TestValidation:
    def test_a_document_off_the_lattice_is_rejected(self) -> None:
        from tests.fixtures.rows import data_row, day_row

        table = [day_row("SATURDAY"), data_row("KT-201", {0: ("CSE101(70_A)", "XY")})]
        with pytest.raises(IngestionError):
            parse_tables([(1, [table])])
