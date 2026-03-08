# Task 03: Test Coverage

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 01 and 02 (LiveView tests require Task 02 to be complete)
- **Blocks**: Task 04

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer. Converts scenarios into ExUnit tests with proper test layers (unit, integration), minimal fixtures, and actionable failures.

## Agent Invocation
Activate the `qa-elixir-test-author` agent with the following prompt:

> Act as `qa-elixir-test-author` following `llms/constitution.md`.
>
> Execute Task 03 from `llms/tasks/012_ledger_primitives/03_test_coverage.md`.
>
> Read all inputs listed in the task. Write comprehensive ExUnit tests for the Transaction and Posting schemas, the Ledger context transaction APIs, the zero-sum invariant, balance derivation, void workflow (using `voided_at`), entity scoping, the database trigger, and the read-only Transactions LiveView. Key constraint: transactions have no `memo`, no `status` enum, no `updated_at` — use `voided_at` for void state throughout. Follow existing test patterns from `test/aurum_finance/ledger_test.exs`. Do NOT modify `plan.md`.

## Objective
Write comprehensive ExUnit test coverage for the Transaction/Posting schemas, all new `AurumFinance.Ledger` context functions (`create_transaction/2`, `get_transaction!/2`, `list_transactions/1`, `void_transaction/2`, and the updated `get_account_balance/2`), the zero-sum invariant (application and database levels), entity scoping isolation, the void workflow, and the read-only Transactions LiveView. Tests must cover all user stories (US-1 through US-10), acceptance criteria, and edge cases defined in the plan.

Key constraints to test: no `memo` field, no `status` enum, no `updated_at` on either table; `voided_at` is the void marker; no `currency_code`/`entity_id` on postings.

## Inputs Required

- [ ] `llms/tasks/012_ledger_primitives/plan.md` - Master plan with user stories, acceptance criteria, edge cases, and full test coverage targets
- [ ] `llms/tasks/012_ledger_primitives/01_domain_data_model_foundation.md` - Task 01 deliverables and implementation decisions
- [ ] `llms/constitution.md` - Test discipline rules (ExUnit, DB sandbox, deterministic, describe blocks)
- [ ] `llms/project_context.md` - Project conventions
- [ ] `lib/aurum_finance/ledger.ex` - Context implementation (source of truth for API signatures)
- [ ] `lib/aurum_finance/ledger/transaction.ex` - Transaction schema (from Task 01)
- [ ] `lib/aurum_finance/ledger/posting.ex` - Posting schema (from Task 01)
- [ ] `lib/aurum_finance/ledger/account.ex` - Account schema (for test setup)
- [ ] `test/aurum_finance/ledger_test.exs` - Existing account tests (extend, do not rewrite)
- [ ] `test/support/factory.ex` - Factory definitions (transaction_factory, posting_factory from Task 01)
- [ ] `test/support/fixtures.ex` - Fixture helpers (transaction_fixture from Task 01)
- [ ] `test/support/data_case.ex` - DataCase setup pattern
- [ ] `test/support/conn_case.ex` - ConnCase setup pattern (for LiveView tests)
- [ ] `lib/aurum_finance_web/live/transactions_live.ex` - Transactions LiveView (from Task 02, for behavioral reference)

## Expected Outputs

- [ ] **Test file**: `test/aurum_finance/ledger/transaction_test.exs` -- Transaction changeset unit tests (including `void_changeset/1`)
- [ ] **Test file**: `test/aurum_finance/ledger/posting_test.exs` -- Posting changeset unit tests
- [ ] **Extended test file**: `test/aurum_finance/ledger_test.exs` -- Context-level integration tests for transaction APIs (add new `describe` blocks alongside existing account tests)
- [ ] **LiveView test file**: `test/aurum_finance_web/live/transactions_live_test.exs` -- Read-only Transactions LiveView tests
- [ ] All tests pass with `mix test`
- [ ] `mix precommit` passes

## Acceptance Criteria

