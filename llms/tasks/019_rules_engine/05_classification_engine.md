# Task 05: Classification.Engine Pure Evaluator

## Status
- **Status**: COMPLETED
- **Approved**: [x] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 06, Task 09

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Implement `AurumFinance.Classification.Engine` as a pure-function evaluator that executes active rule groups against in-memory transaction data, evaluates the AurumFinance DSL through an internal adapter/wrapper boundary, applies rule actions, and returns explainable per-field proposals without writing to the database. The engine must support unified scoped rule groups (`account`, `entity`, `global`) with deterministic matching and precedence.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (Decision 5, Condition Model, Action Model, Issue #20 preview semantics)
- [ ] `llms/tasks/019_rules_engine/02_classification_context_crud.md` - DSL compiler/validator outputs and supported field/operator contract
- [ ] `llms/constitution.md` - Context API and documentation requirements
- [ ] `llms/project_context.md` - Product invariants for grouped rules and explainability
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance/classification/expression_validator.ex` - Expression validation contract from Task 02
- [ ] `lib/aurum_finance/classification/rule_group.ex` - Group shape and priority semantics
- [ ] `lib/aurum_finance/classification/rule.ex` - Rule shape and action embedding
- [ ] `lib/aurum_finance/ledger/transaction.ex` - Transaction data shape
- [ ] `lib/aurum_finance/ledger/posting.ex` - Posting data shape
- [ ] `lib/aurum_finance/ledger/account.ex` - Account data used by posting-derived fields

## Expected Outputs

- [x] New module: `lib/aurum_finance/classification/engine.ex`
- [x] Internal evaluator adapter/wrapper module(s) used by the engine so the underlying parser/evaluator can be swapped later without changing the DSL contract
- [x] Supporting structs/types inside the engine module or adjacent modules for preview results and per-field provenance
- [x] `@doc` documentation for the public evaluation entrypoints and core return structures

## Acceptance Criteria

- [ ] Public entrypoint implemented for pure evaluation, following the spec shape: evaluates transactions and rule groups without DB access or side effects
- [ ] The engine selects matching groups for a transaction using the unified scope model: global groups, entity-scoped groups matching `transaction.entity_id`, and account-scoped groups matching any `posting.account_id` on the transaction
- [ ] Matching groups are ordered by scope precedence `account > entity > global`, then `priority ASC`, then deterministic tie-break by `name ASC`
- [ ] Rules within a group are evaluated in `position ASC`, with deterministic tie-break by `name ASC`
- [ ] The engine evaluates expressions through an AurumFinance-owned adapter/wrapper layer rather than hard-coding a third-party evaluator into the public engine contract
- [ ] A concrete evaluator backend may use `Excellerate`, a custom parser/evaluator, or another implementation, but it must remain replaceable behind the adapter boundary
- [ ] Group semantics honor `is_active`; inactive groups are skipped entirely
- [ ] Rule semantics honor `is_active`; inactive rules are skipped entirely
- [ ] Rule semantics honor `stop_processing`; when `true`, first matching rule in the group stops further rule evaluation inside that group
- [ ] Matching semantics support all v1 condition fields as finalized in the spec/tasks; `memo` is out of scope for v1
- [ ] Posting-derived conditions evaluate against each posting independently; a rule matches if any posting satisfies all conditions
- [ ] `currency_code` condition evaluation reads from `posting.account.currency_code`
- [ ] The engine applies actions per field using first-writer-wins across groups for the same evaluation pass
- [ ] `category` action values are treated as account UUID strings in the proposed output, not display names
- [ ] Tags `add`/`remove` operations are applied deterministically with no duplicates
- [ ] Notes `append` appends newline-separated content
- [ ] Engine output is explainable per field: winning group, rule, action, old value/proposed value, and whether the field was skipped/protected
- [ ] Engine returns enough structured data for preview UI to show `matched`, `proposed`, `protected`, and `no_match` states
- [ ] Invalid expressions or invalid action payloads fail safe for the affected rule/action and do not crash the evaluation pass
- [ ] All public functions have `@doc`

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/classification/              # New rules engine namespace
lib/aurum_finance/ledger/transaction.ex        # Transaction shape
lib/aurum_finance/ledger/posting.ex            # Posting shape
lib/aurum_finance/ledger/account.ex            # Account-derived fields
```

### Patterns to Follow
- Keep the engine pure and deterministic; all inputs are explicit arguments
- Use small private helpers for field extraction, expression evaluation, and action application
- Prefer pattern matching for action dispatch by field/operation
- Return tagged tuples or well-defined structs instead of ad hoc maps
- Keep evaluator-specific code isolated behind a wrapper/adapter module
- Keep scope selection and group ordering centralized in a small, testable helper path

### Constraints
- Do NOT query the database inside the engine
- Do NOT write `ClassificationRecord` rows here
- Do NOT emit audit events here
- The engine must be reusable by both preview (Task 06) and apply APIs (Task 09)
- `memo` is out of scope for v1 and must not be implemented in this task
- `currency_code` must be evaluated only from `posting.account.currency_code`
- Do NOT leak library-specific syntax or types into the public engine/compiler/validator contract

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Implement the evaluator wrapper/adapter first, then wire the engine to it
3. Define the public evaluation API and return shape before implementing helpers
4. Implement scope matching and scope precedence ordering first
5. Implement condition evaluation for the supported field/operator matrix
6. Implement group and rule ordering semantics exactly as documented in the spec
7. Implement action application and per-field claim tracking
8. Include explicit explainability data needed by preview and audit layers
9. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify the engine is pure and has no repo/audit dependencies
2. Verify group/rule ordering and first-writer-wins semantics against the spec
3. Review the output structure for suitability in preview and apply flows
4. Confirm any unresolved `memo`/field support decision is explicit
5. If approved: mark `[x]` on "Approved" and update `execution_plan.md` status

---

## Execution Summary
Completed on 2026-03-13.

### Work Performed
- Implemented a pure `AurumFinance.Classification.Engine` with deterministic scope/rule ordering and first-writer-wins field claiming
- Added evaluator boundary module `AurumFinance.Classification.Engine.DslEvaluator`
- Added result/proposed-change structs for preview/apply explainability
- Added unit coverage for scope precedence, stop-processing, case-insensitive string operators, protected fields, and invalid-expression fail-safe behavior

### Outputs Created
- `lib/aurum_finance/classification/engine.ex`
- `lib/aurum_finance/classification/engine/dsl_evaluator.ex`
- `lib/aurum_finance/classification/engine/result.ex`
- `lib/aurum_finance/classification/engine/proposed_change.ex`
- `test/aurum_finance/classification/engine_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
- String operators (`equals`, `contains`, `starts_with`, `ends_with`) should behave case-insensitively | Matches the plan/spec contract for v1 string comparisons |
- Category action values remain UUID strings in engine output | The engine is pure and does not resolve category account names for display |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
- Keep a separate `DslEvaluator` behind the engine boundary | Inlining evaluation logic directly into `Engine` | Preserves a replaceable evaluator backend without changing the engine contract |
- Return explicit `Result` / `ProposedChange` structs | Returning untyped ad hoc maps | Makes preview/apply consumers and tests more stable and easier to reason about |

### Blockers Encountered
- None after Task 02 was available

### Questions for Human
1. None

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
2026-03-13

### Decision
- [x] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
