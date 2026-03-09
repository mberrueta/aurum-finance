# Task 04: Audit Backend Tests — Full Coverage for Foundation Changes

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01, Task 02, Task 03
- **Blocks**: Task 05

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer. Converts scenarios into ExUnit tests with proper test layers (unit, integration, LiveView, Oban), minimal fixtures, and actionable failures.

## Agent Invocation
```
Act as a QA-driven Elixir Test Author following llms/constitution.md.

Read and implement Task 04 from llms/tasks/013_audit_trail/04_audit_backend_tests.md

Before starting, read:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/013_audit_trail/plan.md (full spec — especially edge cases and failure semantics sections)
- llms/tasks/013_audit_trail/01_audit_schema_and_migration.md (schema changes)
- llms/tasks/013_audit_trail/02_audit_context_api.md (new API)
- llms/tasks/013_audit_trail/03_audit_query_extensions.md (query extensions)
- This task file in full
```

## Objective
Create comprehensive test coverage for all audit trail foundation changes: schema hardening, new helper API atomicity, caller migration verification, append-only enforcement, and query filter extensions. This corresponds to plan task 9.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` - Edge cases, failure semantics, redaction rules
- [ ] `lib/aurum_finance/audit.ex` - New helper API (after Tasks 01-03)
- [ ] `lib/aurum_finance/audit/audit_event.ex` - Schema with `metadata`, without `updated_at`
- [ ] `lib/aurum_finance/audit/multi.ex` - Multi helper (after Task 02)
- [ ] `lib/aurum_finance/entities.ex` - Migrated callers (after Task 02)
- [ ] `lib/aurum_finance/ledger.ex` - Migrated callers (after Task 02)
- [ ] `test/aurum_finance/entities_test.exs` - Existing test patterns and fixtures
- [ ] `test/aurum_finance/ledger_test.exs` - Existing test patterns and fixtures
- [ ] `test/support/fixtures.ex` - Fixture helpers
- [ ] `test/support/data_case.ex` - DataCase setup
- [ ] `test/support/conn_case.ex` - ConnCase setup (imports Factory + Fixtures)

## Expected Outputs

- [ ] **`test/aurum_finance/audit_test.exs`** - Core audit context tests
- [ ] **`test/aurum_finance/audit/audit_event_test.exs`** - Schema/changeset unit tests

## Acceptance Criteria

### Schema Tests (`audit_event_test.exs`)
- [ ] Valid changeset with all required fields + `metadata`
- [ ] Valid changeset without `metadata` (it is optional)
- [ ] Invalid changeset when required fields are missing
- [ ] `metadata` is cast as a map
- [ ] No `updated_at` field exists on the struct (`refute Map.has_key?(struct, :updated_at)` or equivalent)
- [ ] `entity_type` and `action` length validations (max 120 chars)

### Helper API Tests (`audit_test.exs`)

#### `insert_and_log/2`
- [ ] Creates both the domain record and an audit event in a single transaction
- [ ] Audit event has `action: "created"`, `before: nil`, correct `after` snapshot
- [ ] Redaction is applied to the `after` snapshot (test with a field in `redact_fields`)
- [ ] Returns `{:ok, struct}` on success
- [ ] Returns `{:error, changeset}` when the domain insert fails (invalid changeset)
- [ ] Neither the domain record nor the audit event exists after a domain insert failure

#### `update_and_log/3`
- [ ] Creates both the domain update and an audit event in a single transaction
- [ ] Audit event has correct `before` and `after` snapshots
- [ ] Redaction is applied to both `before` and `after` snapshots
- [ ] Returns `{:ok, struct}` on success
- [ ] Returns `{:error, changeset}` when the domain update fails

#### `archive_and_log/3`
- [ ] Audit event has `action: "archived"`
- [ ] `after` snapshot shows `archived_at` set
- [ ] Works correctly as a semantic wrapper around update logic

#### `Audit.Multi.append_event/4`
- [ ] Appends an audit event step to an existing Multi
- [ ] The audit event is created when the Multi transaction succeeds
- [ ] The audit event is NOT created when a prior Multi step fails (atomicity)
- [ ] The `after` snapshot is derived from the named step's result

### Atomicity Tests
- [ ] When audit insert fails (e.g., missing required field in the audit event), the domain write is rolled back
- [ ] Verify rollback by checking that the domain record does not exist in the database after failure
- [ ] Test the `{:error, {:audit_failed, reason}}` return shape

### DB Immutability Enforcement Tests

#### `audit_events` — append-only
- [ ] Raw SQL `UPDATE audit_events SET ...` raises `Postgrex.Error` matching `~r/append-only/`
- [ ] Raw SQL `DELETE FROM audit_events ...` raises `Postgrex.Error` matching `~r/append-only/`
- [ ] `INSERT` into `audit_events` continues to work normally

#### `postings` — append-only
- [ ] Raw SQL `UPDATE postings SET amount = ... WHERE id = $1` raises `Postgrex.Error` matching `~r/append-only/`
- [ ] Raw SQL `DELETE FROM postings WHERE id = $1` raises `Postgrex.Error` matching `~r/append-only/`
- [ ] `INSERT` into `postings` continues to work normally

#### `transactions` — protected facts
- [ ] Raw SQL `DELETE FROM transactions WHERE id = $1` raises `Postgrex.Error` matching `~r/protected ledger facts/`
- [ ] Raw SQL UPDATE changing `description` raises `Postgrex.Error` matching `~r/immutable/`
- [ ] Raw SQL UPDATE changing `entity_id` raises `Postgrex.Error` matching `~r/immutable/`
- [ ] Raw SQL UPDATE changing `date` raises `Postgrex.Error` matching `~r/immutable/`
- [ ] Raw SQL UPDATE changing `source_type` raises `Postgrex.Error` matching `~r/immutable/`
- [ ] Raw SQL UPDATE setting `voided_at` (NULL → non-NULL) **succeeds** — this is the one allowed lifecycle update
- [ ] Raw SQL UPDATE changing `voided_at` when already non-NULL raises `Postgrex.Error` matching `~r/set-once/`
- [ ] Raw SQL UPDATE setting `correlation_id` on an existing transaction **succeeds** — allowed lifecycle field
- [ ] `INSERT` into `transactions` continues to work normally

### Caller Migration Verification Tests
- [ ] `Entities.create_entity/2` produces an audit event with correct fields
- [ ] `Entities.update_entity/3` produces an audit event with before/after snapshots
- [ ] `Entities.archive_entity/2` produces an audit event with `action: "archived"`
- [ ] `Entities.unarchive_entity/2` produces an audit event with `action: "unarchived"`
- [ ] `Ledger.create_account/2` produces an audit event with redacted `institution_account_ref`
- [ ] `Ledger.create_transaction/2` produces an audit event with `entity_type: "transaction"`
- [ ] `Ledger.void_transaction/2` produces audit events for both the void and the reversal
- [ ] All audit events produced by callers have the correct `actor` and `channel` values

### Query Extension Tests
- [ ] `list_audit_events(occurred_after: datetime)` filters correctly
- [ ] `list_audit_events(occurred_before: datetime)` filters correctly
- [ ] Combined date range filter works
- [ ] `list_audit_events(offset: n)` skips records correctly
- [ ] Offset + limit pagination works correctly
- [ ] `distinct_entity_types/0` returns sorted unique values
- [ ] `distinct_entity_types/0` returns `[]` when no events exist

### General
- [ ] All tests use `async: true` where possible
- [ ] Tests use DB sandbox (via `DataCase`)
- [ ] Tests use existing fixture helpers (`entity_fixture`, `account_fixture`)
- [ ] No debug prints or log noise
- [ ] `mix test` passes with zero warnings
- [ ] `mix precommit` passes

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance/                     # Test directory for context tests
test/aurum_finance/entities_test.exs    # Existing entity tests (reference pattern)
test/aurum_finance/ledger_test.exs      # Existing ledger tests (reference pattern)
test/support/fixtures.ex                # entity_fixture, account_fixture helpers
test/support/data_case.ex               # DataCase with sandbox setup
```

