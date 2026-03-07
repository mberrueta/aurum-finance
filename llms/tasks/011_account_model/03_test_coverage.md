# Task 03: Test Coverage

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01, Task 02
- **Blocks**: Task 04, Task 05

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer. Converts scenarios into ExUnit tests with proper test layers (unit, integration, LiveView, Oban), minimal fixtures, and actionable failures.

## Agent Invocation
Activate the `qa-elixir-test-author` agent with the following prompt:

> Act as `qa-elixir-test-author` following `llms/constitution.md`.
>
> Execute Task 03 from `llms/tasks/011_account_model/03_test_coverage.md`.
>
> Read all inputs listed in the task. Write comprehensive ExUnit tests for the Account model, Ledger context, and AccountsLive LiveView. Follow the existing entities test patterns exactly.

## Objective
Deliver comprehensive test coverage for the Account schema, Ledger context, and AccountsLive LiveView. Tests must cover changeset validations, entity scoping isolation, archive lifecycle, audit event emission, balance derivation placeholder, normal balance helper, and all LiveView CRUD interactions.

## Inputs Required

- [ ] `llms/tasks/011_account_model/plan.md` - Master plan with acceptance criteria mapping and coverage targets
- [ ] `llms/constitution.md` - Test discipline rules (ExUnit, DB sandbox, deterministic, errors_on helper)
- [ ] `llms/project_context.md` - Project conventions
- [ ] `test/aurum_finance/entities_test.exs` - Reference context test pattern (describe blocks, fixtures, changeset tests, archive tests, audit integration tests)
- [ ] `test/aurum_finance_web/live/entities_live_test.exs` - Reference LiveView test pattern (ConnCase, log_in_root, has_element?, form submission, stable DOM IDs)
- [ ] `test/support/data_case.ex` - DataCase with errors_on/1 helper
- [ ] `test/support/conn_case.ex` - ConnCase with log_in_root/1 helper
- [ ] `lib/aurum_finance/ledger.ex` - Context API under test (from Task 01)
- [ ] `lib/aurum_finance/ledger/account.ex` - Schema under test (from Task 01)
- [ ] `lib/aurum_finance_web/live/accounts_live.ex` - LiveView under test (from Task 02)

## Expected Outputs

- [ ] **Context test file**: `test/aurum_finance/ledger_test.exs`
  - Changeset validation tests
  - CRUD operation tests
  - Entity scoping isolation tests
  - Archive/unarchive lifecycle tests
  - Audit event integration tests
  - Balance derivation placeholder test
  - Normal balance helper tests
- [ ] **LiveView test file**: `test/aurum_finance_web/live/accounts_live_test.exs`
  - List view rendering tests
  - Create form submission tests
  - Edit form with immutable field behavior
  - Archive/unarchive from UI
  - Show-archived toggle
  - Tab navigation between institution/category/system sections

## Acceptance Criteria

- [ ] All tests use `async: true` and DB sandbox
- [ ] Tests use `errors_on(changeset)` helper for changeset validation assertions
- [ ] Tests use `ExMachina` factories and `Faker` data instead of ad hoc local fixtures where practical

### Changeset Validation Tests
- [ ] Required fields test: `name`, `account_type`, `currency_code`, `entity_id` are required
- [ ] Valid `account_type` enum values accepted: `asset`, `liability`, `equity`, `income`, `expense`
- [ ] Invalid `account_type` values rejected
- [ ] Valid `operational_subtype` values per account_type accepted
- [ ] Invalid `operational_subtype` for account_type rejected
- [ ] `operational_subtype` required when `account_type` is `asset` or `liability`
- [ ] `operational_subtype` must be nil when `account_type` is `income`, `expense`, or `equity`
- [ ] `currency_code` validates length is exactly 3
- [ ] `currency_code` validates format `^[A-Z]{3}$` (rejects lowercase, numbers, special chars)
- [ ] `name` length validates min 2, max 160
- [ ] Immutability: `account_type` cannot change on update
- [ ] Immutability: `operational_subtype` cannot change on update
- [ ] Immutability: `currency_code` cannot change on update

