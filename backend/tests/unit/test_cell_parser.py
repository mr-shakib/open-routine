from __future__ import annotations

import pytest

from open_routine.ingestion.cell_parser import parse_cell, split_section


@pytest.mark.parametrize(
    ("raw", "batch", "subsection"),
    [("62_E1", "62_E", "1"), ("62_E", "62_E", None), ("60_C", "60_C", None)],
)
def test_split_section(raw: str, batch: str, subsection: str | None) -> None:
    assert split_section(raw) == (batch, subsection)


def test_split_section_passes_through_unknown_shapes() -> None:
    """An unfamiliar scheme degrades rather than raising."""
    assert split_section("WEIRD") == ("WEIRD", None)


def test_parses_a_theory_class() -> None:
    parsed = parse_cell("CSE332(60_C)\nMAH")
    assert parsed is not None
    assert parsed.course_code == "CSE332(60_C)"
    assert parsed.batch == "60_C"
    assert parsed.section == "60_C"
    assert parsed.teacher == "MAH"
    assert parsed.is_lab is False
    assert parsed.is_optional is False


def test_parses_a_lab_subsection() -> None:
    parsed = parse_cell("CSE414(62_E1)\nSRH")
    assert parsed is not None
    assert parsed.batch == "62_E"
    assert parsed.section == "62_E1"
    assert parsed.is_lab is True


def test_course_code_stays_fused() -> None:
    """The source token is preserved; batch is derived alongside, not by splitting."""
    parsed = parse_cell("CSE414(62_E1) SRH")
    assert parsed is not None
    assert parsed.course_code == "CSE414(62_E1)"


def test_flags_optional_courses() -> None:
    parsed = parse_cell("TCSE412(61_A)\nSAH")
    assert parsed is not None
    assert parsed.is_optional is True


def test_tba_teacher_is_preserved_as_sentinel() -> None:
    parsed = parse_cell("CSE322(60_C)\nTBA")
    assert parsed is not None
    assert parsed.teacher == "TBA"


def test_missing_teacher_defaults_to_tba() -> None:
    parsed = parse_cell("CSE322(60_C)")
    assert parsed is not None
    assert parsed.teacher == "TBA"


def test_room_inside_the_cell_is_extracted_not_mistaken_for_a_teacher() -> None:
    parsed = parse_cell("CSE414(62_E1)\nSRH\nKT-503")
    assert parsed is not None
    assert parsed.teacher == "SRH"
    assert parsed.room_override == "KT-503"


@pytest.mark.parametrize("raw", ["", "   ", "-", "--", "N/A", "\n\n"])
def test_empty_cells_yield_nothing(raw: str) -> None:
    assert parse_cell(raw) is None


def test_text_without_a_course_token_yields_nothing() -> None:
    assert parse_cell("Break") is None
    assert parse_cell("SRH") is None


def test_tolerates_a_space_inside_the_course_code() -> None:
    parsed = parse_cell("CSE 414(62_E1) SRH")
    assert parsed is not None
    assert parsed.course_code == "CSE414(62_E1)"
