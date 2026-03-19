# Task 01: Migration Foundation

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 02

## Assigned Agent
`dev-db-performance-architect` - Database architect for schema design, migrations, indexes, and constraints

## Agent Invocation
Invoke the `dev-db-performance-architect` agent with instructions to read this task file, `plan.md`, and the referenced migrations before starting implementation.

## Objective
Create the database foundation for Daily Balance Snapshots: add `accounts.timezone`, normalize `postings.amount` precision, and create the `daily_balance_snapshots` table with the approved indexes and constraints.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `priv/repo/migrations/20260307120000_create_accounts.exs`
- [ ] `priv/repo/migrations/20260307203018_create_transactions_and_postings.exs`
- [ ] Existing migration conventions under `priv/repo/migrations/`

## Expected Outputs

- [ ] Migration file altering `accounts` to add `timezone`
- [ ] Migration file altering `postings.amount` to `decimal(20, 4)`
- [ ] Migration file creating `daily_balance_snapshots`
- [ ] DB indexes and constraints matching the approved plan

## Acceptance Criteria

- [ ] `accounts.timezone` is added as non-null
- [ ] Existing account rows are backfilled only for compatibility, with explicit notes that the backfill is not final business semantics
- [ ] New accounts are expected to provide explicit timezone values; the migration does not imply deriving timezone from `entity`
- [ ] `postings.amount` is normalized to `decimal(20, 4)`
- [ ] `daily_balance_snapshots` includes `id`, `account_id`, `entity_id`, `snapshot_date`, `closing_balance`, `daily_delta`, `computed_at`, `projection_version`, timestamps
- [ ] `closing_balance` and `daily_delta` use `decimal(20, 4)`
- [ ] Unique index exists on `[:account_id, :snapshot_date]`
- [ ] Index exists on `[:entity_id, :snapshot_date]`
- [ ] Index exists on `[:snapshot_date]`
- [ ] Migration is reversible or safely expressed in `change/0`

## Technical Notes

### Relevant Code Locations
```text
priv/repo/migrations/                         # Migration naming and style
lib/aurum_finance/ledger/account.ex           # Account schema target
lib/aurum_finance/ledger/posting.ex           # Posting schema target
```

### Patterns to Follow
- Use explicit `:binary_id` FKs
- Use `:utc_datetime_usec` timestamps
- Keep DB enforcement narrow: PKs, FKs, non-null, unique/indexes

### Constraints
- Do not create generalized projection registry tables
- Do not add `account_type` or `currency_code` to `daily_balance_snapshots`
- Do not over-constrain business logic at the DB layer

## Execution Instructions

### For the Agent
1. Read all listed inputs.
2. Create the migration(s) needed for timezone, precision normalization, and `daily_balance_snapshots`.
3. Keep the timezone backfill explicitly marked as legacy compatibility only.
4. Document any migration-risk assumptions in the execution summary.

### For the Human Reviewer
1. Review all column types, precision, and indexes against `plan.md`.
2. Confirm the timezone backfill language is compatibility-only.
3. Approve before Task 02 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [To be filled]

### Outputs Created
- [To be filled]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| [To be filled] | [To be filled] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [To be filled] | [To be filled] | [To be filled] |

### Blockers Encountered
- [To be filled]

### Questions for Human
1. [To be filled]

### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
[YYYY-MM-DD]

### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human notes]

### Git Operations Performed
```bash
# [Commands human executed]
```

