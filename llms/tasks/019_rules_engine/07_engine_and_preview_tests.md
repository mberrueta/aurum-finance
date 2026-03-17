# Task 07: Engine + Preview Tests

## Status
- **Status**: COMPLETED
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 06
- **Blocks**: None (should complete before preview UI ships)

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Write ExUnit coverage for the rules engine and preview API, focusing on deterministic ordering, matching semantics, fail-safe behavior, and explainable preview payloads.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (Issue #20 acceptance criteria and edge cases)
- [ ] `llms/tasks/019_rules_engine/05_classification_engine.md` - Engine behavior contract
- [ ] `llms/tasks/019_rules_engine/06_preview_api.md` - Preview API contract
- [ ] `llms/constitution.md` - Test discipline requirements
- [ ] `llms/coding_styles/elixir_tests.md` - Test style guide
- [ ] `lib/aurum_finance/classification/engine.ex` - Engine under test
- [ ] `lib/aurum_finance/classification.ex` - Preview API under test
- [ ] `test/support/factory.ex` - Factories from Task 03
- [ ] `test/aurum_finance/classification_test.exs` - Existing context test pattern from Task 03

## Expected Outputs

- [ ] Test file: `test/aurum_finance/classification/engine_test.exs`
- [ ] Updated or new test file covering `preview_classification/1` in `test/aurum_finance/classification_test.exs` or `test/aurum_finance/classification/preview_test.exs`
- [ ] Any additional factory helpers needed for transactions/classification setup added to `test/support/factory.ex`

## Acceptance Criteria

- [ ] Engine tests cover scope matching and precedence: account-scoped groups outrank entity-scoped groups, which outrank global groups
- [ ] Engine tests cover group ordering by `priority ASC` and tie-break by `name ASC` within the same scope precedence
- [ ] Engine tests cover rule ordering by `position ASC` and tie-break by `name ASC`
- [ ] Engine tests cover `stop_processing: true` and `stop_processing: false`
- [ ] Engine tests cover multi-posting transaction matching semantics
- [ ] Engine tests explicitly exclude `memo` from the v1 supported field set
- [ ] Engine tests cover `currency_code` matching through `posting.account.currency_code`
- [ ] Engine tests cover first-writer-wins per field across groups
- [ ] Engine tests cover tags add/remove semantics and notes append semantics
- [ ] Engine tests cover fail-safe handling for invalid expressions or invalid action payloads
- [ ] Preview API tests cover entity scoping and date-range filtering
- [ ] Preview API tests cover loading of global + matching entity + matching account groups
- [ ] Preview API tests cover no-match rows, matched rows, and protected/manual-override indicators
- [ ] Preview API tests assert no DB writes occur during preview
- [ ] Tests use factories rather than fixtures
- [ ] Tests use `describe` blocks and deterministic assertions
- [ ] Tests run with `mix test`

## Technical Notes

### Relevant Code Locations
```text
test/support/factory.ex                         # Shared factories/helpers
test/aurum_finance/classification_test.exs      # Context tests
test/aurum_finance/classification/              # New engine/preview test area
```

### Patterns to Follow
- `use AurumFinance.DataCase, async: true`
- Prefer focused unit tests for the pure engine and narrower integration tests for the preview API
- Assert structured outputs instead of raw rendered text
- Keep setup data minimal and explicit

### Constraints
- Do NOT write LiveView tests here; that is Task 12
- Do NOT test final apply/write semantics here; that is Task 10
- Keep engine tests independent from database IO wherever possible

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Cover the pure engine first, then add preview integration tests
3. Add only the minimal helper/factory surface needed
4. Verify no preview writes are introduced through test assertions
5. Run `mix test` and document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Run `mix test`
2. Verify ordering semantics and protected-preview cases are covered
3. Review that the tests stay at the proper layer (engine/context, not UI)
4. If approved: mark `[x]` on "Approved" and update `execution_plan.md` status

---

## Execution Summary
Completed on 2026-03-14.

### Work Performed
- Rewrote `test/aurum_finance/classification/engine_test.exs` with 38 pure unit tests (no DB) covering all acceptance criteria for the engine
- Created `test/aurum_finance/classification/preview_test.exs` with 11 DB integration tests for `preview_classification/1`
- Updated `docs/qa/test_plan.md` with complete scenario-to-test mapping (S01-S49)
- No changes to production code or factory.ex were needed

### Outputs Created
- `test/aurum_finance/classification/engine_test.exs` (38 tests, pure in-memory structs, no DB)
- `test/aurum_finance/classification/preview_test.exs` (11 tests, DataCase async: true)
- Updated `docs/qa/test_plan.md` with Classification Engine section

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| S47 (protected indicators) tests the engine directly rather than through `preview_classification/1` | `preview_classification/1` does not yet pass `current_classifications` to the engine; that is deferred to Task #21 when `ClassificationRecord` is implemented |
| Voided transaction test asserts the voided txn is absent rather than asserting an empty result | `void_transaction` creates a reversal transaction that is not voided, so the preview may return the reversal |
| Transactions require double-entry balanced postings in tests | The Ledger context validates at least two postings summing to zero per currency |
| Expense contra accounts use `management_group: :category, operational_subtype: nil` | The Account schema validation rejects expense accounts with institution-style management group and operational subtype |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Engine tests use `ExUnit.Case` (no DB) with inline struct helpers | Use `DataCase` with factories and DB-persisted data | Engine is pure; keeping tests DB-free makes them fast and independent |
| Preview tests use `Ledger.create_transaction/1` through a helper | Use `insert(:transaction)` factory directly | The factory bypasses Ledger validation; using the context API ensures transactions have valid balanced postings and proper preloads |
| Created separate `preview_test.exs` rather than appending to `classification_test.exs` | Append to existing test file | Keeps preview API tests focused and separate from CRUD context tests; follows file-per-concern convention |

### Blockers Encountered
- None

### Questions for Human
1. None

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review

### Decision
- [X] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