### Context CRUD Tests
- [ ] `create_account/2` creates account with valid attrs
- [ ] `create_account/2` returns error changeset with invalid attrs
- [ ] `update_account/3` updates mutable fields (name, notes, institution_name, institution_account_ref)
- [ ] `update_account/3` rejects changes to immutable fields
- [ ] `get_account!/1` returns account by id
- [ ] `get_account!/1` raises for non-existent id
- [ ] `change_account/2` returns changeset for form handling

### Entity Scoping Tests
- [ ] Create accounts in Entity A, query from Entity B perspective returns empty
- [ ] `list_accounts(entity_id: entity_a_id)` returns only Entity A accounts
- [ ] `list_accounts(entity_id: entity_b_id)` returns only Entity B accounts
- [ ] No cross-entity data leakage

### Archive Lifecycle Tests
- [ ] `archive_account/2` sets `archived_at` timestamp
- [ ] Archived accounts excluded from `list_accounts/1` by default
- [ ] `list_accounts(entity_id: id, include_archived: true)` includes archived accounts
- [ ] `unarchive_account/2` clears `archived_at` to nil
- [ ] Unarchived account reappears in default list
- [ ] No hard-delete function exists in the Ledger context

### Audit Event Tests
- [ ] Create emits audit event with `entity_type: "account"`, `action: "created"`
- [ ] Update emits audit event with `action: "updated"`, before/after snapshots
- [ ] Archive emits audit event with `action: "archived"`
- [ ] Unarchive emits audit event with `action: "unarchived"`
- [ ] All audit events include `actor`, `channel`, `occurred_at`
- [ ] `institution_account_ref` is `"[REDACTED]"` in audit snapshots

### Balance and Helper Tests
- [ ] `get_account_balance/2` returns `%{}` (empty map)
- [ ] `normal_balance(:asset)` returns `:debit`
- [ ] `normal_balance(:expense)` returns `:debit`
- [ ] `normal_balance(:liability)` returns `:credit`
- [ ] `normal_balance(:equity)` returns `:credit`
- [ ] `normal_balance(:income)` returns `:credit`

### LiveView Tests
- [ ] `/accounts` renders accounts page when authenticated
- [ ] Tab navigation switches between institution/category/system views
- [ ] Creates an institution-backed account from the form
- [ ] Creates a category account (income/expense) from the form
- [ ] Edits an account (mutable fields only)
- [ ] Archives an account from the list
- [ ] Unarchives an account from the archived list
- [ ] Show-archived toggle reveals archived accounts
- [ ] All tests use stable DOM IDs

