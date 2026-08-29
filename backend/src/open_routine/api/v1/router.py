from __future__ import annotations

from fastapi import APIRouter

from open_routine.api.v1.routes import admin, health, meta, rooms, routines, schedule, search

api_router = APIRouter()
for module in (health, routines, schedule, rooms, meta, search, admin):
    api_router.include_router(module.router)
