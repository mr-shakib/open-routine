# Open Routine

**An open-source, offline-first class routine app for Daffodil International University.**

Type your batch — `60_C` — and your week appears. Instantly, offline, with no account required.

> ⚠️ **Status: pre-alpha.** No application code has been written yet. The repository currently contains the research and architecture that the implementation will follow. Start with **[docs/HOW_THE_EXISTING_APP_WORKS.md](docs/HOW_THE_EXISTING_APP_WORKS.md)**.

---

## What it does

DIU publishes its class routine as one enormous spreadsheet covering every batch, teacher, room and time slot. Reading your own five classes out of it is miserable. Open Routine turns that spreadsheet into four instant queries:

| View | You give | You get |
|---|---|---|
| **Student** | batch `60_C` | your week: day, course, time, room, teacher |
| **Teacher** | initial `SRH` | their week: day, course, time, room, batch |
| **Empty Slots** | a time slot | which rooms are free, for all six days |
| **Room Search** | room + day + time | which class is in there, and whose |

All four are answered from **one dataset**, downloaded once and held on your device.

## Why it exists

There is an existing app that does this well. It is also closed source, wraps a web page in a WebView, is Android-only, and gates features behind a subscription. This project rebuilds the idea as a real native app, in the open, so that students can read it, fix it, fork it, and run it themselves.

## Architecture

```
DIU routine spreadsheet (.xlsx, versioned per semester)
            │
            ▼
   backend/  ·  FastAPI + Python
     ingestion: grid walk → parse cells → flat class records
     API:       typed REST, auto-generated OpenAPI
            │
            │  one snapshot download, cached until the routine version changes
            ▼
   app/  ·  Flutter (Android · iOS)
     local:  SQLite via Drift, indexed for O(1) lookups
     offline-first: every query runs against the local database
```

**Two components, two independent projects:**

| Path | Stack | README |
|---|---|---|
| [`backend/`](backend/) | Python 3.14, FastAPI, SQLAlchemy, Pydantic | [backend/README.md](backend/README.md) |
| [`app/`](app/) | Flutter 3.44, Dart, Drift, Riverpod | [app/README.md](app/README.md) |

## The core idea, in one paragraph

The DIU routine is a **fixed 6 × 6 lattice** — six working days (Saturday–Thursday) × six fixed 90-minute slots. Every class occupies exactly one cell. So ingestion is a grid walk, not layout inference; and because slots are atomic, *"is this room busy?"* is answered by **string equality on the slot label**, never by interval arithmetic. That single property is what makes the whole system fast and, more importantly, correct. The full reasoning is in [the docs](docs/HOW_THE_EXISTING_APP_WORKS.md#-there-is-no-overlap-logic-anywhere).

## Documentation

| Document | What it covers |
|---|---|
| **[How the existing app works](docs/HOW_THE_EXISTING_APP_WORKS.md)** | The problem and the prior art, explained at three levels: plain-English, developer, and expert. **Read this first.** |
| [docs/evidence/](docs/evidence/) | Raw public artifacts the analysis was built on |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to set up, and how to send a change |
| [SECURITY.md](SECURITY.md) | Reporting a vulnerability |

## Contributing

Contributions are welcome, especially from DIU students. See [CONTRIBUTING.md](CONTRIBUTING.md). Good first issues will be tagged once the initial implementation lands.

## Licence

[MIT](LICENSE) — use it, fork it, run your own instance.

Open Routine is not affiliated with or endorsed by Daffodil International University.
