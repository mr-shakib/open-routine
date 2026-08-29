# Open Routine — Backend

FastAPI service. Two jobs: **ingest** the DIU routine spreadsheet into structured records, and **serve** them to the app.

> **Status: structure only.** No code yet. This README is the specification the implementation will follow.

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | **FastAPI** | typed request/response, auto OpenAPI → generated Dart client for the app |
| Validation | **Pydantic v2** | the data model *is* the schema |
| ORM | **SQLAlchemy 2.0** (async) | mature, typed |
| Migrations | **Alembic** | routine schemas will evolve |
| Spreadsheet | **openpyxl** | reads `.xlsx` merged-cell ranges, which we need |
| Testing | **pytest** + `httpx.AsyncClient` | |
| Lint / types | **ruff**, **mypy --strict** | |

## Layout

```
backend/
├── pyproject.toml
├── src/open_routine/
│   ├── main.py              app factory, middleware, router mounting
│   ├── core/                config (pydantic-settings), logging, deps
│   ├── db/                  engine, session, base
│   ├── models/              SQLAlchemy tables
│   ├── schemas/             Pydantic request/response models
│   ├── ingestion/           ← the heart. spreadsheet → records
│   │   ├── lattice.py         canonical DAYS and SLOTS + validation
│   │   ├── grid_reader.py     walk cells, expand merged ranges
│   │   ├── cell_parser.py     "CSE414(62_E1)" + "SRH" → fields
│   │   ├── normalizer.py      clean room names, derive start/end
│   │   └── pipeline.py        orchestrate + atomic version swap
│   ├── services/            query logic (student/teacher/free-rooms/room)
│   └── api/v1/routes/       thin HTTP layer over services
├── tests/
│   ├── unit/                parser and service tests
│   ├── integration/         API tests
│   └── fixtures/            small .xlsx files, incl. awkward cases
└── migrations/              alembic
```

**Rule:** routes stay thin. All logic lives in `services/` and `ingestion/` so it is testable without HTTP.

## Data model

One table, indexed three ways. This is the deliberate departure from the app we studied — it wrote every record **twice** (once under a batch key, once under a teacher key) because IndexedDB is a poor query engine. We have real indexes, so we store each record **once**: half the storage, and room search drops from O(n) to O(1).

```python
class ClassSession:
    id:           int
    routine_id:   int      # FK → Routine (department + version)

    day:          str      # "Sunday"          — from the grid row
    time_slot:    str      # "08:30-10:00"     — from the grid column, VERBATIM
    room:         str      # "KT-503"          — normalised
    room_type:    str      # "Theory" | "Computer Lab"

    course_code:  str      # "CSE414(62_E1)"   — FUSED, kept intact
    course_title: str | None
    teacher:      str      # "SRH", or "TBA"
    batch:        str      # "62_E"
    section:      str      # "62_E1"
    is_lab:       bool     # section has a subsection suffix
    is_optional:  bool     # course_code startswith "TCSE"

    start_min:    int      # 510  — derived, for display/sorting ONLY
    end_min:      int      # 600  — never used for occupancy
```

```
INDEX (routine_id, batch)
INDEX (routine_id, teacher)
INDEX (routine_id, room, day, time_slot)   ← makes room search O(1)
```

⚠️ **`time_slot` is the occupancy key and is compared with `==`.** `start_min`/`end_min` are additive, for "happening now" and sorting. They must never become the occupancy test — see [the docs](../docs/HOW_THE_EXISTING_APP_WORKS.md#-there-is-no-overlap-logic-anywhere).

## API

Clean REST resources, replacing the `POST /api/schedule` + `view_mode` switch of the original (and its quirk of stuffing the teacher initial into a field named `batch`).

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/routines/current?department=cse` | active routine version + timestamp |
| `GET` | `/api/v1/routines/{id}/snapshot` | **full dataset in one payload** — the app's primary call |
| `GET` | `/api/v1/schedule/student/{batch}` | student view |
| `GET` | `/api/v1/schedule/teacher/{initial}` | teacher view |
| `GET` | `/api/v1/rooms/free?day=&slot=` | empty slots |
| `GET` | `/api/v1/rooms/{room}?day=&slot=` | room search |
| `GET` | `/api/v1/meta/slots?department=cse` | the six canonical slots |
| `GET` | `/api/v1/meta/teachers` | faculty directory |
| `GET` | `/api/v1/search/autocomplete?q=&type=` | typeahead |

The snapshot endpoint is what makes the app offline-first: the client downloads it whole and answers everything locally. The per-query endpoints exist for web clients and for debugging.

**No response encryption.** The routine is public data; TLS is the right control. See [SECURITY.md](../SECURITY.md).

## Ingestion contract

```
.xlsx  →  validate lattice  →  walk grid  →  parse cells  →  normalise  →  atomic swap
           │                    │             │               │
           │                    │             │               └─ "KT-503\n  (COM LAB)"
           │                    │             │                  → room + room_type
           │                    │             │                  derive start_min/end_min
           │                    │             └─ regex \(([^)]+)\) then ^(\d+_[A-Z])(\d+)?$
           │                    └─ expand MERGED CELLS: one record per covered slot
           └─ the 6 slot labels must match exactly, or FAIL the import
```

A new version is written to a new `routine_id` and only becomes current once the whole import succeeds. Clients see either the old routine or the new one, never a half-imported mix.

## Free-rooms query

The set difference, in one statement:

```sql
SELECT DISTINCT room FROM class_session WHERE routine_id = :rid
EXCEPT
SELECT room FROM class_session
 WHERE routine_id = :rid AND day = :day AND time_slot = :slot;
```

As in the original, the room universe is derived from the routine itself.