### Transaction Changeset Tests (`test/aurum_finance/ledger/transaction_test.exs`)
- [ ] `describe "changeset/2"` block with:
  - [ ] Test: valid changeset with all required fields
  - [ ] Test: required fields validation (`entity_id`, `date`, `description`, `source_type`)
  - [ ] Test: `source_type` enum validation (only `:manual`, `:import`, `:system` accepted)
  - [ ] Test: `description` max length 500 chars
  - [ ] Test: `voided_at` is nil on new transaction (not a required field)
  - [ ] Test: immutability guards reject changes to `entity_id`, `date`, `description`, `source_type` on update (when `data.id` is not nil)
  - [ ] Test: immutability guards allow changes on create (when `data.id` is nil)
  - [ ] Test: confirm no `memo` field exists on the schema (use `Map.has_key?/2` or schema introspection)
  - [ ] Test: confirm no `status` field exists on the schema
  - [ ] Test: confirm no `updated_at` field exists on the schema
  - [ ] All error messages use i18n keys (assert on gettext key strings, not translated text)
- [ ] `describe "void_changeset/1"` block with:
  - [ ] Test: sets `voided_at` to a datetime value
  - [ ] Test: rejects attempts to change other fields (e.g., description changes are ignored)

### Posting Changeset Tests (`test/aurum_finance/ledger/posting_test.exs`)
- [ ] `describe "changeset/2"` block with:
  - [ ] Test: valid changeset with all required fields
  - [ ] Test: required fields validation (`transaction_id`, `account_id`, `amount`)
  - [ ] Test: `amount` is required and non-nil
  - [ ] Test: confirm no `currency_code` field exists on the schema (use `Map.has_key?/2` or schema introspection)
  - [ ] Test: confirm no `entity_id` field exists on the schema
  - [ ] Test: confirm no `updated_at` field exists on the schema
  - [ ] All error messages use i18n keys

### Context Tests -- create_transaction/2 (`test/aurum_finance/ledger_test.exs`)
- [ ] `describe "create_transaction/2"` block with:
  - [ ] Test: happy path -- 2-posting balanced transaction, single currency (US-1)
  - [ ] Test: happy path -- 3+ posting split transaction, single currency (US-9)
  - [ ] Test: happy path -- transaction spanning accounts in two currencies (USD+EUR), each group sums to zero (US-10)
  - [ ] Test: returned transaction has `voided_at: nil` and postings preloaded
  - [ ] Test: audit event emitted with `entity_type: "transaction"`, `action: "created"`
  - [ ] Test: error -- unbalanced postings returns `{:error, changeset}` with error on `:postings` (US-2)
  - [ ] Test: error -- fewer than 2 postings rejected (US-2)
  - [ ] Test: error -- empty postings list rejected (US-2)
  - [ ] Test: error -- posting references account from a different entity rejected (US-7)
  - [ ] Test: error -- invalid `account_id` FK constraint error
  - [ ] Test: error -- invalid `entity_id` FK constraint error
  - [ ] Test: error -- no partial writes on validation failure (atomic)
  - [ ] Test: zero amount in a posting is allowed (edge case)

### Context Tests -- get_transaction!/2
- [ ] `describe "get_transaction!/2"` block with:
  - [ ] Test: happy path -- returns transaction with postings preloaded
  - [ ] Test: error -- wrong `entity_id` raises `Ecto.NoResultsError` (US-7)
  - [ ] Test: error -- non-existent `transaction_id` raises `Ecto.NoResultsError`

### Context Tests -- list_transactions/1
- [ ] `describe "list_transactions/1"` block with:
  - [ ] Test: entity scoping -- only returns transactions for the given entity (US-5, US-7)
  - [ ] Test: requires `entity_id` -- raises `ArgumentError` if missing
  - [ ] Test: excludes voided transactions (`voided_at IS NOT NULL`) by default
  - [ ] Test: `include_voided: true` includes voided transactions
  - [ ] Test: filter by `source_type`
  - [ ] Test: filter by `account_id` -- returns transactions with at least one posting to that account (US-5)
  - [ ] Test: filter by `date_from` and `date_to`
  - [ ] Test: ordering by `date` desc, then `inserted_at` desc
  - [ ] Test: postings preloaded on each transaction

### Context Tests -- void_transaction/2
- [ ] `describe "void_transaction/2"` block with:
  - [ ] Test: happy path -- original `voided_at` is set; reversal created with `voided_at: nil` (US-6)
  - [ ] Test: original `voided_at` is a datetime (not nil) after void
  - [ ] Test: reversal has negated amounts and same `account_id` values
  - [ ] Test: both share `correlation_id`
  - [ ] Test: reversal has `source_type: :system`, `voided_at: nil`
  - [ ] Test: two audit events emitted: `"voided"` on original, `"created"` on reversal (US-8)
  - [ ] Test: error -- cannot void an already-voided transaction (`voided_at IS NOT NULL`) (US-6)
  - [ ] Test: balance derivation nets to zero after void (US-6)