### Quality Gates
- [ ] `mix test` passes with all new tests green
- [ ] `mix precommit` passes
- [ ] No flaky or timing-dependent tests

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance/entities_test.exs                  # Reference context test pattern
test/aurum_finance_web/live/entities_live_test.exs     # Reference LiveView test pattern
test/support/data_case.ex                              # DataCase with errors_on/1
test/support/conn_case.ex                              # ConnCase with log_in_root/1
lib/aurum_finance/ledger.ex                            # Context under test
lib/aurum_finance/ledger/account.ex                    # Schema under test
lib/aurum_finance_web/live/accounts_live.ex            # LiveView under test
```

### Patterns to Follow

**Context test structure** (from `entities_test.exs`):
- `use AurumFinance.DataCase, async: true`
- `describe` blocks per function/behavior area
- Local `entity_fixture/1` helper using inline attrs merge with unique names
- `errors_on(changeset)` for validation assertions
- Audit event assertions via `Audit.list_audit_events(entity_id: id)`

**LiveView test structure** (from `entities_live_test.exs`):
- `use AurumFinanceWeb.ConnCase, async: true`
- `import Phoenix.LiveViewTest`
- `conn |> log_in_root() |> live("/accounts")` pattern
- `has_element?(view, "#dom-id")` for presence checks
- `element(view, "#dom-id") |> render_click()` for click events
- `form(view, "#form-id", params) |> render_submit()` for form submission

**Factories and test data**:
- Prefer `ExMachina` factories for `Entity` and `Account` over ad hoc local fixtures
- Prefer `Faker` (or ExMachina sequences backed by Faker) for unique names and realistic values
- If temporary local helpers are introduced while bootstrapping tests, Task 03 must replace them with factory-based setup as part of finalizing coverage
- Keep generated values deterministic enough for assertions: use explicit overrides in each test when a specific value matters

### Constraints
- All tests must be deterministic and independent (no ordering dependence)
- Tests must run under DB sandbox
- Use `async: true` for both DataCase and ConnCase tests
- No mocking of the context layer -- use real DB operations
- Entity scoping tests need at least two separate entities to prove isolation

## Execution Instructions

### For the Agent
1. Read all inputs listed above, especially the reference test files
2. Create `test/aurum_finance/ledger_test.exs` with all context-level tests
3. Create `test/aurum_finance_web/live/accounts_live_test.exs` with all LiveView tests
4. Use `describe` blocks to organize test groups logically
5. Ensure entity scoping tests create multiple entities and verify no leakage
6. Replace any temporary local fixtures/helpers with `ExMachina` factories and `Faker`-based data generation
7. Run `mix test` to verify all tests pass
8. Run `mix precommit` to verify quality gates
9. Document all assumptions in "Execution Summary"
10. List any blockers or questions

### For the Human Reviewer
After agent completes:
1. Review test coverage against the acceptance criteria checklist above
2. Verify entity scoping isolation tests are present and meaningful
3. Verify audit event tests check the redaction of `institution_account_ref`
4. Verify immutability tests for account_type, operational_subtype, currency_code
5. Verify LiveView tests use stable DOM IDs from Task 02
6. Run `mix test` locally and check for flaky behavior
7. Run `mix precommit`
8. If approved: mark `[x]` on "Approved" and update plan.md status
9. If rejected: add rejection reason and specific feedback

---

## Execution Summary
The coverage requested by Task 03 was already largely present in the repository. The execution work focused on finalizing the test infrastructure for those files by replacing ad hoc local fixture generation with shared `ExMachina` factories backed by `Faker`, then revalidating the full test and precommit gates.

### Work Performed
- Added a shared `AurumFinance.Factory` with `entity_factory/0` and `account_factory/0`
- Integrated the factory into `DataCase` and `ConnCase`
- Replaced ad hoc local fixture construction in `EntitiesTest`, `LedgerTest`, `EntitiesLiveTest`, and `AccountsLiveTest` with `params_for/1`-based setup from the shared factory
- Kept explicit per-test overrides where assertion values matter
- Re-ran `mix test` and `mix precommit`

### Outputs Created
- `test/support/factory.ex`
- Updates to `test/support/data_case.ex`
- Updates to `test/support/conn_case.ex`
- Updates to `test/aurum_finance/entities_test.exs`
- Updates to `test/aurum_finance/ledger_test.exs`
- Updates to `test/aurum_finance_web/live/entities_live_test.exs`
- Updates to `test/aurum_finance_web/live/accounts_live_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Existing Ledger and AccountsLive coverage already satisfied the behavioral checklist | The current tests already exercised changesets, CRUD, archive lifecycle, audit events, grouping, and LiveView interactions |
| Factory-based param generation is the right level of replacement for these tests | These tests mostly call contexts directly, so `params_for/1` keeps them explicit while removing repetitive local setup |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Use shared ExMachina factories instead of inserting through bespoke helpers everywhere | Keep local inline fixtures, insert structs directly in every test | Shared factories reduce duplication and align the suite with the repository's declared test stack |
| Use `params_for/1` for most context setup instead of `insert/1` | Insert entities/accounts unconditionally | Context tests should still exercise the real create/update APIs rather than bypassing them with direct inserts |

### Blockers Encountered
- Task file status was stale relative to repository state - Resolution: treated Task 03 as coverage-finalization rather than greenfield test authoring and documented that explicitly

### Questions for Human
1. None

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
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