### Patterns to Follow
- Use `describe` blocks to group related tests (see `entities_test.exs` line 8)
- Use `errors_on(changeset)` helper for changeset validation tests (see `entities_test.exs` line 13)
- Use `entity_fixture()` and `account_fixture(entity)` from `test/support/fixtures.ex`
- For append-only tests, use `Ecto.Adapters.SQL.query!/3` to execute raw SQL and catch the Postgres exception

### Testing DB Immutability via Raw SQL

Use `Ecto.Adapters.SQL.query!/3` to bypass Ecto and hit the trigger directly. These tests likely need `async: false` due to sandbox interaction with raw SQL.

```elixir
# audit_events / postings — append-only pattern
assert_raise Postgrex.Error, ~r/append-only/, fn ->
  Ecto.Adapters.SQL.query!(Repo, "UPDATE audit_events SET action = 'tampered' WHERE id = $1", [uuid_bytes])
end

# transactions — protected fact fields
assert_raise Postgrex.Error, ~r/immutable/, fn ->
  Ecto.Adapters.SQL.query!(Repo, "UPDATE transactions SET description = 'tampered' WHERE id = $1", [uuid_bytes])
end

# transactions — allowed lifecycle update (voided_at NULL → non-NULL)
assert {:ok, _} = Ecto.Adapters.SQL.query(Repo, "UPDATE transactions SET voided_at = now() WHERE id = $1", [uuid_bytes])

# transactions — set-once enforcement (voided_at already set)
assert_raise Postgrex.Error, ~r/set-once/, fn ->
  Ecto.Adapters.SQL.query!(Repo, "UPDATE transactions SET voided_at = now() WHERE id = $1", [uuid_bytes])
end
```

