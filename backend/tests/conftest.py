from __future__ import annotations

import os
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

os.environ.setdefault("OPEN_ROUTINE_ENVIRONMENT", "test")
os.environ.setdefault("OPEN_ROUTINE_ADMIN_TOKEN", "test-token")

from open_routine.core.config import get_settings
from open_routine.db.base import Base
from open_routine.db.session import get_session
from open_routine.main import create_app
from tests.fixtures.sessions import seed_routine


@pytest.fixture(scope="session", autouse=True)
def _settings_cache_clear() -> None:
    get_settings.cache_clear()


@pytest_asyncio.fixture
async def sessionmaker(tmp_path: object) -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    """A fresh SQLite database per test."""
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path}/test.db")  # type: ignore[str-bytes-safe]
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    await engine.dispose()


@pytest_asyncio.fixture
async def session(
    sessionmaker: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncSession]:
    async with sessionmaker() as s:
        yield s


@pytest_asyncio.fixture
async def ingested(session: AsyncSession) -> AsyncSession:
    """A session holding one active routine.

    Seeded directly rather than through the PDF reader: these tests are about
    queries, so parsing is not in scope for them.
    """
    await seed_routine(session)
    return session


@pytest_asyncio.fixture
async def client(
    sessionmaker: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncClient]:
    """An HTTP client wired to a database preloaded with one routine."""
    async with sessionmaker() as s:
        await seed_routine(s)

    app = create_app()

    async def override() -> AsyncIterator[AsyncSession]:
        async with sessionmaker() as s:
            yield s

    app.dependency_overrides[get_session] = override
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
