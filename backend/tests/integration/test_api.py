from __future__ import annotations

from httpx import AsyncClient

from open_routine.ingestion.lattice import DAYS, SLOTS

API = "/api/v1"


async def test_health(client: AsyncClient) -> None:
    response = await client.get(f"{API}/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


async def test_lattice_is_exposed_as_a_constant(client: AsyncClient) -> None:
    body = (await client.get(f"{API}/meta/lattice")).json()
    assert body["days"] == list(DAYS)
    assert body["slots"] == list(SLOTS)


async def test_current_routine(client: AsyncClient) -> None:
    body = (await client.get(f"{API}/routines/current", params={"department": "cse"})).json()
    assert body["version"] == "5"
    assert body["is_active"] is True
    assert body["session_count"] == 12


async def test_unknown_department_returns_a_clean_error(client: AsyncClient) -> None:
    response = await client.get(f"{API}/routines/current", params={"department": "nope"})
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "no_active_routine"


async def test_student_schedule(client: AsyncClient) -> None:
    body = (await client.get(f"{API}/schedule/student/66_E")).json()
    assert body["query"] == "66_E"
    assert body["count"] == 5
    assert list(body["days"]) == list(DAYS)
    assert sorted(body["teachers"]) == ["AS", "MAH"]


async def test_student_schedule_groups_by_day(client: AsyncClient) -> None:
    days = (await client.get(f"{API}/schedule/student/66_E")).json()["days"]
    assert len(days["Saturday"]) == 1
    assert days["Wednesday"] == []


async def test_student_schedule_can_hide_optional_courses(client: AsyncClient) -> None:
    on = await client.get(f"{API}/schedule/student/61_A")
    off = await client.get(f"{API}/schedule/student/61_A", params={"include_optional": False})
    assert on.json()["count"] == 1
    assert off.json()["count"] == 0


async def test_teacher_schedule(client: AsyncClient) -> None:
    body = (await client.get(f"{API}/schedule/teacher/AAM")).json()
    assert body["count"] == 5
    every = [s for day in body["days"].values() for s in day]
    assert {s["teacher"] for s in every} == {"AAM"}


async def test_course_code_reaches_the_client_fused(client: AsyncClient) -> None:
    body = (await client.get(f"{API}/schedule/teacher/AAM")).json()
    codes = {s["course_code"] for day in body["days"].values() for s in day}
    assert codes == {"CSE322(66_B1)", "CSE322(66_B2)"}


async def test_free_rooms(client: AsyncClient) -> None:
    body = (await client.get(f"{API}/rooms/free", params={"slot": "08:30-10:00"})).json()
    assert body["time_slot"] == "08:30-10:00"
    assert body["total_rooms"] == 4
    assert "KT-503" not in body["rooms_by_day"]["Saturday"]
    assert len(body["rooms_by_day"]["Tuesday"]) == 4


async def test_free_rooms_rejects_a_slot_off_the_lattice(client: AsyncClient) -> None:
    response = await client.get(f"{API}/rooms/free", params={"slot": "09:00-10:00"})
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


async def test_room_search_occupied(client: AsyncClient) -> None:
    body = (
        await client.get(f"{API}/rooms/KT-503", params={"day": "Saturday", "slot": "08:30-10:00"})
    ).json()
    assert body["occupied"] is True
    assert body["sessions"][0]["course_code"] == "CSE322(66_B1)"
    assert body["sessions"][0]["batch"] == "66_B"


async def test_room_search_free(client: AsyncClient) -> None:
    body = (
        await client.get(f"{API}/rooms/KT-515", params={"day": "Tuesday", "slot": "08:30-10:00"})
    ).json()
    assert body["occupied"] is False
    assert body["sessions"] == []


async def test_room_search_rejects_an_unknown_day(client: AsyncClient) -> None:
    response = await client.get(
        f"{API}/rooms/KT-515", params={"day": "Friday", "slot": "08:30-10:00"}
    )
    assert response.status_code == 422


async def test_snapshot_carries_the_whole_routine(client: AsyncClient) -> None:
    """The client downloads this once and then works offline."""
    routine = (await client.get(f"{API}/routines/current")).json()
    body = (await client.get(f"{API}/routines/{routine['id']}/snapshot")).json()
    assert len(body["sessions"]) == 12
    assert body["slots"] == list(SLOTS)
    assert body["days"] == list(DAYS)
    assert len(body["rooms"]) == 4


async def test_autocomplete(client: AsyncClient) -> None:
    body = (await client.get(f"{API}/search/autocomplete", params={"q": "66"})).json()
    assert "66_E" in body["batches"]


async def test_autocomplete_only_suggests_what_exists(client: AsyncClient) -> None:
    body = (await client.get(f"{API}/search/autocomplete", params={"q": "zzz"})).json()
    assert body["batches"] == []
    assert body["teachers"] == []
    assert body["rooms"] == []


async def test_ingest_requires_a_token(client: AsyncClient) -> None:
    response = await client.post(f"{API}/admin/ingest", data={"version": "9.9"})
    assert response.status_code == 401


async def test_openapi_schema_is_generated(client: AsyncClient) -> None:
    """The Flutter client is generated from this document."""
    schema = (await client.get("/openapi.json")).json()
    assert "ClassSessionOut" in schema["components"]["schemas"]
    assert f"{API}/schedule/student/{{batch}}" in schema["paths"]
