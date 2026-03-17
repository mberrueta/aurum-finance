# Task 01: Migration + Schemas (RuleGroup, Rule, Action Embedded Schema)

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 02, Task 04, Task 05, Task 09

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Create the Ecto migration for `rule_groups` and `rules` tables, plus the corresponding Ecto schemas (`RuleGroup`, `Rule`) and the `RuleAction` embedded schema for JSONB action validation. In this design, `rule_groups.target_fields` is persisted as a Postgres array of strings and `RuleGroup` uses an explicit unified scope model (`global`, `entity`, `account`). This is the data foundation for the entire rules engine.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (sections: Issue #19 New Entities, Schema Design, Condition Model, Action Model, Action Embedded Schema)
- [ ] `llms/constitution.md` - Project coding standards
- [ ] `llms/project_context.md` - Project conventions
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance/ledger/account.ex` - Reference schema pattern (PK, timestamps, @required/@optional, changeset)
- [ ] `lib/aurum_finance/ledger/transaction.ex` - Reference schema pattern
- [ ] `lib/aurum_finance/entities/entity.ex` - Entity schema (FK target for `entity_id`)
- [ ] `priv/repo/migrations/` - Existing migration naming convention

## Expected Outputs

- [ ] Migration file: `priv/repo/migrations/YYYYMMDDHHMMSS_create_rule_groups_and_rules.exs`
- [ ] Schema: `lib/aurum_finance/classification/rule_group.ex` (`AurumFinance.Classification.RuleGroup`)
- [ ] Schema: `lib/aurum_finance/classification/rule.ex` (`AurumFinance.Classification.Rule`)
- [ ] Embedded schema: `lib/aurum_finance/classification/rule_action.ex` (`AurumFinance.Classification.RuleAction`)

## Acceptance Criteria

- [ ] Migration creates `rule_groups` table with all columns per spec: `id` (binary_id PK), `scope_type` (string column, NOT NULL, storing `global | entity | account`), `entity_id` (FK to entities, nullable), `account_id` (FK to accounts, nullable), `name` (string, NOT NULL), `description` (text, nullable), `priority` (integer, NOT NULL), `target_fields` (`{:array, :string}` / Postgres `text[]`, NOT NULL, default `[]`), `is_active` (boolean, NOT NULL, default true), timestamps (utc_datetime_usec)
- [ ] Migration creates `rules` table with all columns per spec: `id` (binary_id PK), `rule_group_id` (FK to rule_groups, NOT NULL, on_delete: :delete_all), `name` (string, NOT NULL), `description` (text, nullable), `position` (integer, NOT NULL), `is_active` (boolean, NOT NULL, default true), `stop_processing` (boolean, NOT NULL, default true), `expression` (text, NOT NULL), `actions` (JSONB, NOT NULL, default `[]`), timestamps
- [ ] Migration adds DB constraints enforcing valid scope combinations: `:global => entity_id/account_id both NULL`, `:entity => entity_id NOT NULL and account_id NULL`, `:account => account_id NOT NULL and entity_id NULL`
- [ ] Indexes created per spec: `rule_groups` -- `(scope_type)`, `(entity_id)`, `(account_id)`, unique partial/conditional name indexes per scope target (`global:name`, `entity:(entity_id,name)`, `account:(account_id,name)`), `(scope_type, priority)`, `(scope_type, is_active)`; `rules` -- `(rule_group_id)`, `(rule_group_id, position)`
- [ ] Migration is reversible
- [ ] `RuleGroup` schema: `@primary_key {:id, :binary_id, autogenerate: true}`, declares `@required` and `@optional`, `changeset/2` casts and validates per constitution rules, maps `scope_type` with `Ecto.Enum, values: [:global, :entity, :account]`, `belongs_to :entity`, `belongs_to :account`, `has_many :rules`, `target_fields` as `{:array, :string}`, i18n error messages via `dgettext("errors", ...)`
- [ ] `RuleGroup` changeset enforces valid scope combinations and forbids both `entity_id` and `account_id` at the same time
- [ ] `Rule` schema: same PK/changeset conventions, `belongs_to :rule_group`, `expression` as `:string`, `actions` via `embeds_many :actions, RuleAction, on_replace: :delete`, `stop_processing` defaults to `true`
- [ ] `RuleAction` embedded schema: fields `field` (Ecto.Enum: `[:category, :tags, :investment_type, :notes]`), `operation` (Ecto.Enum: `[:set, :add, :remove, :append]`), `value` (:string); changeset validates field/operation compatibility per spec (category requires :set, tags requires :add/:remove, notes requires :set/:append, investment_type requires :set)
- [ ] `RuleGroup` name validation: 2-160 chars
- [ ] `Rule` name validation: 2-160 chars
- [ ] `RuleGroup.priority` validation: positive integer
- [ ] `Rule.position` validation: positive integer
- [ ] All validation messages use `dgettext("errors", "...")` per constitution
- [ ] `@doc` on all public functions

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/ledger/account.ex        # Schema pattern reference
lib/aurum_finance/entities/entity.ex       # Entity FK target
lib/aurum_finance/ledger/account.ex        # Account FK target for account-scoped groups
priv/repo/migrations/                      # Migration naming
```

### Patterns to Follow
- `@primary_key {:id, :binary_id, autogenerate: true}` (see Account, Transaction schemas)
- `timestamps(type: :utc_datetime_usec)`
- `@required` / `@optional` module attributes for changeset field lists
- `changeset/2` with `cast(attrs, @required ++ @optional)` then `validate_required(@required)`
- `dgettext("errors", "error_...")` for all validation messages
- FK references use `:binary_id` type

### Constraints
- Do NOT create the `classification_records` migration yet (that is Task 09)
- Do NOT create the `AurumFinance.Classification` context module yet (that is Task 02)
- The `actions` column stores JSONB but is modeled via `embeds_many` with `on_replace: :delete` for changeset validation
- `target_fields` on `RuleGroup` is stored as a Postgres string array and modeled as `{:array, :string}` in the schema
- `account_id` implies entity ownership through the related account; do not store redundant `entity_id` on account-scoped groups

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Create the `lib/aurum_finance/classification/` directory
3. Create the migration file with both tables, scope columns, scope check constraints, indexes, and constraints
4. Create `RuleAction` embedded schema first (Rule depends on it)
5. Create `RuleGroup` schema with all scope validations
6. Create `Rule` schema with embedded actions and all validations
7. Verify the migration is reversible (has a `down` or uses `create table` inside a `change` function)
8. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review migration columns, types, constraints, and indexes against spec
2. Verify schema validations match spec acceptance criteria
3. Run `mix ecto.migrate` to verify migration applies cleanly
4. Check embedded schema field/operation validation matrix
5. If approved: mark `[x]` on "Approved" and update execution_plan.md status
6. If rejected: add rejection reason and specific feedback

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
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