### Testing Atomicity
To test that the domain write rolls back when audit fails, you can use Ecto.Multi with a deliberately broken audit event (e.g., nil entity_type) and verify the domain record does not exist afterward.

### Constraints
- Tests must be deterministic -- no timing dependencies
- Use `System.unique_integer([:positive])` for unique names (pattern from `entities_test.exs` line 45)
- Append-only tests may need `async: false` if they interact with triggers at the connection level

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Create `test/aurum_finance/audit/audit_event_test.exs` with schema/changeset tests
3. Create `test/aurum_finance/audit_test.exs` with:
   - Helper API tests (insert_and_log, update_and_log, archive_and_log, Multi.append_event)
   - Atomicity tests
   - Append-only enforcement tests
   - Caller migration verification tests
   - Query extension tests
4. Run `mix test` to verify all tests pass
5. Run `mix precommit`
6. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review test coverage against the acceptance criteria checklist
2. Verify atomicity tests actually test rollback (not just error returns)
3. Verify append-only tests use raw SQL (not Ecto operations that would be blocked at app level anyway)
4. Check for test isolation (no inter-test dependencies)
5. If approved: mark `[x]` on "Approved" and update plan.md status
6. If rejected: add rejection reason and specific feedback

---

## Execution Summary
Completed.

### Work Performed
- Expanded `test/aurum_finance/audit_test.exs` into a full integration suite covering:
  - `insert_and_log/2`, `update_and_log/3`, and `archive_and_log/3`
  - `Audit.Multi.append_event/4`
  - rollback behavior on audit failures
  - raw-SQL immutability checks for `audit_events`, `postings`, and `transactions`
  - query extensions (`occurred_after`, `occurred_before`, `offset`, `distinct_entity_types/0`)
  - legacy API removal and ledger transaction caller audit coverage
- Added `test/aurum_finance/audit/audit_event_test.exs` for schema/changeset coverage around required fields, optional metadata, length validation, and `updated_at` removal.
- Added `test/aurum_finance/audit/multi_test.exs` with direct, exhaustive `Audit.Multi.append_event/4` coverage for insert, update, and archive-style update flows, including pass/fail/audit-fail rollback cases and inferred vs explicit `entity_id`.
- Updated `docs/qa/test_plan.md` with scenario-to-test mappings for the audit trail foundation work.
- Ran targeted audit tests, the full `mix test` suite, and `mix precommit`.

### Outputs Created
- `test/aurum_finance/audit_test.exs`
- `test/aurum_finance/audit/audit_event_test.exs`
- `test/aurum_finance/audit/multi_test.exs`
- `docs/qa/test_plan.md`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Existing audit assertions in `entities_test.exs` and `ledger_test.exs` remain part of Task 04 coverage | The task asks for full backend coverage, and those suites already verify several caller-migration behaviors that did not need to be duplicated again in the new audit-specific files. |
| Raw SQL immutability tests should live in a non-async `DataCase` module | They intentionally bypass Ecto and exercise database triggers directly, which is safer under the sandbox with serialized execution. |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Kept trigger assertions in `audit_test.exs` instead of a separate trigger-only file | Split by DB concern into another integration file | The task’s expected outputs name `audit_test.exs` as the integration suite, and keeping the raw-SQL checks there makes the foundation coverage easier to review in one place. |
| Used per-record / per-action assertions instead of global table counts in helper tests | Assert the whole table is empty after each failure | Fixtures and prior lifecycle events make global counts brittle; checking the specific entity or event stream proves rollback more accurately. |
| Documented coverage mapping in `docs/qa/test_plan.md` instead of duplicating all lifecycle caller tests in the new files | Re-implement every existing entity/account audit assertion inside `audit_test.exs` | The QA agent workflow requires scenario mapping, and the existing tests already cover part of the acceptance matrix well. |

### Blockers Encountered
- `mix coveralls.html` could not be generated because the task is not defined in this repo (`** (Mix) The task "coveralls.html" could not be found`). Resolution: documented as a follow-up gap; all required ExUnit and precommit gates passed.

### Questions for Human
1. Should the repo expose an ExCoveralls task (for example by adding the expected dev/test dependency/task wiring), or should the constitution’s coverage-artifact requirement be waived for now?

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
[YYYY-MM-DD]

### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
