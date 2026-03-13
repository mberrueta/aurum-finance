# Task 02: Classification Context CRUD + Expression DSL Compiler

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03, Task 04, Task 05

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Create the `AurumFinance.Classification` context module with full CRUD for rule groups and rules. Includes the expression DSL compiler that translates structured condition input (field/operator/value tuples) into the AurumFinance DSL expression string, the expression validator, and scope-aware query/loading contracts for unified scoped rule groups. This task defines AurumFinance-owned DSL contracts only; it must not couple the design to a specific evaluation library.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (Context API Shape, Condition Model, Action Model, Evaluation Semantics)
- [ ] `llms/tasks/019_rules_engine/01_migration_and_schemas.md` - Task 01 outputs (schemas)
- [ ] `llms/constitution.md` - Coding standards (Context APIs & Query Patterns)
- [ ] `llms/project_context.md` - Engineering conventions
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance/ledger.ex` - Reference context pattern (list_*/get_*/create_*/update_*/change_*, filter_query/2, require_entity_scope!, audit integration)
- [ ] `lib/aurum_finance/audit.ex` - Audit helpers (insert_and_log/2, update_and_log/3)
- [ ] `lib/aurum_finance/classification/rule_group.ex` - RuleGroup schema (from Task 01)
- [ ] `lib/aurum_finance/classification/rule.ex` - Rule schema (from Task 01)
- [ ] `lib/aurum_finance/classification/rule_action.ex` - RuleAction embedded schema (from Task 01)

## Expected Outputs

- [ ] Context: `lib/aurum_finance/classification.ex` (`AurumFinance.Classification`)
- [ ] DSL compiler module: `lib/aurum_finance/classification/expression_compiler.ex`
- [ ] DSL validator module: `lib/aurum_finance/classification/expression_validator.ex`
- [ ] Internal evaluator contract/behaviour or adapter boundary that Task 05 can implement behind the AurumFinance DSL

## Acceptance Criteria

- [ ] Context module `AurumFinance.Classification` follows project conventions: `import Ecto.Query`, aliases, `@moduledoc`
- [ ] **RuleGroup CRUD**: `list_rule_groups/1` supports scope-aware filters (`scope_type`, `entity_id`, `account_id`, `visible_to_entity_id`, `visible_to_account_ids`, optional `is_active`) and deterministic ordering; `get_rule_group!/1` or equivalent scope-agnostic fetch by id; `create_rule_group/2` (with audit), `update_rule_group/3` (with audit), `delete_rule_group/2` (cascades to rules, with audit), `change_rule_group/2`
- [ ] **Rule CRUD**: `list_rules/1` (requires `rule_group_id`, ordered by `position ASC, name ASC`), `get_rule!/1` or equivalent scope-agnostic fetch by id, `create_rule/2` (compiles conditions to expression, validates expression, stores actions JSONB, with audit), `update_rule/3` (validates expression on update, with audit), `delete_rule/2` (with audit), `change_rule/2`
- [ ] `create_rule/2` accepts `conditions` key (list of `%{field, operator, value, negate}` maps) and compiles them to `expression` string via the expression compiler
- [ ] `create_rule/2` also accepts `expression` directly for cases where the compiled expression is provided
- [ ] Expression compiler: translates structured conditions to AurumFinance DSL format (e.g., `description contains "Uber"`, `(description contains "Uber") AND (amount < 0)`, `NOT (description contains "ATM")`)
- [ ] Expression validator: validates that an expression string is syntactically valid and references only supported fields/operators. Returns `{:ok, expression}` or `{:error, reason}` via AurumFinance-owned validation logic and contract, without exposing any library-specific syntax
- [ ] Task 02 does not add or require a concrete evaluator dependency in `mix.exs`
- [ ] Task 02 defines a stable adapter boundary so Task 05 can plug in an evaluator implementation without changing the DSL/compiler/validator public contract
- [ ] Supported condition fields for v1 explicitly exclude `memo`; agents must not introduce `memo` support or a migration implicitly from this task
- [ ] `currency_code` support is implemented only as a derived posting field via `posting.account.currency_code`
- [ ] RuleGroup scope validation is enforced in the context and schema layers: `global => no FKs`, `entity => entity_id only`, `account => account_id only`
- [ ] Context exposes a scope-aware helper/query contract to load groups visible for evaluation of a transaction (`global` + matching `entity` + matching `account`)
- [ ] `filter_query/2` private multi-clause function following Ledger pattern
- [ ] `target_fields` weak validation: when creating/updating a rule, if the parent group has non-empty `target_fields`, each action's `field` must be in `target_fields`; error message: "Action field '{field}' is not declared in this group's target fields"
- [ ] All public functions have `@doc` documentation
- [ ] Audit events emitted for create/update/delete of both rule groups and rules using existing `Audit.insert_and_log/2`, `Audit.update_and_log/3` patterns
- [ ] Entity type for audit: `"rule_group"` and `"rule"`
- [ ] All validation messages use `dgettext("errors", "...")`

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/ledger.ex                # Context pattern reference
lib/aurum_finance/audit.ex                 # Audit helper API
lib/aurum_finance/classification/          # Schemas from Task 01
```

### Patterns to Follow
- `list_*` functions accept `opts` keyword list, dispatch to private `filter_query/2`
- Scope filters are explicit; do not force `entity_id` for global/account rule groups
- Audit meta map: `%{actor:, channel:, entity_type:, redact_fields:, serializer:}`
- `{:ok, record}` / `{:error, changeset}` return tuples
- Delete uses `Repo.delete` (cascade handled by DB FK constraint)

### Constraints
- Do NOT implement the engine evaluation logic (that is Task 05)
- Do NOT create `ClassificationRecord` schema (that is Task 09)
- Do NOT implement `preview_classification/1` or `classify_transactions/1` (those are Tasks 06, 09)
- The expression compiler is one-directional only (structured -> string). No string -> structured parsing.
- Expression validation must reject invalid field names, invalid operators, invalid type combinations
- Do NOT couple this task to `Excellerate` or any other evaluator package
- `memo` is out of scope for v1 and must not appear in the supported field matrix for this task
- `currency_code` is derived from `posting.account.currency_code`, not from a persisted `Posting.currency_code`

### Expression DSL Format
```
# Single condition
description contains "Uber"

# Negated condition
NOT (description contains "ATM")

# Multiple conditions (AND joined)
(description contains "Uber") AND (amount < 0)

# Operators map to DSL keywords
equals, contains, starts_with, ends_with, matches_regex, >, <, >=, <=, is_empty, is_not_empty
```

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Define the AurumFinance-owned DSL/compiler/validator contract first, including the adapter boundary Task 05 will implement
3. Create the expression compiler module (structured conditions -> DSL string)
4. Create the expression validator module (DSL string -> validation result)
5. Create the Classification context with all CRUD functions
6. Follow the Ledger context as a structural reference
7. Implement scope-aware list/query behavior for `RuleGroup`
8. Implement target_fields weak validation in rule create/update
9. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify context API matches spec's "Context API Shape" section
2. Test expression compiler with examples from spec
3. Verify audit integration follows existing patterns
4. Check that target_fields validation works correctly
5. If approved: mark `[x]` on "Approved" and update execution_plan.md status

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
