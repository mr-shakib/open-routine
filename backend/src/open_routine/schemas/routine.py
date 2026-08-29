"""Wire models. These define the OpenAPI contract the Flutter client generates from."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ClassSessionOut(BaseModel):
    """One class."""

    model_config = ConfigDict(from_attributes=True)

    day: str = Field(examples=["Sunday"])
    time_slot: str = Field(
        examples=["08:30-10:00"],
        description=(
            "Slot label exactly as published. This is a lattice coordinate and "
            "the key used for occupancy comparisons -- match it with equality, "
            "not by parsing it into times."
        ),
    )
    room: str = Field(examples=["KT-503"])
    room_type: str = Field(examples=["Computer Lab"])
    course_code: str = Field(
        examples=["CSE414(62_E1)"],
        description="The source token, kept fused: course code plus section.",
    )
    course_title: str | None = None
    teacher: str = Field(examples=["SRH"], description='Teacher initial, or "TBA".')
    batch: str = Field(examples=["62_E"])
    section: str = Field(examples=["62_E1"])
    is_lab: bool
    is_optional: bool
    start_min: int = Field(
        examples=[510], description="Minutes past midnight. Display and sorting only."
    )
    end_min: int = Field(examples=[600])


class RoutineOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    department: str
    version: str
    semester: str | None = None
    is_active: bool
    published_at: datetime | None = None
    session_count: int


class ScheduleResponse(BaseModel):
    """A student's or teacher's week."""

    routine: RoutineOut
    query: str
    count: int
    days: dict[str, list[ClassSessionOut]] = Field(
        description="All six working days, in academic-week order. Empty days included."
    )
    teachers: list[str] = Field(
        default_factory=list, description='Initials appearing in this schedule, excluding "TBA".'
    )


class FreeRoomsResponse(BaseModel):
    routine: RoutineOut
    time_slot: str
    rooms_by_day: dict[str, list[str]] = Field(
        description="Free rooms per working day at the requested slot."
    )
    total_rooms: int = Field(description="Size of the room universe for this routine.")


class RoomSearchResponse(BaseModel):
    routine: RoutineOut
    room: str
    day: str
    time_slot: str
    occupied: bool
    sessions: list[ClassSessionOut] = Field(
        default_factory=list,
        description=(
            "Usually zero or one. More than one means the published routine "
            "double-books the room; they are surfaced rather than hidden."
        ),
    )


class SnapshotResponse(BaseModel):
    """The entire routine in one payload.

    This is the client's primary call: it downloads this once, stores it locally,
    and answers every query offline until the routine version changes.
    """

    routine: RoutineOut
    slots: list[str]
    days: list[str]
    rooms: list[str]
    sessions: list[ClassSessionOut]


class LatticeResponse(BaseModel):
    days: list[str]
    slots: list[str]


class IngestionResponse(BaseModel):
    department: str
    version: str
    routine_id: int | None
    cells_read: int
    sessions_created: int
    skipped: int
    skipped_sample: list[dict[str, object]]
