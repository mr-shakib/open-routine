from __future__ import annotations

import pytest

from open_routine.core.errors import IngestionError
from open_routine.ingestion.lattice import (
    DAYS,
    SLOTS,
    normalise_day,
    normalise_slot,
    slot_bounds,
    validate_lattice,
)


def test_lattice_is_six_by_six() -> None:
    assert len(DAYS) == 6
    assert len(SLOTS) == 6
    assert "Friday" not in DAYS  # weekend in Bangladesh


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("sunday", "Sunday"), ("SUN", "Sunday"), (" thu ", "Thursday"), ("Tues", "Tuesday")],
)
def test_normalise_day(raw: str, expected: str) -> None:
    assert normalise_day(raw) == expected


def test_normalise_day_rejects_unknown() -> None:
    assert normalise_day("Someday") is None
    assert normalise_day("") is None


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("08:30-10:00", "08:30-10:00"),
        ("08:30 - 10:00", "08:30-10:00"),
        ("08:30–10:00", "08:30-10:00"),  # noqa: RUF001  -- en dash, on purpose
        ("8:30-10:00", "08:30-10:00"),  # unpadded hour
    ],
)
def test_normalise_slot_tolerates_formatting(raw: str, expected: str) -> None:
    assert normalise_slot(raw) == expected


def test_normalise_slot_never_invents_a_slot() -> None:
    assert normalise_slot("09:00-10:00") is None
    assert normalise_slot("lunch") is None


def test_slot_bounds_resolves_the_midday_crossing() -> None:
    """`11:30-01:00` has no AM/PM marker; hours under 8 are afternoon."""
    assert slot_bounds("08:30-10:00") == (8 * 60 + 30, 10 * 60)
    assert slot_bounds("11:30-01:00") == (11 * 60 + 30, 13 * 60)
    assert slot_bounds("04:00-05:30") == (16 * 60, 17 * 60 + 30)


def test_slot_bounds_are_always_forward() -> None:
    for slot in SLOTS:
        start, end = slot_bounds(slot)
        assert start < end, slot


def test_validate_lattice_accepts_the_full_grid() -> None:
    validate_lattice(list(DAYS), list(SLOTS))


def test_validate_lattice_rejects_missing_columns() -> None:
    with pytest.raises(IngestionError) as excinfo:
        validate_lattice(list(DAYS), list(SLOTS[:4]))
    assert "missing" in str(excinfo.value.detail)


def test_validate_lattice_rejects_unknown_day() -> None:
    with pytest.raises(IngestionError):
        validate_lattice(["Saturday", "Funday"], list(SLOTS))
