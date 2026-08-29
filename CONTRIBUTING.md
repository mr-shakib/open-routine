# Contributing to Open Routine

Thanks for helping out. This project is aimed at DIU students, and contributions from students are especially welcome.

## Before you start

Two facts about the source data explain most of the architecture:

1. **The routine is a fixed 6 x 6 lattice** — six working days (Saturday–Thursday) by six fixed 90-minute slots. Every class occupies exactly one cell. So ingestion is a grid walk, not layout inference.
2. **Because slots are atomic, two classes can never partially overlap.** Occupancy is therefore decided by string equality on the slot label, and no interval arithmetic exists anywhere in the codebase.

Read [backend/README.md](backend/README.md) for the data model and the ingestion contract before changing either.

## Repository layout

```
open-routine/
├── backend/     FastAPI service — ingestion + API      (independent project)
├── app/         Flutter client  — Android + iOS        (independent project)
└── .github/     CI and issue templates
```

`backend/` and `app/` are separate projects with separate toolchains, tests and CI. Work on one without installing the other.

## Setup

**Backend** — Python 3.12+ (3.14 recommended):

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
pytest
uvicorn open_routine.main:app --reload
```

**App** — Flutter 3.35+ (3.44 recommended):

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

## Non-negotiable design rules

These come out of the analysis and exist to prevent real bugs. Changing them needs discussion in an issue first.

1. **`time_slot` is a label, not a time.** It is stored verbatim and compared with `==`. Derived `start`/`end` columns exist for display, sorting and "happening now" — they must **never** become the occupancy test. Interval arithmetic reintroduces every edge case the lattice model avoids.
2. **`course_code` stays fused.** Keep `CSE414(62_E1)` as the source token. Derive `batch` and `section` *alongside* it, never by destroying it.
3. **Ingestion validates loudly.** If the six slot labels don't match, fail the import. Never partially import a routine.
4. **The routine PDF is one continuous table.** Days start partway down a page and flow across page breaks, and the day label lands in an arbitrary column. Never infer the day from the page number.
5. **Offline-first.** Every query must be answerable from the local database with no network. The network only refreshes the snapshot.

## Code style

**Python** — `ruff` (lint + format), `mypy --strict` on `src/`. Type-annotate everything.
**Dart** — `dart format`, `flutter analyze` clean. Follow [Effective Dart](https://dart.dev/effective-dart).

Both run in CI; please run them locally first.

## Tests

- **Ingestion parser changes require a fixture test.** Add the case to `backend/tests/fixtures/rows.py`, which mirrors the real PDF's table shape. Cover the awkward ones: nested brackets in retake codes, unbalanced brackets, `Reserved` holds, lab subsections, teacher initials with numeric suffixes.
- **Validate against a real routine** before trusting a parser change:
  ```bash
  OPEN_ROUTINE_TEST_PDF="CSE Class Routine V5 Summer-2026.pdf" pytest -q
  ```
  The routine PDF is university material and is not committed to this repository.
- Query logic changes need unit tests for the four query types.
- Bug fixes should come with a regression test.

## Commits and PRs

[Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.

Keep PRs focused. Describe what changed and why. Link the issue. If you touched ingestion, say which fixture proves it.

## Reporting a routine parsing bug

The most valuable bug reports. Please include:

- the routine **version** and department
- the batch / teacher / room affected
- what the app showed vs. what the official routine says
- the source file if you can share it

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
