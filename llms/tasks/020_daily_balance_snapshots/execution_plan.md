# Execution Plan: Daily Balance Snapshots

## Metadata
- **Spec**: `llms/tasks/020_daily_balance_snapshots/plan.md`
- **Created**: 2026-03-18
- **Status**: PLANNING
- **Current Task**: N/A

## Overview

This execution plan turns the approved Daily Balance Snapshots design into a sequential implementation path for the core reporting projection foundation. It keeps the PR focused on the durable base layer only: schema changes, versioned projection logic, async refresh orchestration, ledger event integration, and tests, with the minimal `ReportsLive` rebuild UI treated as optional scope.

## Technical Summary

### Codebase Impact
- **New files**: ~8-12
- **Modified files**: ~6-10
- **Database migrations**: Yes
- **External dependencies**: None

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Precision migration on `postings.amount` affects existing data shape | Medium | High | Isolate migration review, keep scale change explicit, verify with targeted tests |
| Multi-account transactions lose affected accounts in emitted event payloads or subscriber handling | Medium | High | Add dedicated event/subscriber tests covering all affected accounts |
| Rebuild logic accidentally groups by timestamps instead of `transaction.date` | Low | High | Keep business date semantics explicit in engine task and tests |
| `from_date` merge logic grows into hidden complexity | Medium | Medium | Keep task contract simple: prefer oldest known `from_date`, no extra state tables |
| Optional UI expands scope and delays core delivery | Medium | Medium | Keep `ReportsLive` task explicitly optional and sequenced after core + tests |

## Roles

### Human Reviewer
- Approves each task before the next begins
- Executes all git operations (add, commit, push, checkout, stash, revert)
- Final sign-off on completed work
- Can reject or request changes on any task

### Executing Agents

| Task | Agent | Description |
|------|-------|-------------|
| 01 | `dev-db-performance-architect` | Migration review and schema-level DB design |
| 02 | `dev-backend-elixir-engineer` | Ledger schema and factory alignment |
| 03 | `dev-backend-elixir-engineer` | Reporting projection schema and initial V1 module |
| 04 | `dev-backend-elixir-engineer` | Projection engine and versioned rebuild logic |
| 05 | `dev-backend-elixir-engineer` | Reporting context APIs |
| 06 | `dev-backend-elixir-engineer` | Oban worker and enqueue semantics |
| 07 | `dev-backend-elixir-engineer` | Ledger event emission and reporting subscriber integration |
| 08 | `qa-elixir-test-author` | Backend and worker test coverage |
| 09 | `dev-frontend-ui-engineer` | Optional minimal rebuild UI in `ReportsLive` |
| 10 | `audit-pr-elixir` | Final implementation audit |

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Migration foundation | PENDING | [ ] | None |
| 02 | Ledger schema and factory alignment | BLOCKED | [ ] | Task 01 |
| 03 | Reporting projection schema and initial V1 module | BLOCKED | [ ] | Task 02 |
| 04 | Projection engine | BLOCKED | [ ] | Task 03 |
| 05 | Reporting context API | BLOCKED | [ ] | Task 04 |
| 06 | Refresh worker and enqueue path | BLOCKED | [ ] | Task 05 |
| 07 | Ledger event integration | BLOCKED | [ ] | Task 06 |
| 08 | Backend test suite | BLOCKED | [ ] | Task 07 |
| 09 | Optional rebuild UI | BLOCKED | [ ] | Task 08 |
| 10 | Final PR audit | BLOCKED | [ ] | Task 08, Task 09 if Task 09 is implemented |

**Status Legend:**
- `PENDING` - Ready to start
- `IN_PROGRESS` - Currently being executed
- `COMPLETED` - Done and approved
- `BLOCKED` - Waiting on dependency
- `REJECTED` - Needs rework
- `ON_HOLD` - Paused by human

## Assumptions

1. The approved `plan.md` is the authoritative feature spec for this task folder.
2. `AurumFinance.Reporting` does not exist yet and will be introduced in this feature.
3. The migration adding `accounts.timezone` may use a compatibility backfill such as `"Etc/UTC"` for existing rows only, while new accounts must require explicit real timezone input.
4. The implementation should derive `daily_balance_snapshots.entity_id` from the resolved account, not from external input.
5. The PR should intentionally prefer full forward-range replacement over partial diffing.
6. The minimal rebuild UI in `ReportsLive` is optional and should be skipped if it meaningfully expands scope.

## Open Questions

1. None currently blocking Task 01.
2. If the optional `ReportsLive` rebuild control becomes noisy or delays backend completion, the human reviewer should explicitly decide whether to skip Task 09 in this PR.

## Change Log

| Date | Task | Change | Reason |
|------|------|--------|--------|
| 2026-03-18 | Plan | Initial execution plan created | Translate approved spec into sequential implementation tasks |
