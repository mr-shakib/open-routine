"""Synthetic routine data, in the shape the real PDF produces.

The published routine PDF is university material and is not redistributed here,
so tests run against rows constructed to match its structure exactly: 18 columns
(six slots x Room/Course/Teacher), day-header rows that can appear in any
column, a repeated sub-header, room cells carrying their type on a second line,
and every course-code shape the real document contains.

A test against a real PDF is available too -- see ``OPEN_ROUTINE_TEST_PDF`` in
``tests/integration/test_real_pdf.py``.
"""

from __future__ import annotations

from open_routine.ingestion.lattice import SLOTS

#: The slot header row: a label in every third column.
SLOT_HEADER: list[str] = [SLOTS[i // 3] if i % 3 == 0 else "" for i in range(18)]

#: The sub-header repeated under it on every page.
SUB_HEADER: list[str] = ["Room", "Course", "Teacher"] * 6


def day_row(day: str, column: int = 0) -> list[str]:
    """A day-header row, with the label in an arbitrary column.

    The real document does not put it in a fixed place, so the reader must find
    it wherever it lands.
    """
    row = [""] * 18
    row[column] = day.upper()
    return row


def data_row(room: str, cells: dict[int, tuple[str, str]]) -> list[str]:
    """One routine row: the room repeats in all six slot columns.

    ``cells`` maps slot index to ``(course, teacher)``; omitted slots are free.
    """
    row: list[str] = []
    for slot in range(6):
        course, teacher = cells.get(slot, ("", ""))
        row += [room, course, teacher]
    return row


#: Rows covering every shape the real Summer-2026 document contains.
SAMPLE_TABLE: list[list[str]] = [
    ["Class Routine for CSE Program"] + [""] * 17,
    ["Version V5"] + [""] * 17,
    ["Effective From: Saturday 11 July, 2026 Prepared by: Class Routine Committee"] + [""] * 17,
    day_row("SATURDAY"),
    SLOT_HEADER,
    SUB_HEADER,
    data_row("KT-201", {1: ("CSE315(66_E)", "AS"), 2: ("CSE321(66_C)", "FNN")}),
    data_row("KT-208", {0: ("PHY101(71_B)", "MAK"), 5: ("CSE213(RE_A(3C))", "NAE")}),
    # A lab: the room carries its type on a second line, and the class spans
    # two consecutive slots.
    data_row("KT-503\n(COM LAB)", {0: ("CSE322(66_B1)", "AAM"), 1: ("CSE322(66_B1)", "AAM")}),
    data_row("G1-020\n(Physics Lab)", {2: ("PHY102(70_J)", "MRI")}),
    # Retake shapes, a teacher initial with a numeric suffix, and a room held
    # back rather than taught in.
    data_row("G1-004\n(COM LAB)", {3: ("CSE124(RE_A1(1.5C))", "ZZM")}),
    data_row("G1-001\n(COM LAB)", {4: ("CSE324(RE_A(3C))", "NT_2")}),
    data_row("G1-022\n(COM LAB)", {0: ("Reserved", "Reserved")}),
    # A typo that exists in the published document: the opening bracket is gone.
    data_row("G1-026", {1: ("CSE47164_P)", "GR")}),
    # A cell that is genuinely unusable and must be reported, not dropped.
    data_row("KT-804", {5: ("\\", "")}),
    # The next day starts partway down, with its label in a middle column.
    day_row("SUNDAY", column=6),
    SUB_HEADER,
    data_row("KT-201", {0: ("CSE315(66_E)", "AS")}),
    data_row("KT-503\n(COM LAB)", {1: ("CSE322(66_B2)", "AAM")}),
]
