# Task 03: Context CRUD Tests + Factory Definitions

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: None (non-blocking for later tasks, but should complete before commit 1)

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Write comprehensive ExUnit tests for the `AurumFinance.Classification` context CRUD operations, expression compiler, and expression validator. Create ExMachina factories for `rule_group` and `rule`.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (acceptance criteria for US-1 through US-8)
- [ ] `llms/tasks/019_rules_engine/02_classification_context_crud.md` - Task 02 outputs
- [ ] `llms/constitution.md` - Test discipline requirements
- [ ] `llms/coding_styles/elixir_tests.md` - Test style guide
- [ ] `lib/aurum_finance/classification.ex` - Context under test (from Task 02)
- [ ] `lib/aurum_finance/classification/expression_compiler.ex` - Compiler under test
- [ ] `lib/aurum_finance/classification/expression_validator.ex` - Validator under test
- [ ] `test/support/factory.ex` - Existing factory file to extend
- [ ] `test/aurum_finance/ledger_test.exs` - Reference test pattern

## Expected Outputs

- [ ] Updated factory: `test/support/factory.ex` with `rule_group_factory`, `rule_factory`, `insert_rule_group/2`, `insert_rule/3` helpers
- [ ] Test file: `test/aurum_finance/classification_test.exs`
- [ ] Test file: `test/aurum_finance/classification/expression_compiler_test.exs`
- [ ] Test file: `test/aurum_finance/classification/expression_validator_test.exs`

## Acceptance Criteria

- [ ] Factories: `rule_group_factory` creates a valid entity-scoped `RuleGroup` by default; factory traits/helpers also cover `global_rule_group` and `account_rule_group`; `rule_factory` creates a valid `Rule` with default rule_group association, valid expression, and valid actions
- [ ] `insert_rule_group/2` and `insert_rule/3` convenience helpers following existing `insert_account/2` pattern, with support for explicit scope setup where needed
- [ ] **RuleGroup CRUD tests**: create happy path for `global`, `entity`, and `account` scopes; create with validation errors (missing name, invalid priority, invalid scope combinations), scoped name uniqueness, list ordering and filters, get by id, update, delete (cascades rules), change_rule_group
- [ ] **Rule CRUD tests**: create from structured conditions (compiler integration), create with direct expression, create with invalid expression (rejected), create with invalid action field/operation combos, create with target_fields validation (group constrains action fields), list ordering (position ASC, name ASC), update expression (valid and invalid), delete, audit events emitted for create/update/delete
- [ ] **Expression compiler tests**: single condition, multiple AND conditions, negated conditions, all operators (equals, contains, starts_with, ends_with, matches_regex, >, <, >=, <=, is_empty, is_not_empty), all fields
- [ ] **Expression validator tests**: valid expressions pass, invalid field names rejected, invalid operators rejected, malformed syntax rejected, empty expression rejected
- [ ] Scope-aware query tests cover `visible_to_entity_id` / `visible_to_account_ids` behavior for loading global + matching entity + matching account groups
- [ ] Field coverage explicitly excludes `memo` for v1
- [ ] Tests cover that `currency_code` is treated as a supported derived field sourced from `posting.account.currency_code`
- [ ] Tests use `async: true` where possible
- [ ] Tests use `describe` blocks grouped by function
- [ ] Tests follow factory pattern (no fixtures, no `*_fixture` naming)
- [ ] All tests pass with `mix test`

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance/ledger_test.exs         # Reference test pattern
test/support/factory.ex                     # Factory to extend
test/support/data_case.ex                   # DataCase setup
```

### Patterns to Follow
- `use AurumFinance.DataCase, async: true`
- `import AurumFinance.Factory`
- `describe "function_name/arity" do ... end`
- `errors_on(changeset)` for changeset assertion
- Factory helpers like `insert_entity()`, `insert_account(entity, attrs)`

### Constraints
- Do NOT test engine evaluation (Task 07)
- Do NOT test ClassificationRecord (Task 10)
- Focus on CRUD operations, expression compilation, and validation
- Do not add tests for `memo`; it is out of scope for v1

## Execution Instructions

### For the Agent
1. Read all inputs listed above, especially the coding style guides
2. Add factories to `test/support/factory.ex` (do not create a separate factory file)
3. Create test files mirroring source paths
4. Cover all acceptance criteria from spec US-1 through US-8
5. Ensure edge cases from spec "Edge Cases" section are covered (empty states, error states, boundary conditions)
6. Run `mix test` to verify all tests pass
7. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Run `mix test` to verify green
2. Review test coverage against spec acceptance criteria
3. Verify factory patterns match existing conventions
4. If approved: mark `[x]` on "Approved" and update execution_plan.md status

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
