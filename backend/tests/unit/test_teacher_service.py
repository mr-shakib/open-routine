from __future__ import annotations

import logging

from sqlalchemy.ext.asyncio import AsyncSession

from open_routine.services import teacher_service

RECORDS: list[dict[str, str | None]] = [
    {
        "initial": "SRH",
        "name": "Dr. Sheak Rashed Haider Noori",
        "designation": "Professor & Head",
        "department": "CSE",
        "office_room": "KT-205",
        "image_url": "https://example.invalid/srh.jpg",
    },
    {"initial": "MAH", "name": "Someone Else", "designation": "Lecturer"},
]


async def test_upsert_inserts(session: AsyncSession) -> None:
    written = await teacher_service.upsert_teachers(session, RECORDS)
    assert written == 2
    assert len(await teacher_service.list_teachers(session)) == 2


async def test_lookup_is_case_insensitive(session: AsyncSession) -> None:
    await teacher_service.upsert_teachers(session, RECORDS)
    found = await teacher_service.get_teacher(session, "srh")
    assert found is not None
    assert found.name == "Dr. Sheak Rashed Haider Noori"
    assert found.office_room == "KT-205"


async def test_unknown_initial_returns_none(session: AsyncSession) -> None:
    assert await teacher_service.get_teacher(session, "ZZZ") is None


async def test_upsert_updates_rather_than_duplicating(session: AsyncSession) -> None:
    await teacher_service.upsert_teachers(session, RECORDS)
    await teacher_service.upsert_teachers(
        session,
        [{"initial": "SRH", "name": "Dr. Sheak Rashed Haider Noori", "designation": "Dean"}],
    )
    everyone = await teacher_service.list_teachers(session)
    assert len(everyone) == 2
    srh = await teacher_service.get_teacher(session, "SRH")
    assert srh is not None
    assert srh.designation == "Dean"


async def test_colliding_initials_are_warned_about(session: AsyncSession, caplog: object) -> None:
    """The published directory really does contain two people sharing "SAS".

    The routine identifies teachers by initial alone, so this is ambiguous at the
    source. Loading must not silently keep whichever record happened to be last.
    """
    import pytest

    assert isinstance(caplog, pytest.LogCaptureFixture)
    await teacher_service.upsert_teachers(session, [{"initial": "SAS", "name": "First Person"}])
    with caplog.at_level(logging.WARNING):
        await teacher_service.upsert_teachers(
            session, [{"initial": "SAS", "name": "Second Person"}]
        )
    assert "Duplicate teacher initial" in caplog.text
    assert "SAS" in caplog.text


async def test_records_without_an_initial_are_skipped(session: AsyncSession) -> None:
    """One real directory entry has no parseable initial; it must not crash."""
    written = await teacher_service.upsert_teachers(
        session, [{"initial": None, "name": "Mr. Mahmudul Islam Rakib"}]
    )
    assert written == 0
    assert await teacher_service.list_teachers(session) == []


async def test_filter_by_department(session: AsyncSession) -> None:
    await teacher_service.upsert_teachers(session, RECORDS)
    assert len(await teacher_service.list_teachers(session, "cse")) == 1
    assert await teacher_service.list_teachers(session, "bba") == []
