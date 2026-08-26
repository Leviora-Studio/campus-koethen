# @campus/openapi

Published contract of the **Campus Köthen API**, generated from the NestJS DTOs.

`AGPL-3.0-only` · Copyright © 2026 Leviora Studio and Jona Loreen Sommer

## Files

| File                   | Purpose                                                    |
| ---------------------- | ---------------------------------------------------------- |
| `openapi.json`         | Generated OpenAPI document — the machine-readable contract |
| `scripts/validate.mjs` | Structural guarantees checked in CI                        |

## Regenerating

```bash
pnpm openapi:generate     # from the repository root
```

The generator boots the real application module, so the document can never
describe an endpoint that does not exist. CI regenerates it and fails if the
committed file differs, which keeps the contract and the implementation from
drifting apart.

## What `validate.mjs` enforces

1. Every endpoint the mobile client depends on is present.
2. The API stays **read-only** — any non-`GET` operation fails the check.
3. No upstream identifier leaks into the public contract:
   `documentId`, `populate`, `localizations`, `image_url`, `location_id`.
   These correspond to real architectural rules — the client must not learn
   Strapi's internal shape, and it must never receive a canteen image URL or an
   upstream `location_id`.
4. The declared licence stays `AGPL-3.0-only`.

## Human-readable contract

See [`docs/api.md`](../../docs/api.md) for the locale contract, the
`channels` parameter semantics and the canteen freshness metadata.
