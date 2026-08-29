from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.ingestion.lattice import DAYS
from open_routine.services import room_service, routine_service, schedule_service


async def _routine_id(session: AsyncSession) -> int:
    return (await routine_service.get_active_routine(session, "cse")).id


async def test_student_schedule_returns_only_that_batch(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    rows = await schedule_service.get_student_schedule(ingested, rid, "60_C")
    assert rows
    assert {r.batch for r in rows} == {"60_C"}


async def test_student_schedule_is_case_insensitive(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    upper = await schedule_service.get_student_schedule(ingested, rid, "60_C")
    lower = await schedule_service.get_student_schedule(ingested, rid, "60_c")
    assert len(upper) == len(lower)


async def test_optional_courses_can_be_excluded(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    with_optional = await schedule_service.get_student_schedule(ingested, rid, "61_A")
    without = await schedule_service.get_student_schedule(
        ingested, rid, "61_A", include_optional=False
    )
    assert len(with_optional) == 1
    assert without == []


async def test_teacher_schedule_uses_the_normalised_initial(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    rows = await schedule_service.get_teacher_schedule(ingested, rid, "SRH")
    assert {r.teacher for r in rows} == {"SRH"}
    assert len(rows) == 4


async def test_schedule_is_sorted_by_academic_week_then_time(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    rows = await schedule_service.get_student_schedule(ingested, rid, "60_C")
    keys = [(DAYS.index(r.day), r.start_min) for r in rows]
    assert keys == sorted(keys)


async def test_group_by_day_includes_empty_days(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    grouped = schedule_service.group_by_day(
        await schedule_service.get_student_schedule(ingested, rid, "62_E")
    )
    assert list(grouped) == list(DAYS)
    assert grouped["Tuesday"] == []


async def test_distinct_teachers_excludes_tba(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    teachers = await schedule_service.distinct_teachers(ingested, rid, "60_C")
    assert "TBA" not in teachers
    assert set(teachers) == {"MAH", "NRC"}


async def test_room_universe_comes_from_the_routine(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    rooms = await room_service.all_rooms(ingested, rid)
    assert rooms == ["G1-007", "KT-503", "KT-515", "KT-801(A)"]


async def test_free_rooms_is_universe_minus_occupied(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    universe = set(await room_service.all_rooms(ingested, rid))
    occupied = await room_service.occupied_rooms(ingested, rid, "Saturday", "08:30-10:00")
    free = await room_service.free_rooms_for_day(ingested, rid, "Saturday", "08:30-10:00")
    assert occupied == {"KT-503", "KT-515"}
    assert set(free) == universe - occupied


async def test_free_rooms_covers_every_working_day(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    by_day = await room_service.free_rooms_all_days(ingested, rid, "08:30-10:00")
    assert list(by_day) == list(DAYS)
    # Nothing is scheduled on Tuesday at this slot, so every room is free.
    assert len(by_day["Tuesday"]) == 4


async def test_room_search_finds_the_occupying_class(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    rows = await room_service.find_in_room(ingested, rid, "KT-503", "Saturday", "08:30-10:00")
    assert len(rows) == 1
    assert rows[0].course_code == "CSE414(62_E1)"


async def test_room_search_returns_nothing_when_free(ingested: AsyncSession) -> None:
    rid = await _routine_id(ingested)
    assert await room_service.find_in_room(ingested, rid, "KT-515", "Tuesday", "08:30-10:00") == []


async def test_occupancy_is_exact_slot_equality_not_overlap(ingested: AsyncSession) -> None:
    """A class in 08:30-10:00 must not register as occupying 10:00-11:30.

    This is the lattice guarantee. If someone ever replaces the equality test
    with interval arithmetic, this test is what catches it.
    """
    rid = await _routine_id(ingested)
    occupied_first = await room_service.occupied_rooms(ingested, rid, "Saturday", "08:30-10:00")
    occupied_second = await room_service.occupied_rooms(ingested, rid, "Saturday", "10:00-11:30")
    assert "KT-515" in occupied_first
    assert "KT-515" not in occupied_second


async def test_split_lab_subsections_occupy_different_rooms(ingested: AsyncSession) -> None:
    """62_E1 and 62_E2 run simultaneously in different rooms; both are real."""
    rid = await _routine_id(ingested)
    rows = await schedule_service.get_student_schedule(ingested, rid, "62_E")
    sections = {r.section for r in rows}
    assert sections == {"62_E1", "62_E2"}
