"""Application factory."""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from open_routine import __version__
from open_routine.api.v1.router import api_router
from open_routine.core.config import Settings, get_settings
from open_routine.core.errors import register_exception_handlers
from open_routine.core.logging import configure_logging
from open_routine.db.base import Base
from open_routine.db.session import dispose_engine, get_engine

logger = logging.getLogger(__name__)

DESCRIPTION = """
Turns the DIU class routine spreadsheet into structured, queryable data.

The routine is a fixed **6 x 6 lattice** -- six working days by six 90-minute
slots -- and every class occupies exactly one cell. Because slots are atomic,
occupancy is decided by equality on the slot *label*, never by interval
arithmetic.

Clients are expected to call `/routines/current`, and re-download
`/routines/{id}/snapshot` whenever the version changes. Everything else can then
be answered locally, offline.
"""


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:  # noqa: ARG001
    settings = get_settings()
    configure_logging(settings.log_level)
    logger.info("Starting %s %s (%s)", settings.project_name, __version__, settings.environment)

    if not settings.is_production:
        # Convenience for development and tests. Production uses Alembic.
        async with get_engine().begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    yield
    await dispose_engine()


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()

    app = FastAPI(
        title=settings.project_name,
        version=__version__,
        description=DESCRIPTION,
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=False,
            allow_methods=["GET", "POST"],
            allow_headers=["*"],
        )

    register_exception_handlers(app)
    app.include_router(api_router, prefix=settings.api_v1_prefix)

    @app.get("/admin", include_in_schema=False)
    async def admin_console() -> FileResponse:
        """The admin console.

        Served from the API itself rather than the marketing site: same origin,
        so the token never crosses domains and there is no CORS surface, and it
        ships with the API so the two can never drift apart. Every action it
        performs is an ordinary authenticated call to /api/v1/admin.
        """
        return FileResponse(
            Path(__file__).parent / "static" / "admin.html",
            media_type="text/html",
            headers={"Cache-Control": "no-store", "X-Robots-Tag": "noindex, nofollow"},
        )

    @app.get("/", include_in_schema=False)
    async def root() -> dict[str, str]:
        return {
            "name": settings.project_name,
            "version": __version__,
            "docs": "/docs",
            "admin": "/admin",
            "api": settings.api_v1_prefix,
        }

    return app


app = create_app()
