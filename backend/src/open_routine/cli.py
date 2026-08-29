"""Command-line entry points for operating the service."""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

from open_routine.core.logging import configure_logging
from open_routine.db.base import Base
from open_routine.db.session import dispose_engine, get_engine, get_sessionmaker
from open_routine.ingestion import ingest_pdf
from open_routine.ingestion.normalizer import split_name_initial
from open_routine.services import teacher_service


async def _create_tables() -> None:
    async with get_engine().begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def _ingest(args: argparse.Namespace) -> int:
    await _create_tables()
    async with get_sessionmaker()() as session:
        report = await ingest_pdf(
            session,
            args.path,
            department=args.department,
            version=args.version,
            semester=args.semester,
            activate=not args.no_activate,
        )
    print(json.dumps(report.as_dict(), indent=2))
    if report.skipped_count:
        print(
            f"\nWarning: {report.skipped_count} cell(s) could not be parsed. "
            "Review the sample above before trusting this import.",
            file=sys.stderr,
        )
    return 0


async def _load_teachers(args: argparse.Namespace) -> int:
    """Load a faculty directory JSON file.

    Accepts either this project's shape (``initial``/``name``) or the
    ``Name_Initial`` shape used by the published DIU directory.
    """
    await _create_tables()
    raw = json.loads(Path(args.path).read_text(encoding="utf-8"))
    records = []
    for item in raw:
        if "Name_Initial" in item:
            name, initial = split_name_initial(item["Name_Initial"])
            records.append(
                {
                    "initial": initial,
                    "name": name,
                    "designation": item.get("Designation"),
                    "department": item.get("Department"),
                    "office_room": item.get("Assigned Room Number"),
                    "image_url": item.get("Image"),
                }
            )
        else:
            records.append(item)

    async with get_sessionmaker()() as session:
        written = await teacher_service.upsert_teachers(session, records)
        await session.commit()
    print(f"Loaded {written} teacher record(s).")
    return 0


async def _init_db(args: argparse.Namespace) -> int:  # noqa: ARG001
    await _create_tables()
    print("Schema created.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="open-routine", description="Open Routine backend tools")
    sub = parser.add_subparsers(dest="command", required=True)

    p_ingest = sub.add_parser("ingest", help="Ingest a published routine PDF")
    p_ingest.add_argument("path", type=Path)
    p_ingest.add_argument("--department", default="cse")
    p_ingest.add_argument(
        "--version",
        default=None,
        help="Routine revision. Read from the document header ('Version V5') if omitted.",
    )
    p_ingest.add_argument("--semester", default=None)
    p_ingest.add_argument(
        "--no-activate", action="store_true", help="Import without making it live"
    )
    p_ingest.set_defaults(func=_ingest)

    p_teachers = sub.add_parser("load-teachers", help="Load a faculty directory JSON")
    p_teachers.add_argument("path", type=Path)
    p_teachers.set_defaults(func=_load_teachers)

    p_init = sub.add_parser("init-db", help="Create the schema")
    p_init.set_defaults(func=_init_db)

    return parser


def main() -> int:
    configure_logging()
    args = build_parser().parse_args()

    async def run() -> int:
        try:
            # argparse.Namespace is untyped, so `args.func` arrives as Any.
            result: int = await args.func(args)
            return result
        finally:
            await dispose_engine()

    exit_code: int = asyncio.run(run())
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
