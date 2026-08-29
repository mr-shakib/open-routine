"""Every shape here was taken from the published Summer-2026 routine."""

from __future__ import annotations

import pytest

from open_routine.ingestion.cell_parser import is_non_class, parse_cell, split_section


@pytest.mark.parametrize(
    ("raw", "batch", "subsection"),
    [
        ("66_B1", "66_B", "1"),
        ("66_E", "66_E", None),
        ("RE_A1", "RE_A", "1"),
        ("RE_A", "RE_A", None),
    ],
)
def test_split_section(raw: str, batch: str, subsection: str | None) -> None:
    assert split_section(raw) == (batch, subsection)


def test_split_section_passes_through_unknown_shapes() -> None:
    """An unfamiliar scheme degrades rather than losing the class."""
    assert split_section("WEIRD") == ("WEIRD", None)


class TestRealCourseShapes:
    def test_theory_class(self) -> None:
        parsed = parse_cell("CSE315(66_E)", "AS")
        assert parsed is not None
        assert (parsed.course_code, parsed.batch, parsed.section) == (
            "CSE315(66_E)",
            "66_E",
            "66_E",
        )
        assert parsed.teacher == "AS"
        assert not parsed.is_lab
        assert not parsed.is_retake

    def test_lab_subsection(self) -> None:
        parsed = parse_cell("CSE322(66_B1)", "AAM")
        assert parsed is not None
        assert parsed.batch == "66_B"
        assert parsed.section == "66_B1"
        assert parsed.is_lab

    def test_retake_with_credit(self) -> None:
        """`CSE213(RE_A(3C))` -- nested brackets, which a naive regex splits wrongly."""
        parsed = parse_cell("CSE213(RE_A(3C))", "NAE")
        assert parsed is not None
        assert parsed.course_code == "CSE213(RE_A)"
        assert parsed.batch == "RE_A"
        assert parsed.credit == "3C"
        assert parsed.is_retake

    def test_retake_lab_with_fractional_credit(self) -> None:
        parsed = parse_cell("CSE124(RE_A1(1.5C))", "ZZM")
        assert parsed is not None
        assert parsed.batch == "RE_A"
        assert parsed.section == "RE_A1"
        assert parsed.is_lab
        assert parsed.credit == "1.5C"

    def test_retake_without_credit(self) -> None:
        parsed = parse_cell("CSE311(RE_B)", "FRA")
        assert parsed is not None
        assert parsed.batch == "RE_B"
        assert parsed.credit is None

    def test_stray_full_stop_in_credit(self) -> None:
        parsed = parse_cell("CSE323(RE_A(3C.))", "MTN")
        assert parsed is not None
        assert parsed.batch == "RE_A"

    def test_course_code_stays_fused(self) -> None:
        """The source token survives; batch is derived alongside, not by splitting."""
        parsed = parse_cell("CSE322(66_B1)", "AAM")
        assert parsed is not None
        assert parsed.course_code == "CSE322(66_B1)"

    def test_non_cse_prefixes(self) -> None:
        for code in ("PHY101(71_B)", "MAT102(71_L)", "ENG102(71_C)", "ACT327(66_F)"):
            assert parse_cell(code, "XX") is not None


class TestSourceDefects:
    """Defects that exist in the published document and must not lose data."""

    def test_unbalanced_bracket_still_parses(self) -> None:
        parsed = parse_cell("CSE324(RE_A1(2C)", "NT_2")
        assert parsed is not None
        assert parsed.batch == "RE_A"
        assert parsed.section == "RE_A1"

    def test_missing_opening_bracket_is_recovered(self) -> None:
        """`CSE47164_P)` should read `CSE471(64_P)`; course codes are 3 digits."""
        parsed = parse_cell("CSE47164_P)", "GR")
        assert parsed is not None
        assert parsed.course_code == "CSE471(64_P)"
        assert parsed.batch == "64_P"

    def test_missing_teacher_becomes_tba(self) -> None:
        parsed = parse_cell("CSE426(RE_A(3C)", "")
        assert parsed is not None
        assert parsed.teacher == "TBA"

    def test_genuinely_unusable_cell_yields_nothing(self) -> None:
        assert parse_cell("\\", "") is None


class TestTeacherInitials:
    @pytest.mark.parametrize("initial", ["AS", "AAM", "DMAK", "NT_2", "MNT_2", "NT-1", "EEE_11"])
    def test_real_initials_survive(self, initial: str) -> None:
        parsed = parse_cell("CSE315(66_E)", initial)
        assert parsed is not None
        assert parsed.teacher == initial

    def test_blank_becomes_tba(self) -> None:
        parsed = parse_cell("CSE315(66_E)", "")
        assert parsed is not None
        assert parsed.teacher == "TBA"


class TestNonClassCells:
    @pytest.mark.parametrize("raw", ["", "   ", "-", "--", "N/A", "Reserved", "reserved"])
    def test_recognised_as_deliberate(self, raw: str) -> None:
        """A held room is information, not a parse failure."""
        assert is_non_class(raw)
        assert parse_cell(raw, "") is None

    def test_a_real_course_is_not_non_class(self) -> None:
        assert not is_non_class("CSE315(66_E)")
