"""Validate the reader against an actual published routine.

The routine PDF is university material and is not committed here, so this test
is skipped unless one is provided:

    OPEN_ROUTINE_TEST_PDF="CSE Class Routine V5 Summer-2026.pdf" pytest -q

Run it whenever the department publishes a new revision: a layout change shows
up here first, as a drop in the number of classes or a jump in skipped cells.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from open_routine.ingestion.cell_parser import is_non_class, parse_cell
from open_routine.ingestion.lattice import DAYS, SLOTS
from open_routine.ingestion.pdf_reader import read_pdf

PDF_ENV = "OPEN_ROUTINE_TEST_PDF"
_path = os.environ.get(PDF_ENV)

pytestmark = pytest.mark.skipif(
    not _path or not Path(_path).is_file(),
    reason=f"set {PDF_ENV} to a published routine PDF to run this",
)


@pytest.fixture(scope="module")
def parsed() -> tuple[list[object], object]:
    cells, info = read_pdf(str(_path))
    return cells, info  # type: ignore[return-value]


def test_document_states_its_own_version(parsed: tuple[list, object]) -> None:
    _, info = parsed
    assert info.version, "no version found in the document header"  # type: ignore[attr-defined]


def test_covers_the_whole_working_week(parsed: tuple[list, object]) -> None:
    cells, _ = parsed
    assert {c.day for c in cells} == set(DAYS)


def test_every_cell_lands_on_the_lattice(parsed: tuple[list, object]) -> None:
    cells, _ = parsed
    for cell in cells:
        assert cell.day in DAYS
        assert cell.time_slot in SLOTS


def test_a_real_routine_yields_a_plausible_number_of_classes(
    parsed: tuple[list, object],
) -> None:
    """A whole department's week is thousands of classes, not dozens.

    A layout change that silently halves the import is the failure this catches.
    """
    cells, _ = parsed
    assert len(cells) > 1000


def test_almost_everything_parses(parsed: tuple[list, object]) -> None:
    """Published documents carry a few typos; a wave of failures means drift."""
    cells, _ = parsed
    unparsed = [
        c
        for c in cells
        if not is_non_class(c.course_text) and parse_cell(c.course_text, c.teacher_text) is None
    ]
    ratio = len(unparsed) / max(len(cells), 1)
    assert ratio < 0.01, f"{len(unparsed)}/{len(cells)} cells unparsed: {unparsed[:5]}"


def test_rooms_carry_no_newline_artifacts(parsed: tuple[list, object]) -> None:
    """The app we studied ships room keys with the newline still in them."""
    cells, _ = parsed
    assert all("\n" not in c.room for c in cells)
    assert all("COM LAB" not in c.room for c in cells)


def test_labs_are_detected(parsed: tuple[list, object]) -> None:
    cells, _ = parsed
    labs = [c for c in cells if c.room_type != "Theory"]
    assert labs, "no lab rooms recognised"
