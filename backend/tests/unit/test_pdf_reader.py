from __future__ import annotations

import pytest

from open_routine.core.errors import IngestionError
from open_routine.ingestion.lattice import SLOTS
from open_routine.ingestion.pdf_reader import _read_header, parse_tables
from tests.fixtures.rows import SAMPLE_TABLE, SLOT_HEADER, data_row, day_row

PAGES = [(1, [SAMPLE_TABLE])]


def test_reads_every_populated_cell() -> None:
    assert len(parse_tables(PAGES)) == 14


def test_day_carries_until_the_next_day_header() -> None:
    """The document is one continuous table; days are not page-aligned."""
    cells = parse_tables(PAGES)
    assert {c.day for c in cells} == {"Saturday", "Sunday"}
    assert len([c for c in cells if c.day == "Sunday"]) == 2


def test_day_header_is_found_in_any_column() -> None:
    """SUNDAY sits in a middle column of the fixture, as it does in the real PDF."""
    assert any(c.day == "Sunday" for c in parse_tables(PAGES))


def test_day_carries_across_page_breaks() -> None:
    """A continuation page repeats no day header, so the previous day continues."""
    page_two = [SLOT_HEADER, data_row("KT-999", {0: ("CSE101(70_A)", "XY")})]
    cells = parse_tables([(1, [SAMPLE_TABLE]), (2, [page_two])])
    carried = [c for c in cells if c.room == "KT-999"]
    assert len(carried) == 1
    assert carried[0].day == "Sunday"  # the last day announced


def test_the_room_repeats_across_slot_columns() -> None:
    """Each row is six independent triples, not one room with six classes."""
    lab = [c for c in parse_tables(PAGES) if c.room == "KT-503" and c.day == "Saturday"]
    assert len(lab) == 2
    assert {c.time_slot for c in lab} == {"08:30-10:00", "10:00-11:30"}


def test_room_type_is_split_off_the_room_name() -> None:
    cells = {c.room: c.room_type for c in parse_tables(PAGES)}
    assert cells["KT-503"] == "Computer Lab"
    assert cells["G1-020"] == "Physics Lab"
    assert cells["KT-201"] == "Theory"


def test_every_cell_lands_on_the_lattice() -> None:
    from open_routine.ingestion.lattice import DAYS

    for cell in parse_tables(PAGES):
        assert cell.day in DAYS
        assert cell.time_slot in SLOTS


def test_repeated_subheader_is_not_mistaken_for_data() -> None:
    """`Room | Course | Teacher` repeats on every page and must be ignored."""
    assert not any(c.course_text == "Course" for c in parse_tables(PAGES))


def test_rejects_a_document_without_the_slot_header() -> None:
    table = [day_row("SATURDAY"), data_row("KT-201", {0: ("CSE101(70_A)", "XY")})]
    with pytest.raises(IngestionError) as excinfo:
        parse_tables([(1, [table])])
    assert "lattice" in str(excinfo.value).lower()


class TestDocumentHeader:
    HEADER = (
        "Class Routine for CSE Program\n"
        "Version V5\n"
        "Effective From: Saturday 11 July, 2026 Prepared by: Class Routine Committee\n"
        "SATURDAY"
    )

    def test_reads_the_version(self) -> None:
        """The document states its own version, so nobody has to retype it."""
        assert _read_header(self.HEADER).version == "5"

    def test_reads_the_effective_date(self) -> None:
        assert _read_header(self.HEADER).effective_from == "Saturday 11 July, 2026"

    def test_reads_the_title(self) -> None:
        assert _read_header(self.HEADER).title == "Class Routine for CSE Program"

    def test_missing_header_is_not_fatal(self) -> None:
        info = _read_header("something else entirely")
        assert info.version is None
        assert info.effective_from is None
