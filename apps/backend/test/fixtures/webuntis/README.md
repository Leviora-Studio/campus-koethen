# WebUntis fixtures

Recorded from the **public** WebUntis timetable view of Hochschule Anhalt on
**22 July 2026**, then minimised and redacted.

> ⚠️ These capture an **internal, undocumented interface** of the WebUntis web
> UI — not a published, versioned API and not a contract anyone owes us. It can
> change without notice. Treat a parser failure as an upstream change first, and
> re-verify against the live view before assuming a bug in our code.

## Verified request contract

Base: `https://hsa.webuntis.com/WebUntis/api/rest/view/v1`

| Endpoint             | Method | Required parameters                                             | Required headers                                    |
| -------------------- | ------ | --------------------------------------------------------------- | --------------------------------------------------- |
| `/app/data`          | GET    | —                                                               | `anonymous-school: hsa`                             |
| `/timetable/filter`  | GET    | `resourceType=CLASS`                                            | `anonymous-school`, `X-Webuntis-Api-School-Year-Id` |
| `/timetable/entries` | GET    | `start`, `end` (`YYYY-MM-DD`), `format=2`, `resourceType=CLASS` | `anonymous-school`, `X-Webuntis-Api-School-Year-Id` |

Observed behaviour worth knowing:

- A missing required parameter answers **HTTP 500** with a JSON body naming the
  parameter — it is not a 400, so status alone is a poor error signal.
- `/app/data` returns the school year context. The id is **dynamic** and must be
  read at runtime; on the observation date it was `49` (`2026/2026`,
  2026-04-07 → 2026-09-30). It is never hardcoded in this repository.
- `/timetable/entries` **without any resource ids returns every class at once**.
  On the observation date that was 270 classes × 5 days = 1350 day objects in
  ~505 KB, served in ~1.2 s. This is why synchronisation batches the whole
  catalogue in one request per window instead of iterating 270 groups.
- `days[]` is one object per (date, class) pair, each with a `status`
  (`NO_DATA` when the class has nothing that day) and `gridEntries[]`.

### The positional trap

Lesson details live in `position1` … `position7`, and **the index carries no
meaning**. In the recorded sample alone:

| Observed  | Positions it appeared at |
| --------- | ------------------------ |
| `TEACHER` | 1                        |
| `SUBJECT` | 1, 2                     |
| `ROOM`    | 2, 3                     |
| `CLASS`   | 3, 4                     |
| `INFO`    | 1, 2                     |

Parsers must therefore key off `current.type` and never off the position
number. Each item is `{ current, removed }`, where `removed` is populated for
substitutions.

### Observed vocabulary

- `type`: `NORMAL_TEACHING_PERIOD`, `ADDITIONAL_PERIOD`
- `status`: `REGULAR`, `CHANGED`, `CANCELLED`, `ADDITIONAL`
- `statusDetail`: `CONFIRMED`, `TENTATIVE`, `MOVED`, `null`
- `icons`: `NOTES`

This list is **what was seen, not what exists**. Unknown values must map to a
safe fallback rather than fail the import.

`duration.start` / `duration.end` are local wall-clock strings without a zone
(`2026-07-20T10:00`) and are interpreted as `Europe/Berlin`.

`ids[]` is the stable source key. It occasionally holds more than one id.

## Files

| File                       | Purpose                                                                                                                                                             |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app-data.json`            | school year context. Verbatim — the anonymous view returns an all-`null` `user`, so there was nothing to redact                                                     |
| `filter-classes.json`      | class catalogue, trimmed from 270 to 8 classes across 4 departments; all 14 departments kept                                                                        |
| `entries-week.json`        | 10 day objects covering `REGULAR`, `CHANGED`, `CANCELLED` and `ADDITIONAL` three times each, plus a multi-id entry, a `removed` substitution and an `INFO` position |
| `entries-empty.json`       | structurally valid `NO_DATA` days with no entries — a real empty week, not an error                                                                                 |
| `entries-with-errors.json` | synthetic: a populated top-level `errors[]`                                                                                                                         |
| `malformed.json`           | synthetic: truncated, genuinely unparseable JSON                                                                                                                    |
| `login.html`               | synthetic: the HTML page returned instead of JSON when the school context is rejected                                                                               |

## Redaction

The live payload contained **145 distinct real teacher name strings**. Every
`TEACHER` entry — in both `current` and `removed` — was replaced with a
deterministic pseudonym (`D-Demo01` / `Demoperson01` / `Demo Demoperson01`), so
the same source person maps to the same synthetic identity and the relationships
in the fixture stay meaningful.

Verified after generation: zero of those 145 strings occur in any fixture.

Nothing else is personal data. Subjects, rooms, class names and departments are
institutional and are kept verbatim, because the parsers must cope with their
real shape (umlauts, dots, slashes, very long `longName` values).

**No cookies, tokens, session values or request headers were recorded.**

## Rules

- These fixtures are the **only** timetable source the test suite ever touches.
  No test may call the live system — that would make CI depend on a third party
  and put avoidable load on it.
- Re-recording means re-running the redaction and re-verifying it. Never commit
  a raw capture.
