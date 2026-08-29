from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class TeacherOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    initial: str = Field(examples=["SRH"])
    name: str
    designation: str | None = None
    department: str | None = None
    office_room: str | None = None
    image_url: str | None = None


class TeacherSuggestion(BaseModel):
    initial: str
    name: str


class AutocompleteResponse(BaseModel):
    query: str
    batches: list[str] = []
    teachers: list[TeacherSuggestion] = []
    rooms: list[str] = []
