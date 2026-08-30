"""Publishing is deliberately separate from importing.

A routine that parsed badly is worse than no new routine: every student would
get wrong rooms and times. So an import is staged, inspected, and only then
published — and these tests hold that line.
"""

from __future__ import annotations

from httpx import AsyncClient

API = "/api/v1"
AUTH = {"Authorization": "Bearer test-token"}


async def _routine_id(client: AsyncClient) -> int:
    body = (await client.get(f"{API}/routines/current")).json()
    return int(body["id"])


class TestAuth:
    async def test_activate_needs_a_token(self, client: AsyncClient) -> None:
        assert (await client.post(f"{API}/admin/routines/1/activate")).status_code == 401

    async def test_delete_needs_a_token(self, client: AsyncClient) -> None:
        assert (await client.delete(f"{API}/admin/routines/1")).status_code == 401

    async def test_a_wrong_token_is_refused(self, client: AsyncClient) -> None:
        response = await client.post(
            f"{API}/admin/routines/1/activate",
            headers={"Authorization": "Bearer nope"},
        )
        assert response.status_code == 401


class TestPublishing:
    async def test_publishing_switches_which_routine_is_live(
        self, client: AsyncClient, sessionmaker: object
    ) -> None:
        from tests.fixtures.sessions import seed_routine

        first = await _routine_id(client)
        async with sessionmaker() as s:  # type: ignore[operator]
            second = await seed_routine(s, version="6")
            second.is_active = False
            await s.commit()
            second_id = second.id

        response = await client.post(f"{API}/admin/routines/{second_id}/activate", headers=AUTH)
        assert response.status_code == 200
        assert response.json()["version"] == "6"

        assert (await client.get(f"{API}/routines/current")).json()["id"] == second_id
        assert second_id != first

    async def test_publishing_an_earlier_revision_is_a_rollback(
        self, client: AsyncClient, sessionmaker: object
    ) -> None:
        """Going back is the same call, so recovering from a bad publish is
        one click rather than re-uploading the previous PDF."""
        from tests.fixtures.sessions import seed_routine

        original = await _routine_id(client)
        async with sessionmaker() as s:  # type: ignore[operator]
            newer = await seed_routine(s, version="7")
            newer.is_active = False
            await s.commit()
            newer_id = newer.id

        await client.post(f"{API}/admin/routines/{newer_id}/activate", headers=AUTH)
        assert (await client.get(f"{API}/routines/current")).json()["id"] == newer_id

        await client.post(f"{API}/admin/routines/{original}/activate", headers=AUTH)
        assert (await client.get(f"{API}/routines/current")).json()["id"] == original

    async def test_publishing_something_that_does_not_exist_is_a_clean_404(
        self, client: AsyncClient
    ) -> None:
        response = await client.post(f"{API}/admin/routines/9999/activate", headers=AUTH)
        assert response.status_code == 404
        assert response.json()["error"]["code"] == "not_found"


class TestDeletion:
    async def test_the_live_revision_cannot_be_deleted(self, client: AsyncClient) -> None:
        """Deleting it would leave every client asking for a routine that is gone."""
        live = await _routine_id(client)
        response = await client.delete(f"{API}/admin/routines/{live}", headers=AUTH)
        assert response.status_code == 422
        assert "live" in response.json()["error"]["message"].lower()
        # and it is still being served
        assert (await client.get(f"{API}/routines/current")).json()["id"] == live

    async def test_a_staged_revision_can_be_deleted(
        self, client: AsyncClient, sessionmaker: object
    ) -> None:
        from tests.fixtures.sessions import seed_routine

        async with sessionmaker() as s:  # type: ignore[operator]
            staged = await seed_routine(s, version="8")
            staged.is_active = False
            await s.commit()
            staged_id = staged.id

        assert (
            await client.delete(f"{API}/admin/routines/{staged_id}", headers=AUTH)
        ).status_code == 200
        ids = {r["id"] for r in (await client.get(f"{API}/routines")).json()}
        assert staged_id not in ids


class TestConsole:
    async def test_the_console_is_served_by_the_api(self, client: AsyncClient) -> None:
        """Same origin as the API, so the token never crosses domains."""
        response = await client.get("/admin")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]
        assert "Open Routine" in response.text

    async def test_the_console_is_not_indexable(self, client: AsyncClient) -> None:
        response = await client.get("/admin")
        assert "noindex" in response.headers.get("x-robots-tag", "")
        assert response.headers.get("cache-control") == "no-store"

    async def test_the_console_ships_no_token(self, client: AsyncClient) -> None:
        """It asks for one at runtime; nothing is baked into the page."""
        body = (await client.get("/admin")).text
        assert "test-token" not in body
