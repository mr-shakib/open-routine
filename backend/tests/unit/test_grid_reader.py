from __future__ import annotations

from pathlib import Path

import pytest

from open_routine.core.errors import IngestionError
from open_routine.ingestion.grid_reader import read_grid


def test_reads_every_populated_cell(workbook: Path) -> None:
    cells = read_grid(workbook)
    assert len(cells) == 12  # every non-blank cell in the fixture


def test_expands_merged_day_blocks(workbook: Path) -> None:
    """The day label is merged down its block; unexpanded, rows lose their day."""
    cells = read_grid(workbook)
    saturday = [c for c in cells if c.day == "Saturday"]
    # Three Saturday rows contribute cells, but only the first carries the label.
    assert len(saturday) == 5
    assert {c.room for c in saturday} == {"KT-503", "KT-515", "G1-007"}


def test_every_cell_lands_on_the_lattice(workbook: Path) -> None:
    from open_routine.ingestion.lattice import DAYS, SLOTS

    for cell in read_grid(workbook):
        assert cell.day in DAYS
        assert cell.time_slot in SLOTS


def test_room_type_survives_the_grid_walk(workbook: Path) -> None:
    cells = read_grid(workbook)
    lab = next(c for c in cells if c.room == "KT-503")
    theory = next(c for c in cells if c.room == "KT-515")
    assert lab.room_type == "Computer Lab"
    assert theory.room_type == "Theory"


def test_rejects_a_sheet_whose_columns_are_not_the_lattice(broken_workbook: Path) -> None:
    """Failing loudly beats importing a routine that is quietly wrong."""
    with pytest.raises(IngestionError) as excinfo:
        read_grid(broken_workbook)
    assert "lattice" in str(excinfo.value).lower()
