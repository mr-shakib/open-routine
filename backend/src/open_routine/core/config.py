"""Application settings, loaded from the environment (prefix ``OPEN_ROUTINE_``)."""

from __future__ import annotations

from functools import lru_cache
from typing import Annotated, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="OPEN_ROUTINE_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    project_name: str = "Open Routine"
    environment: Literal["development", "test", "production"] = "development"
    log_level: str = "INFO"

    database_url: str = "sqlite+aiosqlite:///./open_routine.db"
    db_echo: bool = False

    #: NoDecode keeps pydantic-settings from JSON-parsing this before the
    #: validator below runs, so a plain "a,b" or "*" works from the environment.
    cors_origins: Annotated[list[str], NoDecode] = Field(default_factory=lambda: ["*"])

    #: Bearer token guarding write endpoints. Empty disables them entirely,
    #: which is the safe default: a misconfigured deployment cannot be written to.
    admin_token: str = ""

    api_v1_prefix: str = "/api/v1"

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _split_origins(cls, v: object) -> object:
        if isinstance(v, str):
            return [o.strip() for o in v.split(",") if o.strip()]
        return v

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()