### Context Tests -- get_account_balance/2
- [ ] `describe "get_account_balance/2"` block with:
  - [ ] Test: balance derived from postings (replaces placeholder) (US-3)
  - [ ] Test: returns `%{currency_code => Decimal.t()}` with exactly one key
  - [ ] Test: returns `%{}` for accounts with no postings (US-3)
  - [ ] Test: `as_of_date` filtering works (US-4)
  - [ ] Test: balance after void nets to zero (US-6)
  - [ ] Test: balance is always in account's own currency, no FX conversion

### Database Trigger Test
- [ ] `describe "zero-sum database trigger"` block with:
  - [ ] Test: direct SQL insert of unbalanced postings is rejected by the trigger
  - [ ] Test: direct SQL insert of balanced postings (via account join) succeeds

### Entity Isolation Tests
- [ ] Cross-entity isolation verified in:
  - [ ] `create_transaction/2` rejects cross-entity account references
  - [ ] `list_transactions/1` returns only the queried entity's transactions
  - [ ] `get_transaction!/2` rejects wrong entity_id
  - [ ] `get_account_balance/2` scoped correctly (only postings for the given account)

### Read-only Transactions LiveView Tests (`test/aurum_finance_web/live/transactions_live_test.exs`)
- [ ] `describe "mount"` block with:
  - [ ] Test: page renders successfully (connected mount, no crash)
  - [ ] Test: displays transactions for the current session entity
  - [ ] Test: empty state renders when no transactions exist for the entity (no error, helpful message)
- [ ] `describe "filtering"` block with:
  - [ ] Test: voided transactions excluded by default (transactions with `voided_at IS NOT NULL` not shown)
  - [ ] Test: voided transactions appear when the include-voided toggle is enabled
  - [ ] Test: filter by date range reduces the list
  - [ ] Test: filter by source type reduces the list
- [ ] `describe "read-only invariant"` block with:
  - [ ] Test: no "New Transaction" button in the HTML
  - [ ] Test: no "Edit" or "Void" buttons in the HTML
  - [ ] Test: no form with action targeting a create/update/delete route

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance/ledger_test.exs                     # Extend with transaction describe blocks
test/aurum_finance/ledger/                              # New directory for schema unit tests
test/support/factory.ex                                 # transaction_factory, posting_factory
test/support/fixtures.ex                                # transaction_fixture/2
test/support/data_case.ex                               # DataCase with sandbox setup
lib/aurum_finance/ledger.ex                             # Context under test
lib/aurum_finance/ledger/transaction.ex                 # Transaction schema under test
lib/aurum_finance/ledger/posting.ex                     # Posting schema under test
```

### Patterns to Follow

**Test structure pattern** (from existing `test/aurum_finance/ledger_test.exs`):
- `use AurumFinance.DataCase, async: true`
- Group tests with `describe` blocks per function
- Use `errors_on(changeset)` helper for changeset error assertions
- Use fixture helpers for setup: `entity_fixture/1`, `account_fixture/2`, `transaction_fixture/2`
- Assert on i18n error keys (e.g., `"error_field_required"`) not translated messages

**Test setup pattern** for transaction tests:
```elixir
# Common setup: create entity + 2 accounts for balanced transactions
setup do
  entity = entity_fixture()
  checking = account_fixture(entity, %{name: "Checking", account_type: :asset, operational_subtype: :bank_checking, management_group: :institution, currency_code: "USD"})
  groceries = account_fixture(entity, %{name: "Groceries", account_type: :expense, management_group: :category, currency_code: "USD"})
  %{entity: entity, checking: checking, groceries: groceries}
