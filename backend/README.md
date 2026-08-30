# Open Routine — Backend

FastAPI service. Two jobs: **ingest** the published DIU routine PDF into structured records, and **serve** them to the app.

## Quick start

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"

cp .env.example .env          # then set OPEN_ROUTINE_ADMIN_TOKEN

open-routine init-db
open-routine ingest "CSE Class Routine V5 Summer-2026.pdf"
open-routine load-teachers teachers.json      # optional faculty directory

uvicorn open_routine.main:app --reload
```

Interactive docs at <http://localhost:8000/docs>.

The version and effective date are read from the document's own header
(`Version V5`, `Effective From: Saturday 11 July, 2026`), so nobody retypes them.
Pass `--version` only to override.

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | FastAPI | typed request/response, auto OpenAPI → generated Dart client |
| Validation | Pydantic v2 | the data model *is* the schema |
| ORM | SQLAlchemy 2.0 (async) | mature, typed |
| Migrations | Alembic | routine schemas will evolve |
| PDF | pdfplumber | the routine is published as a PDF with a real text layer and real ruling lines |
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
│   │   ├── cell_parser.py     "CSE322(66_B1)" + "AAM" → fields
│   │   ├── pdf_reader.py      read tables, carry the day across pages
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

    course_code:  str      # "CSE322(66_B1)"   — FUSED, kept intact
    course_title: str | None
    teacher:      str      # "AAM", or "TBA"
    batch:        str      # "66_B"            — derived
    section:      str      # "66_B1"           — derived
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
| `POST` | `/api/v1/admin/teachers` | load the faculty directory |
| `POST` | `/api/v1/admin/routines/{id}/activate` | publish a revision, or roll back |
| `DELETE` | `/api/v1/admin/routines/{id}` | delete a revision that is not live |
| `GET` | `/admin` | the admin console |

`/routines/{id}/snapshot` is what makes the app offline-first: the client downloads it once, writes it to its local database, and answers everything locally until `version` changes.

**No response encryption.** The routine is public data; TLS is the right control. The app we studied AES-encrypts responses with a key it ships to the client, which buys nothing. See [SECURITY.md](../SECURITY.md).

## Ingestion

The department publishes the routine as a **PDF with a real text layer and real
ruling lines** — not a scan — so `pdfplumber` recovers the table directly. **No
OCR is involved.**

```
.pdf → extract tables → validate lattice → parse cells → normalise → atomic swap
```

Three properties of the real document drive the design:

- **It is one continuous table.** A day begins partway down a page and flows across page breaks, so days cannot be inferred from page boundaries — the current day is carried forward until a day-header row changes it. The day label lands in an arbitrary column, so it is searched for rather than assumed.
- **The room repeats in all six slot columns.** A row is six independent `(room, course, teacher)` triples, not one room with six classes.
- **The room cell carries its type on a second line** — `"KT-503\n(COM LAB)"` — which is exactly the artifact the app we studied never strips.

Handling:

- **Validation fails loudly.** If the six slot columns are not found, the import is rejected. A routine that imports with a shifted column is worse than one that refuses to import.
- **Deliberate non-classes are counted separately.** A room marked `Reserved` is information, not a broken cell, so `skipped` keeps meaning "needs a human look".
- **Unparseable cells are reported, not dropped**, with page, day, slot and room.
- **The swap is atomic.** A revision is written to a new `routine_id` and only becomes active once the whole import succeeds.

### Course-code grammar

Every shape below appears in the published Summer-2026 routine:

| Cell | Meaning |
|---|---|
| `CSE315(66_E)` | theory class for section 66_E |
| `CSE322(66_B1)` | lab subsection 1 of section 66_B |
| `CSE213(RE_A(3C))` | retake section A, 3 credits — **nested brackets** |
| `CSE124(RE_A1(1.5C))` | retake, lab subsection, fractional credit |
| `CSE311(RE_B)` | retake, no credit annotation |
| `CSE324(RE_A1(2C)` | **unbalanced** — a typo in the source, still parsed |
| `CSE47164_P)` | **missing bracket** — recovered as `CSE471(64_P)` |

Teacher initials are mostly plain letters but carry disambiguating suffixes
(`NT_2`, `MNT_2`, `NT-1`). A blank teacher becomes `TBA`.

### Verified against the real document

`CSE Class Routine V5 Summer-2026.pdf` (10 pages) ingests as:

```
2002 sessions from 2009 cells · 6 reserved · 1 skipped
Saturday 323 · Sunday 374 · Monday 371 · Tuesday 372 · Wednesday 366 · Thursday 196
72 rooms · 164 batches · 222 teachers · 754 lab sessions
```

The single skipped cell is a stray backslash in the source document.

## Development

```bash
pytest -q                              # 123 tests
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
