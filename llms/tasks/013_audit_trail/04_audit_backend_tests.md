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

### Append-Only Enforcement Tests
- [ ] Attempting a raw SQL `UPDATE` on `audit_events` raises a database error
- [ ] Attempting a raw SQL `DELETE` on `audit_events` raises a database error
- [ ] `INSERT` operations continue to work normally
- [ ] Test via `Repo.query!("UPDATE audit_events SET action = 'test' WHERE id = $1", [id])` wrapped in a rescue/catch

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

### Testing Append-Only via Raw SQL
```elixir
test "UPDATE on audit_events raises a database error" do
  # First create an audit event
  {:ok, entity} = Entities.create_entity(%{name: "Test", type: :individual, country_code: "US"})
  [event] = Audit.list_audit_events(entity_type: "entity", entity_id: entity.id)

  assert_raise Postgrex.Error, ~r/append-only/, fn ->
    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE audit_events SET action = 'tampered' WHERE id = $1",
      [Ecto.UUID.dump!(event.id)]
    )
  end
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
*[Filled by executing agent after completion]*

### Work Performed
- [What was actually done]

### Outputs Created
- [List of files/artifacts created]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| [Assumption 1] | [Why this was assumed] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [Decision 1] | [Options] | [Why chosen] |

### Blockers Encountered
- [Blocker 1] - Resolution: [How resolved or "Needs human input"]

### Questions for Human
1. [Question needing human input]

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
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
