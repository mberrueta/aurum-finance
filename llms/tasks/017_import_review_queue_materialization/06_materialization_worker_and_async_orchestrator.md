# Task 06: Materialization Worker and Async Orchestrator

## Status
- **Status**: COMPLETED
- **Approved**: [x] Human sign-off

## Objective
Implement the async worker that processes one materialization run and records durable row outcomes.

## Worker Responsibilities
1. Load the run and validate account/imported-file scope.
2. Move run `pending -> processing`.
3. Evaluate relevant imported rows from durable evidence.
4. Commit eligible rows into the ledger.
5. Persist row-level `committed`, `skipped`, or `failed` outcomes.
6. Finalize the run as `completed`, `completed_with_errors`, or `failed`.

## Row Handling Rules
- `ready` + not committed + currency-safe => attempt commit
- `duplicate` => `skipped`
- `invalid` => `skipped`
- already committed => `skipped`
- currency mismatch => `failed`

## Important Constraints
- No manual duplicate override path
- No review overlay lookup
- No FX conversion
- Use `account.currency_code` as the only posting-currency source of truth

## Partial Failure Policy
- One bad row does not roll back the entire batch by default.
- If some rows fail but the run finishes, set `completed_with_errors`.
- Reserve `failed` for run-wide failures that prevent normal completion.

## Idempotency Expectations
- Re-check committed state before creating transactions
- rely on durable uniqueness in `import_row_materializations`
- make retries safe and non-duplicating
- persist one `import_row_materializations` record for every evaluated row, including `skipped` outcomes