end
```

**Direct SQL for trigger test**:
- Use `Ecto.Adapters.SQL.query!/3` to insert postings directly (bypassing application validation)
- Wrap in a test that expects a Postgrex error on unbalanced insert

**Read-only LiveView test pattern**:
- Use `use AurumFinanceWeb.ConnCase, async: true`
- Log in the test user before mounting the LiveView
- Use `live(conn, ~p"/transactions")` to mount
- Assert on rendered HTML with `assert html =~ "..."` and `refute html =~ "..."` for absent buttons

**Audit event assertion pattern** (from existing account tests):
- Query `AurumFinance.Audit.AuditEvent` after the operation
- Assert on `entity_type`, `action`, `actor`, `channel`, `before`, `after`

### Constraints
- Tests MUST run under DB sandbox and be deterministic
- Tests MUST NOT depend on ordering or timing
- Use `import AurumFinance.TestSupport.Fixtures` for fixture helpers
- Schema unit tests go in `test/aurum_finance/ledger/` directory (new)
- Context integration tests extend the existing `test/aurum_finance/ledger_test.exs` file
- Do not rewrite or reorganize existing account tests

## Execution Instructions

### For the Agent
1. Read all inputs listed above, especially plan.md acceptance criteria (US-1 through US-10), edge cases, and the complete coverage targets in the plan's Task 03 section
2. Create `test/aurum_finance/ledger/transaction_test.exs` for Transaction changeset unit tests (including `void_changeset/1` and absence-of-field tests)
3. Create `test/aurum_finance/ledger/posting_test.exs` for Posting changeset unit tests
4. Add new `describe` blocks to `test/aurum_finance/ledger_test.exs` for context-level tests
5. Create `test/aurum_finance_web/live/transactions_live_test.exs` for the read-only LiveView tests
6. Write tests following the existing patterns (describe blocks, errors_on, fixtures, async: true)
7. Ensure every user story (US-1 through US-10) has at least one corresponding test
8. Ensure every acceptance criterion has a corresponding test assertion
9. Ensure every edge case from plan.md is covered
10. Verify: no test references `status`, `memo`, or `updated_at` on transactions; use `voided_at` throughout
11. Run `mix test` to verify all tests pass
12. Run `mix precommit` to verify formatting, Credo pass
13. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify every user story (US-1 through US-10) has test coverage
2. Verify every acceptance criterion scenario from plan.md has a test
3. Verify edge cases (empty states, error states, boundary conditions) are tested
4. Verify entity isolation is tested from multiple angles
5. Verify database trigger test uses direct SQL (not context API)
6. Verify test structure follows existing patterns (describe blocks, async: true)
7. Run `mix test` locally and check for flaky or slow tests
8. Run `mix precommit`
9. If approved: mark `[x]` on "Approved" and update plan.md status
10. If rejected: add rejection reason and specific feedback

---

## Execution Summary
### Work Performed
- Added schema unit tests for `AurumFinance.Ledger.Transaction` and `AurumFinance.Ledger.Posting`.
- Consolidated transaction context coverage into `test/aurum_finance/ledger_test.exs` and removed the temporary `ledger_transactions_test.exs`.
- Expanded `TransactionsLive` coverage for empty state, compact URL hydration, source filtering, include-voided behavior, and the read-only invariant.
- Added `docs/qa/test_plan.md` to map scenario groups to concrete test files.

### Outputs Created
- `test/aurum_finance/ledger/transaction_test.exs`
- `test/aurum_finance/ledger/posting_test.exs`
- `docs/qa/test_plan.md`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| DB-level zero-sum trigger coverage is no longer applicable | The trigger was intentionally removed earlier in this PR and the invariant now lives in the app layer only |
| Transactions LiveView date filtering should be tested through URL presets instead of `from/to` inputs | The implemented UI uses compact `q=` filters plus `this_week` / `this_month` / `this_year` / `all` presets |
| Validation assertions should follow the app's current mix of gettext keys and translated strings | Existing schemas are not fully uniform yet, so tests must lock the real current contract |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Moved transaction integration coverage into `ledger_test.exs` and deleted `ledger_transactions_test.exs` | Keeping the extra file | The task explicitly asked for context-level coverage in `ledger_test.exs`; consolidating reduces duplication |
| Added `docs/qa/test_plan.md` with scenario-group mapping instead of a line-by-line user-story matrix | No plan file | The QA agent instructions explicitly require a test plan artifact |
| Tested read-only invariant by checking absence of transaction mutation affordances, not every `delete` attribute in the DOM | Broad HTML substring blocking | The app shell includes a logout link with `data-method="delete"`, so broad delete assertions are noisy and incorrect |

### Blockers Encountered
- Task spec still referenced a DB trigger and old LiveView date-range UI. Resolution: covered the implemented behavior and documented the divergence in `docs/qa/test_plan.md`.

### Questions for Human
1. None.

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
