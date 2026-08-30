# Open Routine

**An open-source, offline-first class routine app for Daffodil International University.**

Type your batch — `60_C` — and your week appears. Instantly, offline, with no account required.

---

## What it does

DIU publishes its class routine as one enormous PDF covering every batch, teacher, room and time slot — 2,000 classes across 10 pages. Reading your own five out of it is miserable. Open Routine turns that PDF into four instant queries:

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
DIU routine PDF (published per semester, versioned)
            │
            ▼
   backend/  ·  FastAPI + Python
     ingestion: read PDF tables → parse cells → flat class records
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

The DIU routine is a **fixed 6 × 6 lattice** — six working days (Saturday–Thursday) × six fixed 90-minute slots. Every class occupies exactly one cell. So ingestion is a grid walk, not layout inference; and because slots are atomic, *"is this room busy?"* is answered by **string equality on the slot label**, never by interval arithmetic. That single property is what makes the whole system fast and, more importantly, correct.

The practical consequence: **never replace the slot-label comparison with interval arithmetic.** Storing real start/end times and testing `start < query_end AND end > query_start` looks more general, but it reintroduces an entire class of edge cases that the lattice removes for free. `start_min`/`end_min` exist for display and sorting only.

## Documentation

| Document | What it covers |
|---|---|
| [backend/README.md](backend/README.md) | Running the API, the data model, the ingestion contract |
| [app/README.md](app/README.md) | The Flutter client's architecture and local schema |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to set up, and how to send a change |
| [SECURITY.md](SECURITY.md) | Reporting a vulnerability |

## Contributing

Contributions are welcome, especially from DIU students. See [CONTRIBUTING.md](CONTRIBUTING.md). Good first issues will be tagged once the initial implementation lands.

## Licence

[MIT](LICENSE) — use it, fork it, run your own instance.

Open Routine is not affiliated with or endorsed by Daffodil International University.
