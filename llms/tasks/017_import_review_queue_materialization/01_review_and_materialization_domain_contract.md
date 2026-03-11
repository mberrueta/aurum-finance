# Task 01: Review and Materialization Domain Contract

## Status
- **Status**: COMPLETED
- **Approved**: [x] Human sign-off

## Objective
Define the simplified CSV v1 contract around imported-row evidence, materialization runs, and row-level outcomes.

## Domain Boundary

| Concern | Durable model | Notes |
|---|---|---|
| Imported evidence | `imported_files`, `imported_rows` | Immutable results of parsing and normalization. |
| Materialization run | `import_materializations` | One async request/run for one imported file. |
| Row outcome and traceability | `import_row_materializations` | Durable row-level result plus transaction linkage when committed. |

Removed from the design:

- `import_row_reviews`
- `approved`
- `rejected`
- `force_approved`

## Core Rules
1. `imported_rows` remain immutable evidence.
2. `ready` means the row is eligible by default unless already committed or currency-mismatched.
3. `duplicate` rows are visible but not materializable in v1.
4. `invalid` rows are never materializable.
5. `account.currency_code` is the only source of truth for ledger currency.
6. `imported_row.currency` is evidence only.
7. Currency mismatch must produce a durable row-level `failed` outcome during materialization.

## Eligibility Matrix

| Imported row status | Already committed | Currency matches account | Materializable | Expected run outcome |
|---|---|---|---|---|
| `ready` | no | yes or row currency absent | Yes | `committed` |
| `ready` | no | no | No | `failed` |
| `ready` | yes | any | No | `skipped` |
| `duplicate` | any | any | No | `skipped` |
| `invalid` | any | any | No | `skipped` |

## Materialization Run Contract

### Top-level statuses
- `pending`
- `processing`
- `completed`
- `completed_with_errors`
- `failed`

### Semantics
- `completed`: the run finished and no row ended in `failed`
- `completed_with_errors`: the run finished, but at least one row failed
- `failed`: the run itself failed in a run-wide way and could not finish normally

## Row-Level Outcome Contract

### Allowed statuses
- `committed`
- `skipped`
- `failed`

### Required meanings
- `committed`: transaction was created and linked durably
- `skipped`: row was intentionally not committed, such as `duplicate`, `invalid`, or already committed
- `failed`: row could not be materialized even though the run processed it, including currency mismatch

## Idempotency Contract
1. The same imported row must never be committed twice.
2. Durable uniqueness belongs in `import_row_materializations`.
3. Worker retries must re-check committed state before creating a transaction.
4. Already committed rows must not make the whole run fail.
5. Every evaluated row in a materialization run produces a durable row-level outcome record in `import_row_materializations`, including `skipped`.

## CSV Recovery Contract
If the CSV import itself is wrong, the v1 correction path is:

1. hard delete the `imported_file`
2. hard delete its `imported_rows`
3. re-import the corrected CSV

This is separate from materialization and replaces any need for row-level rejection workflow in CSV v1.

## Decisions Locked By This Task
- No row-level human review overlay.
- No duplicate override path.
- No FX conversion.
- Keep `completed_with_errors`.
- Keep hard delete plus re-import as the CSV correction path.

## Locked Decision
Already committed rows must produce an explicit `skipped` row outcome in reruns. This keeps row-level traceability and UI behavior consistent.
