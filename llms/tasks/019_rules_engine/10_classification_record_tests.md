# Task 10: Classification Record Tests

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 09
- **Blocks**: None (should complete before commit 3 is considered done)

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Write ExUnit coverage for `ClassificationRecord` persistence, single-transaction apply, bulk apply, manual overrides, provenance, and audit side effects.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (Issue #21, US-13 through US-16)
- [ ] `llms/tasks/019_rules_engine/09_classification_record_and_apply_apis.md` - Apply/manual API contract
- [ ] `llms/constitution.md` - Test discipline requirements
- [ ] `llms/coding_styles/elixir_tests.md` - Test style guide
- [ ] `lib/aurum_finance/classification.ex` - APIs under test
- [ ] `lib/aurum_finance/classification/classification_record.ex` - Schema under test
- [ ] `lib/aurum_finance/audit/audit_event.ex` - Audit evidence model
- [ ] `test/support/factory.ex` - Shared factories

## Expected Outputs

- [ ] Test file: `test/aurum_finance/classification/classification_record_test.exs` or equivalent focused context test file
- [ ] Additional tests in `test/aurum_finance/classification_test.exs` if that is the chosen pattern
- [ ] Factory additions for `classification_record` and any convenience helpers needed for apply/manual flows

## Acceptance Criteria

- [ ] Tests cover `ClassificationRecord` changeset validations and field constraints
- [ ] Tests cover single-transaction apply creating a new record
- [ ] Tests cover single-transaction apply updating an existing unlocked record
- [ ] Tests cover bulk apply summary counts (`applied`, `skipped_manual`, `no_match`, and failures if supported)
- [ ] Tests cover scope-aware apply selection and precedence across global/entity/account groups
- [ ] Tests cover per-field manual protection: locked category skipped while unlocked tags/notes still update
- [ ] Tests cover `set_manual_field/4` for each supported field type
- [ ] Tests cover `clear_manual_override/3` retaining the existing value while unlocking automation
- [ ] Tests cover category validation against same-entity category accounts
- [ ] Tests cover provenance data written to `*_classified_by`
- [ ] Tests cover audit event emission for apply and manual-override operations
- [ ] Tests cover graceful behavior when provenance references a deleted rule/group
- [ ] Tests use factories and deterministic assertions
- [ ] Tests run with `mix test`

## Technical Notes

### Relevant Code Locations
```text
test/support/factory.ex                              # Factory definitions
test/aurum_finance/classification_test.exs           # Existing context tests
test/aurum_finance/classification/                   # New focused test area
lib/aurum_finance/audit/audit_event.ex               # Audit verification
```

### Patterns to Follow
- Use `errors_on/1` for changeset assertions
- Prefer small scenario-focused tests over giant end-to-end setup blocks
- Assert audit records by meaningful metadata rather than broad count-only checks
- Keep field-level override tests explicit and readable

### Constraints
- Do NOT write LiveView tests here; that is Task 12
- Do NOT duplicate engine unit tests from Task 07
- Focus on persistence and side effects, not UI rendering

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Add the `classification_record` factory only if Task 09 requires it
3. Cover single-transaction, bulk, and manual override flows separately
4. Verify audit evidence in tests
5. Run `mix test` and document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Run `mix test`
2. Verify the tests actually cover per-field override semantics
3. Review audit assertions for meaningfulness
4. If approved: mark `[x]` on "Approved" and update `execution_plan.md` status

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

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

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

### Git Operations Performed
```bash
```
