# Open Routine — Backend

FastAPI service. Two jobs: **ingest** the DIU routine spreadsheet into structured records, and **serve** them to the app.

## Quick start

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"

cp .env.example .env          # then set OPEN_ROUTINE_ADMIN_TOKEN

open-routine init-db
open-routine ingest routine.xlsx --department cse --version 5.1
open-routine load-teachers teachers.json      # optional faculty directory

uvicorn open_routine.main:app --reload
```

Interactive docs at <http://localhost:8000/docs>.

No routine file to hand? The test fixture builder makes a valid one:

```bash
python -c "import sys; sys.path.insert(0,'tests'); from pathlib import Path; \
from fixtures.build import build_workbook; build_workbook(Path('sample.xlsx'))"
open-routine ingest sample.xlsx --department cse --version 0.1
```

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | FastAPI | typed request/response, auto OpenAPI → generated Dart client |
| Validation | Pydantic v2 | the data model *is* the schema |
| ORM | SQLAlchemy 2.0 (async) | mature, typed |
| Migrations | Alembic | routine schemas will evolve |
| Spreadsheet | openpyxl | exposes merged-cell ranges, which we need |
| Database | SQLite by default, Postgres optional | the dataset is small; SQLite needs no server |
| Testing | pytest + httpx | |
| Lint / types | ruff, mypy --strict | both clean, enforced in CI |

## Layout

```
backend/
├── pyproject.toml
├── Dockerfile · compose.yaml
├── alembic.ini · migrations/
├── src/open_routine/
│   ├── main.py              app factory, CORS, exception handlers
│   ├── cli.py               ingest · load-teachers · init-db
│   ├── core/                config, logging, domain errors
│   ├── db/                  engine, session, declarative base
│   ├── models/              SQLAlchemy tables
│   ├── schemas/             Pydantic wire models
│   ├── ingestion/           ← the heart
│   │   ├── lattice.py         DAYS, SLOTS, validation, slot_bounds
│   │   ├── cell_parser.py     "CSE414(62_E1)" + "SRH" → fields
│   │   ├── grid_reader.py     walk cells, expand merged ranges
│   │   ├── normalizer.py      clean rooms, split name/initial
│   │   └── pipeline.py        orchestrate + atomic version swap
│   ├── services/            query logic, no HTTP
│   └── api/v1/routes/       thin HTTP layer
└── tests/                   unit · integration · fixtures
```

Routes stay thin; all logic lives in `services/` and `ingestion/` so it is testable without HTTP.

## Data model

One table, indexed four ways. This is the deliberate departure from the app we studied: it wrote every record **twice** (once under a batch key, once under a teacher key) because IndexedDB cannot index arbitrary fields. We have a real database, so each class is stored **once** and the indexes do the work — half the storage, and room search becomes an index seek instead of a linear scan.

```python
class ClassSession:
    routine_id:   int      # FK → Routine (department + version)

    day:          str      # "Sunday"          — grid row
    time_slot:    str      # "08:30-10:00"     — grid column, VERBATIM
    room:         str      # "KT-503"          — normalised
    room_type:    str      # "Theory" | "Computer Lab"

    course_code:  str      # "CSE414(62_E1)"   — FUSED, kept intact
    course_title: str | None
    teacher:      str      # "SRH", or "TBA"
    batch:        str      # "62_E"            — derived
    section:      str      # "62_E1"           — derived
    is_lab:       bool     # section has a subsection suffix
    is_optional:  bool     # course_code starts with "TCSE"

    start_min:    int      # 510  — derived, display/sorting ONLY
    end_min:      int      # 600
```

```
INDEX (routine_id, batch)                    student search
INDEX (routine_id, teacher)                  teacher search
INDEX (routine_id, room, day, time_slot)     room search
INDEX (routine_id, day, time_slot)           empty slots
```

> ⚠️ **`time_slot` is the occupancy key and is compared with `==`.** `start_min`/`end_min` exist for display, sorting and "what is on right now". They must **never** become the occupancy test.

Interval arithmetic (`start < query_end AND end > query_start`) looks more general, but the lattice already guarantees classes cannot partially overlap — so it buys nothing and reintroduces edge cases. `test_occupancy_is_exact_slot_equality_not_overlap` guards this.

## API

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/health` | liveness + database check |
| `GET` | `/api/v1/routines` | all revisions |
| `GET` | `/api/v1/routines/current?department=` | the active revision |
| `GET` | `/api/v1/routines/{id}/snapshot` | **whole routine in one payload** |
| `GET` | `/api/v1/schedule/student/{batch}` | student view |
| `GET` | `/api/v1/schedule/teacher/{initial}` | teacher view |
| `GET` | `/api/v1/rooms/free?slot=` | empty rooms, all six days |
| `GET` | `/api/v1/rooms/{room}?day=&slot=` | room search |
| `GET` | `/api/v1/meta/lattice` | the six days and six slots |
| `GET` | `/api/v1/meta/teachers` | faculty directory |
| `GET` | `/api/v1/search/autocomplete?q=` | typeahead |
| `POST` | `/api/v1/admin/ingest` | upload a routine (bearer token) |

`/routines/{id}/snapshot` is what makes the app offline-first: the client downloads it once, writes it to its local database, and answers everything locally until `version` changes.

**No response encryption.** The routine is public data; TLS is the right control. The app we studied AES-encrypts responses with a key it ships to the client, which buys nothing. See [SECURITY.md](../SECURITY.md).

## Ingestion

```
.xlsx → detect layout → validate lattice → walk grid → parse cells → normalise → atomic swap
```

- **Merged cells are expanded.** A lab spanning two slots, or a day label spanning its block of rows, is one merged cell whose value openpyxl reports only at the top-left corner. Unexpanded, those classes vanish silently — the failure mode most likely to go unnoticed.
- **Validation fails loudly.** If the six slot columns are not found, the import is rejected. A routine that imports with a shifted column is worse than one that refuses to import.
- **Unparseable cells are reported, not dropped.** `IngestionReport.skipped_cells` records each one with its row, column and text.
- **The swap is atomic.** A revision is written to a new `routine_id` and only becomes active once the whole import succeeds.

> ⚠️ **The exact published DIU layout has not been verified against a real file.** The reader expects a day-blocked grid (day column, room column, six slot columns) and locates the axes by inspection. Validate against a real routine before trusting an import in production.

## Development

```bash
pytest -q                              # 86 tests
ruff check src tests && ruff format --check src tests
mypy src                               # strict
alembic upgrade head                   # production schema
docker compose up --build              # containerised
```

In development and test the schema is created automatically at startup. Production uses Alembic.

## Known data quirks

Found while loading the real published faculty directory (221 records):

- one entry has no parseable initial (`Mr. Mahmudul Islam Rakib`) and is skipped;
- two different people share the initial `SAS`.

The routine identifies teachers by initial alone, so a collision is ambiguous **at the source**. `upsert_teachers` logs a warning rather than silently keeping whichever record loaded last.
