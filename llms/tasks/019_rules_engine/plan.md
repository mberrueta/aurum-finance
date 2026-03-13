# 019 - Rules Engine: Data Model, Preview, and Classification

**GitHub Issues**: #19, #20, #21
**Status**: READY FOR TECH LEAD REVIEW
**Priority**: P1
**Labels**: type:feature, area:rules, area:classification
**Implementation Strategy**: Three sequential commits in one PR (#19 -> #20 -> #21)

---

## ADR Alignment Decision

This spec follows **ADR-0003**, **ADR-0004**, and **ADR-0011** as the authoritative design. Six design choices are explicitly resolved here:

### Decision 1: Per-field override (Opción A)

Manual override protection is **per classification field**, not per record.

| What the GitHub issues implied | What the ADRs define |
|-------------------------------|----------------------|
| One `Classification` per posting | One `ClassificationRecord` per **transaction** |
| `source: :rule \| :manual` blocks the whole record | Per-field `*_manually_overridden` flags (e.g., `category_manually_overridden`) |
| If `source: :manual`, rules skip the whole posting | Rules skip only the manually-overridden **field**; other fields remain automatable |
| Single `rule_id` for the record | Per-field `*_classified_by` JSONB (records which rule set that specific field) |

**Why Opción A:** A user may accept the rule-assigned category but manually override tags. Per-field granularity makes this possible without all-or-nothing semantics. Firefly III–style full-record locks are simpler but destroy this use case.

### Decision 2: Expression + Actions JSONB on Rule (no separate condition/action tables)

Conditions are authored via a structured UI form but are **compiled to a single `expression :text` column on the `rules` table** before persisting. The structured form representation (field/operator/value tuples) is **transient UI state only** — it is not stored in the database.

Actions are stored as a **JSONB array on `rules.actions`** — there is no separate `rule_actions` table.

| Concern | This spec |
|---------|-----------|
| Condition persistence | `rules.expression :text` — AurumFinance's own DSL string, compiled from structured builder input |
| DSL ownership | `expression` is **AurumFinance's DSL**, not the syntax of any evaluation library. The engine translates DSL → internal evaluator at runtime. The stored string is never coupled to an external library's format. |
| Condition queryability | Expression is human-readable for debugging; not indexed or queried by the DB |
| Structured condition editing | **Create**: guided builder UI. **Edit**: raw expression editor (no builder reconstruction). v1 does not parse `expression` back into builder state. |
| Action persistence | `rules.actions :jsonb` — array of action maps |
| Action queryability | JSONB operators on `rules.actions` if needed |
| No `rule_conditions` table | Removed entirely |
| No `rule_actions` table | Removed entirely |

**Rationale for expression + JSONB:** Fewer tables, simpler migrations, simpler preloads. The engine translates `expression` to its internal evaluator at runtime — swapping the evaluator library (e.g., moving from a custom interpreter to Excellerate or any other) requires no migration or schema change. Actions as JSONB on the rule avoids a join for the common read path.

### Decision 3: Context is `AurumFinance.Classification`

Per ADR-0007, rules and classification live in the `AurumFinance.Classification` context (Tier 2). Not `AurumFinance.Rules`.

### Decision 4: Unified explicit scoped rule groups

This spec uses a **single `rule_groups` table/schema** with an explicit scope model:

- `scope_type: :global` with `entity_id = nil` and `account_id = nil`
- `scope_type: :entity` with `entity_id != nil` and `account_id = nil`
- `scope_type: :account` with `entity_id = nil` and `account_id != nil`

Both foreign keys may be nullable at the table level, but **scope is not inferred from nullability alone**. `scope_type` is the source of truth, and the valid FK combinations are enforced by both changesets and DB check constraints. `entity_id` and `account_id` are never both set.

| Model | This spec |
|-------|-----------|
| Separate tables per scope | Rejected |
| Implicit scope from nullable FKs only | Rejected |
| **Single table + explicit `scope_type`** | **Chosen** |

**Runtime meaning of each scope:**

| Scope | Matching behavior |
|-------|-------------------|
| `global` | Applies to all transactions |
| `entity` | Applies when `rule_group.entity_id == transaction.entity_id` |
| `account` | Applies when `rule_group.account_id` matches any posting account on the transaction |

**Rationale:**

1. **Keeps one coherent model** — no template tables, no duplicated schemas, no split CRUD/UI flows.
2. **Supports the real reuse cases cleanly** — some rules are truly global, some belong to one entity, some belong to one specific account.
3. **Preserves explicitness** — the scope is auditable and queryable as first-class data.
4. **Keeps account ownership normalized** — account-scoped groups derive entity ownership through the account relationship; they do not redundantly store `entity_id`.
5. **Avoids condition abuse** — `entity_*` or `account_*` conditions are not used to emulate ownership boundaries.

**What this means for condition fields:** `entity_name`, `entity_slug`, `entity_type`, `entity_country_code` as condition fields remain **out of scope for v1**. Ownership/targeting comes from `RuleGroup` scope, not from conditions.

### Decision 5: Scope precedence + group priority for deterministic conflict resolution

ADR-0003/0011 say groups execute *in parallel with no ordering between them*, relying on `target_fields` declarations to avoid conflicts. In practice, two groups can target the same field (e.g., both `set category`), and "undefined" conflict resolution is not auditable.

**This spec introduces deterministic final field selection with two layers of precedence:**

1. Scope precedence: **account-scoped groups first, then entity-scoped groups, then global groups**
2. Inside the same scope precedence: **`priority ASC`, then `name ASC`**

Groups are **independently evaluable** and may run concurrently. Rules **inside a group** remain sequential and ordered by `position ASC`, then `name ASC`. Final field selection happens in a deterministic merge phase.

For each classification field: **the first applicable proposal in the merge ordering wins. Subsequent proposals do not overwrite that field.**

This is "first-writer-wins per field, merged by scope precedence and then group priority."

| Model | Conflict behavior |
|-------|------------------|
| ADR-0011 "parallel, no order" | Undefined — depends on implementation order |
| "last group wins" | Deterministic but unintuitive (lower priority wins over higher) |
| **This spec: "first group wins per field"** | **Deterministic, intuitive, auditable** |

**Concrete example:**

```
Group 1 (priority: 1) — Expense Category → action: {field: "category", operation: "set", value: "<transport-account-uuid>"}
Group 2 (priority: 2) — Travel Override  → action: {field: "category", operation: "set", value: "<travel-account-uuid>"}

Transaction: Uber trip matching both groups
Result: category_account_id = <transport-account-uuid>  ← Group 1 wins; Group 2 skipped for category
        tags from Group 2 still applied if tags not yet set by Group 1
```

**Implementation:** The engine first selects all matching groups for the transaction:

- global groups
- entity groups where `entity_id == transaction.entity_id`
- account groups where `account_id` matches any posting account in the transaction

Those groups are independently evaluable. The deterministic merge phase then orders their field proposals by:

1. scope precedence `account > entity > global`
2. `priority ASC`
3. `name ASC`

Before accepting each field proposal, the merge phase checks: has this field already been claimed by a higher-precedence proposal in this evaluation pass? If yes, skip it. If no, accept it and mark the field as claimed for this pass.

**Audit:** `audit_events` records which group/rule set each field. Skipped groups are not logged (no-op). This makes the winning group explicit and queryable.

> This is another deliberate evolution of ADR-0011. `target_fields` is retained with **weak validation**: when a `RuleGroup` declares `target_fields`, any action within a rule in that group must target a field listed in `target_fields`. This is validated at rule creation/update time — not enforced by the evaluation engine at runtime. An empty `target_fields` means "unconstrained" (all action fields allowed).

### Decision 6: `category` is a FK to `accounts`, not a free string

ADR-0011 defined `category` as a plain string (e.g., `"Transport"`, `"Groceries"`). However, AurumFinance's chart of accounts already encodes category semantics: accounts with `management_group: :category` ARE the category list. There is no separate free-form category taxonomy.

**This spec uses `category_account_id` (UUID FK to `accounts`) everywhere:**

| Layer | ADR-0011 | This spec |
|-------|----------|-----------|
| `ClassificationRecord` | `category :string` | `category_account_id :binary_id FK` |
| Action `value` for `field: "category"` | any string | account UUID (stored as string in JSONB, resolved at evaluation) |
| Audit `old_value`/`new_value` in `audit_events` | string | account UUID for `category`; canonical JSON string for `tags` (e.g. `"[\"ride\"]"`); plain string for `investment_type`/`notes` |
| UI display | render the string | resolve UUID → account name |

**Rationale:**
- Enforces referential integrity — no dangling string categories that don't exist in the chart of accounts
- Eliminates spelling/casing inconsistencies (`"transport"` vs `"Transport"`)
- Aligns with how every other ledger reference works in the system
- Category accounts are already entity-scoped, so the FK implicitly validates entity scope

**Consequence for action storage:** An action's `value` in `rules.actions` JSONB remains a string, but for `field: "category"` the string must be a valid account UUID. The engine resolves it to the account at evaluation time and writes the UUID into `ClassificationRecord.category_account_id`. Invalid UUIDs fail safe (action skipped, warning logged).

**Consequence for display:** all UI rendering of `category_account_id` must join/resolve to `account.name`. The account name is the human-readable label shown to the user.

---

## Project Context

### Related Entities (Existing -- Read Only, Not Modified)

- `AurumFinance.Ledger.Transaction` - The transaction header that rules evaluate against
  - Location: `lib/aurum_finance/ledger/transaction.ex`
  - Key fields: `id`, `entity_id`, `date`, `description`, `source_type`, `voided_at`
  - Rules match on `description`, `date`; entity-scoped via `entity_id`
  - DB constraint: immutable core fields; only `voided_at` and `correlation_id` updatable

- `AurumFinance.Ledger.Posting` - The immutable posting leg; source of condition data (amount, account) for rule evaluation
  - Location: `lib/aurum_finance/ledger/posting.ex`
  - Key fields: `id`, `transaction_id`, `account_id`, `amount`
  - Rules evaluate conditions against posting fields (amount, account_name, etc.); classification output attaches to the **parent transaction**, not to the posting
  - DB constraint: fully append-only (trigger blocks ALL updates and deletes)

- `AurumFinance.Ledger.Account` - The account; rules can match on `account_id`
  - Location: `lib/aurum_finance/ledger/account.ex`
  - Key fields: `id`, `entity_id`, `name`, `account_type`, `management_group`, `currency_code`
  - Category accounts (`management_group: :category`) are the valid values for `field: "category"` actions
  - Account-scoped `RuleGroup`s attach directly to `account_id`; entity ownership is derived through the account relationship

- `AurumFinance.Entities.Entity` - Ownership boundary for entity-scoped rules and for transactions/classifications
  - Location: `lib/aurum_finance/entities/entity.ex`
  - Entity-scoped `RuleGroup`s attach directly to `entity_id`

- `AurumFinance.Ingestion.ImportedRow` - Imported row evidence with `description`, `amount`, `posted_on`
  - Location: `lib/aurum_finance/ingestion/imported_row.ex`
  - Key fields: `description`, `normalized_description`, `amount`, `posted_on`, `account_id`
  - Rules may eventually also run against imported rows pre-materialization (out of scope for v1)

### Existing UI Stub

- `AurumFinanceWeb.RulesLive` (`lib/aurum_finance_web/live/rules_live.ex`)
  - Currently a mock/placeholder with hardcoded data (`mock_rule_groups/0`)
  - Has existing component module: `lib/aurum_finance_web/components/rules_components.ex`
  - Components define `rule_group_item/1` and `rule_row/1` with mock map structures
  - Route: `live "/rules", RulesLive, :index`
  - Both the LiveView and components will be rewritten to use real data

- `AurumFinanceWeb.TransactionsLive` (`lib/aurum_finance_web/live/transactions_live.ex`)
  - Entity-scoped transaction listing with filters
  - Per-transaction detail view exists via `expanded_transaction_id` assign
  - Pattern to follow for per-transaction "apply rules" action (Issue #21)

### Auth and Permissions Model

- **Single-user root auth**: No role-based access control. Auth is binary (authenticated root or not).
- **Auth plug**: `AurumFinanceWeb.RootAuth` with `:require_authenticated_root` pipeline
- **LiveView on_mount**: `{AurumFinanceWeb.RootAuth, :ensure_authenticated}`
- **Entity isolation**: Ledger queries remain explicitly entity-scoped. Rule groups are explicitly scoped as `global`, `entity`, or `account`; account-scoped ownership derives through the related account.

### Naming Conventions Observed

- **Contexts**: `AurumFinance.Ledger`, `AurumFinance.Entities`, `AurumFinance.Ingestion`, `AurumFinance.Reconciliation`
- **Schemas**: `AurumFinance.Context.SchemaName` (e.g., `AurumFinance.Ledger.Transaction`)
- **LiveViews**: `AurumFinanceWeb.RulesLive` (flat, not nested in directories)
- **Components**: `AurumFinanceWeb.RulesComponents` (separate module per feature)
- **Context functions**: `list_*`, `get_*!`, `create_*`, `update_*`, `archive_*`, `change_*`
- **Filter pattern**: `list_*` accepts `opts` keyword list, dispatches to private multi-clause `filter_query/2`
- **Scope enforcement**: explicit scope validation in changesets/queries; do not infer scope only from nullable FKs
- **Ecto enums**: `Ecto.Enum, values: @some_list` with module attribute
- **Primary keys**: `@primary_key {:id, :binary_id, autogenerate: true}`
- **Timestamps**: `timestamps(type: :utc_datetime_usec)`
- **Changesets**: declare `@required` and `@optional`, cast both, validate required
- **i18n**: `dgettext("domain", "key")` pattern, errors via `dgettext("errors", "error_...")`
- **Audit**: context functions use `Audit.insert_and_log/2`, `Audit.update_and_log/3` etc.

### Product Invariants (from project_context.md)

These product invariants directly govern the rules engine design:

1. **Rules engine is grouped, not flat**: independent rule groups can match the same transaction simultaneously; first matching rule wins within each group; explainability is mandatory (group, rule, and field-level changes).
2. **Imported data split**: immutable facts (amount, date, description, account) vs. mutable classification (category, tags, notes).
3. **Manual edits protected**: manual user edits are protected from automation re-runs via **per-field** `*_manually_overridden` boolean flags on `ClassificationRecord`. Rules skip only the manually-overridden field — other fields on the same record remain automatable.

---

## Commit Strategy

| Commit | Issue | Scope | Depends On |
|--------|-------|-------|------------|
| **Commit 1** | #19 | Rules data model (schemas, migration, context CRUD, LiveView) | None |
| **Commit 2** | #20 | Rules runner preview/dry-run (engine, preview API, preview UI) | Commit 1 |
| **Commit 3** | #21 | Classification layer (schema, apply rules, manual overrides, bulk apply) | Commit 1 + 2 |

---

## Issue #19 -- Rules Data Model

### New Entities

- `AurumFinance.Classification` - **New context** (Tier 2 per ADR-0007) owning rule groups, rules, classification records, and the rules engine
  - Location: `lib/aurum_finance/classification.ex`

- `AurumFinance.Classification.RuleGroup` - Independent classification dimension grouping ordered rules
  - Location: `lib/aurum_finance/classification/rule_group.ex`
  - Table: `rule_groups`
  - Fields: `id`, `scope_type` (`:global | :entity | :account`), `entity_id` (nullable), `account_id` (nullable), `name`, `description` (text, nullable), `priority` (integer — group execution order for conflict resolution inside the same scope), `target_fields` (Postgres array of strings, e.g. `["category"]` or `["tags"]`, default `[]`), `is_active` (boolean, default true), `inserted_at`, `updated_at`
  - Note: valid scope combinations are enforced explicitly. `priority` determines execution order inside the same scope precedence bucket (Decision 5). `target_fields` enforces weak validation: when non-empty, any action in a rule within this group must target a field listed here. Empty `target_fields` = unconstrained. Validation fires at rule creation/update, not at engine evaluation time.

- `AurumFinance.Classification.Rule` - A named condition-action unit within a group
  - Location: `lib/aurum_finance/classification/rule.ex`
  - Table: `rules`
  - Fields: `id`, `rule_group_id`, `name`, `description` (text, nullable), `position` (integer, ascending; lower = higher priority within group), `is_active` (boolean, default true), `stop_processing` (boolean, default true — implements first-match-wins), `expression` (text, NOT NULL — compiled from structured condition input), `actions` (JSONB, NOT NULL — array of action maps), `inserted_at`, `updated_at`
  - Note: `expression` is the compiled form of user-authored conditions. `actions` is an inline JSONB array. There are no separate `rule_conditions` or `rule_actions` tables.

### Condition Model

Conditions are **authored via a structured UI form** (field / operator / value / negate tuples) but **persisted as a single compiled `expression` text column** on the `rules` table. The structured tuple representation is **transient UI state only** — it is never stored in the database.

**Rule authoring UX (v1):**

| Operation | UI |
|-----------|-----|
| **Create** | Guided builder: rows of field / operator / value / negate. Builder compiles to `expression` on save. Backend validates `expression` before persisting; invalid → rejected, not saved. |
| **Edit** | Raw expression editor showing the stored `expression` string + `actions` JSONB. No builder reconstruction from expression. |
| **Delete** | Always permitted. |

v1 does **not** implement bidirectional parsing (expression → builder state). Users who need to restructure a rule significantly should delete and recreate it using the builder.

**Edit mode UX notice** (displayed above the raw editor):

> _Advanced mode. Editing the expression directly may make the rule invalid. Invalid expressions are rejected on save — the rule will not be updated until the expression is fixed._

**Validation contract:** the backend validates `expression` on every create and update. If validation fails, the rule is not saved and a clear error is returned. Saving an invalid expression is not permitted — there is no "broken rule" state in production.

**AurumFinance expression DSL (v1):**

```
description contains "Uber"
description starts_with "AMZN"
amount < -100
abs_amount >= 50
account_name equals "Checking"
description matches_regex "^UBER.*"
NOT (description contains "ATM")
(description contains "Uber") AND (amount < 0)
```

- This is **AurumFinance's own DSL format**, not the syntax of any internal evaluation library.
- The engine contains a translation layer: DSL string → internal evaluator representation. The DSL is compiled to the internal evaluator representation during rule validation. The concrete evaluator backend is intentionally hidden behind an AurumFinance-owned adapter/wrapper so it can be swapped later without migration or schema change. An initial backend may use **Excellerate** (user-provided reference: `geofflane/excellerate`, release `0.3.0`), but the stored DSL is never coupled to that package.
- Multiple conditions are joined by `AND` in the compiled expression (OR logic = multiple rules with the same actions)
- `negate: true` on a single builder row wraps the condition in `NOT (...)`

#### Supported Condition Fields

| `field` value | Source | Type | Description |
|--------------|--------|------|-------------|
| `description` | Transaction | string | Original transaction description |
| `amount` | Posting | decimal | Posting amount (signed) |
| `abs_amount` | Posting | decimal | Absolute value of posting amount |
| `currency_code` | Posting/account | string | Currency of the posting, derived from `posting.account.currency_code` |
| `date` | Transaction | date | Transaction date |
| `source_type` | Transaction | string | How transaction was created (import/manual/system) |
| `account_name` | Account | string | Name of the posting's account |
| `account_type` | Account | string | Type of the posting's account |
| `institution_name` | Account | string | Institution name of the posting's account |

Note on multi-posting transactions: condition fields that reference postings are evaluated against **each posting independently**. If any posting satisfies all conditions, the rule matches. Classification is applied at the **transaction level** (not per-posting).
`memo` is explicitly out of scope for v1 because the current `Transaction` schema does not expose it.

#### Supported Operators

| `operator` value | Applicable types | Description |
|-----------------|-----------------|-------------|
| `equals` | string, decimal, date | Exact match (case-insensitive for strings) |
| `contains` | string | Substring match (case-insensitive) |
| `starts_with` | string | Prefix match (case-insensitive) |
| `ends_with` | string | Suffix match (case-insensitive) |
| `matches_regex` | string | Regular expression match |
| `greater_than` | decimal, date | `>` comparison |
| `less_than` | decimal, date | `<` comparison |
| `greater_than_or_equal` | decimal, date | `>=` comparison |
| `less_than_or_equal` | decimal, date | `<=` comparison |
| `is_empty` | string | Null or empty string (value field ignored) |
| `is_not_empty` | string | Not null and not empty (value field ignored) |

Operator and field names appear as keywords in the expression DSL. Invalid type combinations fail safe (condition does not match) rather than crash.

**At least one condition is required per rule.** The context validates that the compiled `expression` is non-empty before persisting.

### Action Model

Actions are stored as a **JSONB array** on `rules.actions`. Each element in the array is an action map. There is no separate `rule_actions` table.

**Action map schema:**

```json
[
  {"field": "category", "operation": "set", "value": "<account-uuid>"},
  {"field": "tags",     "operation": "add", "value": "ride"}
]
```

#### Target Fields

| `field` value | Type | Description |
|--------------|------|-------------|
| `category` | uuid | Account UUID — must reference an `Account` with `management_group: :category` in the same entity. Stored as string in actions JSONB; resolved to FK at evaluation time. |
| `tags` | list of strings | Transaction tags |
| `investment_type` | string | Investment classification (e.g., "ETF", "Bond") |
| `notes` | string | Classification notes / friendly description |

#### Operations

| `operation` | Applicable fields | Description |
|------------|------------------|-------------|
| `set` | category, investment_type, notes | Replace the field value entirely |
| `add` | tags | Add value to existing list (no duplicates) |
| `remove` | tags | Remove value from existing list |
| `append` | notes | Append value to existing notes (newline separated) |

Note: The GitHub issues mentioned a `skip` action type. Explicitly excluded — leaving a field unset is the natural way to express no classification for a dimension.

**At least one action is required per rule.** The context validates that `actions` is a non-empty array before persisting.

#### Action Embedded Schema

Each element of `rules.actions` JSONB is validated via an `embedded_schema` before the rule is persisted:

```elixir
embedded_schema do
  field :field,     Ecto.Enum, values: [:category, :tags, :investment_type, :notes]
  field :operation, Ecto.Enum, values: [:set, :add, :remove, :append]
  field :value,     :string
end
```

**Changeset validations:**

| Condition | Rule |
|-----------|------|
| `field`, `operation`, `value` | all required |
| `field: :category` | `operation` must be `:set`; `value` must be a valid UUID resolving to an `Account` with `management_group: :category` in the same entity |
| `field: :tags` | `operation` must be `:add` or `:remove` |
| `field: :notes` | `operation` must be `:set` or `:append` |
| `field: :investment_type` | `operation` must be `:set` |

Invalid action maps reject the entire rule changeset with an inline error. Actions are not persisted individually — the full `actions` array is atomic with the rule.

### Evaluation Semantics (ADR-0011 §5 + §8)

1. **Groups are independently evaluable and may run concurrently.** Only `is_active: true` groups participate.
2. **Rules inside a group remain sequential and ordered** by `position ASC`, then `name ASC`. Only `is_active: true` rules participate.
3. **First matching rule wins within a group** when `stop_processing: true` (the default). Setting `stop_processing: false` allows additive rules inside the same group (e.g., multiple tag rules in the same group all contribute).
4. The engine selects matching groups for a transaction using the unified scope model:
   - global groups
   - entity-scoped groups matching `transaction.entity_id`
   - account-scoped groups matching any posting account on the transaction
5. **Final field selection happens in a deterministic merge phase** over field proposals produced by matching groups. Merge precedence is:
   - `account > entity > global`
   - `priority ASC`
   - `name ASC`
6. **Field-level conflict resolution:** for each classification field, the first applicable proposal in that merge ordering claims the field. Subsequent proposals do not overwrite an already-claimed field during this evaluation pass. Non-conflicting fields (different target fields) always compose freely.
7. **Classification is at the transaction level** — `ClassificationRecord` is keyed on `transaction_id`. When a transaction has multiple postings, conditions reference posting fields (amount, account_name) but the output record is per-transaction.
8. **At least one condition is required per rule** (v1 constraint). Zero-condition catch-all rules are deferred — they add engine complexity and are easy to misconfigure.
9. **Manual override guard** (per ADR-0004): before accepting each field proposal, check `ClassificationRecord[field + "_manually_overridden"]`. If `true`, skip that field — do not overwrite. Other fields from the same rule/group may still apply. Manual overrides take precedence over even the highest-precedence scoped proposal.

### User Stories -- Issue #19

#### US-1: Create a Rule Group

As an **authenticated root user**, I want to create a rule group with a name, priority, and optional notes, so that I can organize my classification rules into logical categories.

#### US-2: Edit a Rule Group

As an **authenticated root user**, I want to edit a rule group's name, priority, active status, and notes, so that I can adjust my rule organization over time.

#### US-3: Delete a Rule Group

As an **authenticated root user**, I want to delete a rule group (and its contained rules), so that I can remove obsolete rule categories.

#### US-4: Create a Rule Within a Group

As an **authenticated root user**, I want to create a rule with a name, position, one or more conditions (authored in a structured builder), and one or more actions inside a group, so that I can define specific classification logic.

#### US-5: Edit a Rule

As an **authenticated root user**, I want to edit a rule's name, position, conditions, actions, and active status, so that I can refine my classification logic.

#### US-6: Delete a Rule

As an **authenticated root user**, I want to delete a rule from a group, so that I can remove rules that are no longer needed.

#### US-7: View Rules Ordered by Visible Precedence

As an **authenticated root user**, I want to see visible rule groups ordered by scope precedence and then group priority, and rules within each group ordered by rule priority, so that I can understand the effective evaluation order at a glance.

#### US-8: Toggle Rule/Group Active Status

As an **authenticated root user**, I want to toggle a rule or group between active and inactive without deleting it, so that I can temporarily disable classification logic.

### Acceptance Criteria -- Issue #19

#### US-1: Create a Rule Group

**Scenario: Happy path**
- **Given** I am on the Rules page
- **When** I click "New Group", enter name "Expense Category", priority 10, and notes "Categorize daily expenses"
- **Then** a `RuleGroup` is created with `active: true` (default) and appears in the groups list ordered by priority

**Criteria Checklist:**
- [ ] Form requires: `name` (string, 2-160 chars), `priority` (positive integer)
- [ ] Scope selected explicitly by user: `global`, `entity`, or `account`
- [ ] Optional: `description` (text), `target_fields` (list of classification fields: `category`, `tags`, `investment_type`, `notes`; default empty = unconstrained), `is_active` (boolean, defaults to true)
- [ ] If `target_fields` is non-empty, any action added to a rule in this group must target a field listed in `target_fields` — validated at rule creation/update with inline error "Action field '{field}' is not declared in this group's target fields"
- [ ] Target FK is set according to the selected scope: `global` => no FK, `entity` => `entity_id`, `account` => `account_id`
- [ ] Name uniqueness is enforced within the same scope target:
  `global` => unique by name among globals
  `entity` => unique by (`entity_id`, `name`)
  `account` => unique by (`account_id`, `name`)
- [ ] On success: flash message, group appears in list ordered by visible precedence
- [ ] On validation error: inline form errors
- [ ] Audit event emitted: `entity_type: "rule_group"`, `action: "created"`

#### US-4: Create a Rule Within a Group

**Scenario: Happy path**
- **Given** I have selected rule group "Expense Category"
- **When** I click "Add Rule", enter name "Uber rides", position 1, add condition `{field: "description", operator: "contains", value: "Uber"}` via the builder, add action `{field: "category", operation: "set", value: "<transport-account-uuid>"}` (selected from category account picker)
- **Then** a `Rule` is created with `expression: "description contains \"Uber\""`, `actions: [{"field":"category","operation":"set","value":"<transport-account-uuid>"}]`, and appears in the group's rules table at position 1

**Criteria Checklist:**
- [ ] Form requires: `name` (string, 2-160 chars), `position` (positive integer)
- [ ] Optional: `description` (text), `is_active` (boolean, defaults to true), `stop_processing` (boolean, defaults to true)
- [ ] Condition input via **builder UI** (create only): rows of field / operator / value / negate — no raw text input on create
- [ ] Builder compiles structured input to `expression` before submitting to backend
- [ ] Backend validates `expression` before persisting; invalid expression → rejected with inline error, rule not created
- [ ] At least one condition required (validated server-side: `expression` must be non-empty and valid)
- [ ] At least one action required (UI form; stored as `actions` JSONB array, validated server-side)
- [ ] `rule_group_id` and entity scope set programmatically
- [ ] `field`/`operator` combinations validated for type compatibility (e.g., `matches_regex` only applies to string fields)
- [ ] `matches_regex` operator: `value` must be a valid regex — validated at creation time, not at evaluation time
- [ ] For `field: "category"` actions: `value` must be a UUID resolving to an `Account` with `management_group: :category` in the current entity
- [ ] On success: rule appears in group detail at correct `position` order; condition summary and action summary shown in rule row
- [ ] On validation error: inline form errors

#### US-5: Edit a Rule

**Scenario: Edit expression via raw editor**
- **Given** I have rule "Uber rides" with `expression: "description contains \"Uber\""`
- **When** I click "Edit Rule", modify the expression to `description contains "Uber" AND amount < 0`, and save
- **Then** the backend validates the expression, it is valid, and the rule is updated

**Scenario: Save invalid expression**
- **Given** I am editing rule "Uber rides" in raw expression mode
- **When** I enter a malformed expression (e.g., `description ??? "Uber"`) and click Save
- **Then** the save is rejected with an inline error "Invalid expression: unexpected token '???'"
- **And** the rule is unchanged

**Criteria Checklist:**
- [ ] Edit form shows the stored `expression` as a raw text field (no builder reconstruction)
- [ ] Edit form shows `actions` JSONB for editing (same action builder rows as create)
- [ ] "Advanced mode" notice displayed above the expression editor: _"Editing the expression directly may make the rule invalid. Invalid expressions are rejected on save."_
- [ ] Backend validates `expression` on every update; invalid → rejected, rule unchanged, inline error shown
- [ ] On success: rule row updates inline with new condition summary

#### US-7: View Rules Ordered by Visible Precedence

**Scenario: Multiple groups and rules**
- **Given** I have visible groups across multiple scopes, such as account-scoped "Checking Overrides" (priority 20), entity-scoped "Expense" (priority 10), and global "Investment" (priority 5), each with multiple rules
- **When** I view the Rules page
- **Then** "Checking Overrides" appears before "Expense", and "Expense" appears before "Investment" in the groups list
- **And** within each group, rules are ordered by ascending position number
- **And** inactive groups/rules show a distinct visual indicator (dimmed or badge)

**Criteria Checklist:**
- [ ] Visible groups list ordered by scope precedence `account > entity > global`, then `priority ASC`, then `name ASC` as tiebreaker
- [ ] Rules within selected group ordered by `position ASC`, then `name ASC` as tiebreaker
- [ ] Inactive groups shown with muted styling and "Inactive" badge
- [ ] Inactive rules shown with muted styling in the rules table
- [ ] Each rule row displays: position number, human-readable condition summary (derived from `expression`), human-readable action summary (derived from `actions` JSONB), `is_active` status, `stop_processing` indicator

---

## Issue #20 -- Rules Runner Preview/Dry-Run

### New Modules

- `AurumFinance.Classification.Engine` - Pure-function rules evaluation engine
  - Location: `lib/aurum_finance/classification/engine.ex`
  - Stateless; receives rule groups (with preloaded rules) and transactions (with preloaded postings and accounts), returns match results
  - Evaluates `rule.expression` against transaction/posting/account data at runtime
  - Parses `rule.actions` JSONB to determine field assignments
  - No DB writes

### Preview API

The context exposes a preview function:

```
Classification.preview_classification(opts)
```

- Input options: `entity_id` (required), optional `date_from`, `date_to`
- Internally loads: all active rule groups for the entity (with rules preloaded); transactions in range (with postings and accounts); existing `ClassificationRecord`s
- Output: list of `%ClassificationPreview{}` structs, one per transaction:
  - `transaction` — the transaction
  - `existing_classification` — current `ClassificationRecord` or nil
  - `proposed_changes` — list of `%{rule_group, rule, field, proposed_value, currently_overridden?}`
  - `no_match?` — true if no group matched
- A transaction may have zero matches (no group fired) or multiple matches (one per group that matched)
- **No DB writes occur during preview** — engine is pure-function (`Classification.Engine.evaluate/2`)

### User Stories -- Issue #20

#### US-9: Preview Rules Against Transactions

As an **authenticated root user**, I want to run a dry-run of all active rules against a set of transactions and see what would change, so that I can verify my rules before committing classifications.

#### US-10: View Diff of Current vs. Proposed Classification

As an **authenticated root user**, I want to see a side-by-side comparison of current classification (if any) vs. proposed classification from rules, so that I can understand the impact before applying.

#### US-11: Preview With No Matching Rules

As an **authenticated root user**, I want to see which transactions have no matching rules in the preview, so that I can identify gaps in my rule coverage.

### Acceptance Criteria -- Issue #20

#### US-9: Preview Rules Against Transactions

**Scenario: Happy path -- rules match some transactions**
- **Given** I have active rule group "Expense" with rule "Uber": `expression: "description contains \"Uber\""`, `actions: [{"field":"category","operation":"set","value":"<transport-account-uuid>"}]`
- **And** I have 5 transactions, 2 of which contain "Uber" in the description
- **When** I click "Preview Rules" on the Rules page
- **Then** I see a preview table showing all 5 transactions
- **And** the 2 Uber transactions show proposed change: `category → "Transport"` (account name resolved for display) with the matched rule name and group name
- **And** the 3 non-matching transactions show "No match"

**Scenario: Multiple groups match same transaction**
- **Given** I have rule group "Expense" (priority 1) with rule "Uber": `expression: "description contains \"Uber\""`, action `{field: "category", value: "<transport-account-uuid>"}`
- **And** I have rule group "Tagging" (priority 2) with rule "Uber tag": same expression, action `{field: "tags", operation: "add", value: "ride"}`
- **When** I preview rules
- **Then** the Uber transaction shows two proposed changes: `category → "Transport"` from "Expense" group AND `tags +["ride"]` from "Tagging" group
- **And** the explainability shows which group and rule produced each proposed action

**Criteria Checklist:**
- [ ] Preview loads all active rule groups (with rules) for the current entity
- [ ] Preview loads transactions with preloaded postings and accounts for the current entity (with optional date range filter; date range required to prevent unbounded loads)
- [ ] Each transaction row shows: date, description, amounts per posting, account names
- [ ] Each transaction shows matched rule(s) grouped by rule group, or "No match"
- [ ] For each match: display group name, rule name, and proposed field changes in human-readable form (e.g., "category → Transport" where "Transport" is `account.name` resolved from the stored UUID)
- [ ] No database writes occur during preview (engine is pure-function)
- [ ] Preview date range is required (same as apply — no unbounded loads)
- [ ] Loading state shown while preview is computing

#### US-10: View Diff of Current vs. Proposed

**Scenario: Transaction has a manually-overridden field**
- **Given** a transaction has a `ClassificationRecord` with `category_account_id: <food-account-uuid>` (displayed as "Food") and `category_manually_overridden: true`
- **When** I preview rules and a rule in group "Expense" proposes `category_account_id: <transport-account-uuid>` (displayed as "Transport")
- **Then** the diff view shows for `category`: Current = "Food (manual — protected)", Proposed = "Transport (rule: Uber)" with a lock icon
- **And** other fields (tags, notes) that are NOT manually overridden show their proposed changes normally

**Scenario: Transaction has no existing classification**
- **Given** a transaction has no `ClassificationRecord`
- **When** I preview rules and a rule proposes `category_account_id: <transport-account-uuid>`
- **Then** the diff view shows: Current = "(unclassified)", Proposed = "Transport (rule: Uber)" (account name resolved for display)

**Criteria Checklist:**
- [ ] Diff view is **per-field**: each classification field (category, tags, investment_type, notes) shown separately
- [ ] For each field: show current value + provenance (`*_classified_by` source), proposed value + rule name
- [ ] Fields with `*_manually_overridden: true` shown with lock icon and "protected — will not be overwritten" indicator
- [ ] A manually-overridden field being "protected" does NOT block other fields on the same transaction from being proposed
- [ ] New classifications (no existing record) shown as additions
- [ ] Changed classifications shown with before/after comparison per field

---

## Issue #21 -- Apply Rules to Transactions (Classification Layer)

### New Entities

- `AurumFinance.Classification.ClassificationRecord` - Mutable classification overlay per transaction (ADR-0011 §4)
  - Location: `lib/aurum_finance/classification/classification_record.ex`
  - Table: `classification_records`
  - One record per transaction (unique on `transaction_id`)
  - Per-field provenance: for each classification field, three columns exist:
    - `{field}` — the value (`category_account_id :binary_id FK`; `tags :jsonb`; `investment_type :string`; `notes :text`)
    - `{field}_classified_by` — JSONB provenance: `%{source: "rule", rule_group_id: ..., rule_id: ..., classified_at: ...}` or `%{source: "user", classified_at: ...}` or `nil`
    - `{field}_manually_overridden` — boolean, `false` by default
  - Fields: `id`, `transaction_id` (FK, unique), `entity_id` (denormalized), `category_account_id` (FK to accounts, nullable), `category_classified_by` (JSONB), `category_manually_overridden` (boolean), `tags`, `tags_classified_by`, `tags_manually_overridden`, `investment_type`, `investment_type_classified_by`, `investment_type_manually_overridden`, `notes`, `notes_classified_by`, `notes_manually_overridden`, `inserted_at`, `updated_at`
  - Note: provenance columns use the concept name prefix (`category_*`) even though the value column is `category_account_id`. Keeps the pattern consistent: `{concept}_classified_by`, `{concept}_manually_overridden`.

### Classification Semantics (ADR-0011 §4 + §5)

1. One `ClassificationRecord` per transaction (unique on `transaction_id`)
2. Override protection is **per field**: `category_manually_overridden: true` protects only the `category` field — `tags` and `notes` remain automatable on the same record
3. **Manual override set flow**: user sets a field → `{field}_manually_overridden = true`, `{field}_classified_by = %{source: "user", classified_at: ...}`
4. **User clears override**: `{field}_manually_overridden = false`, value retained — next rule run can re-classify that field
5. **Rule apply flow**: for each action in matched rule, check `{field}_manually_overridden`. If `true`: skip. If `false`: apply value, set `{field}_classified_by = %{source: "rule", rule_group_id: ..., rule_id: ...}`, emit `audit_events` entry
6. When applying rules: if no `ClassificationRecord` exists for the transaction, create one (upsert)

### Classification Audit

Classification field changes are recorded to the **existing `audit_events` table** — no separate `ClassificationAuditLog` table or schema.

**When an audit event is written:**

| Trigger | `entity_type` | `action` | Metadata |
|---------|---------------|----------|----------|
| Rule apply (bulk or single) changes a field | `"classification_record"` | `"rule_applied"` | `field`, `old_value`, `new_value`, `rule_group_id`, `rule_id` |
| User manually sets a field | `"classification_record"` | `"manual_override"` | `field`, `old_value`, `new_value` |
| User clears a manual override | `"classification_record"` | `"override_cleared"` | `field` |

**What is NOT logged:**
- Fields skipped because `*_manually_overridden: true` — no entry (override protection is silent)
- Groups that matched but whose field action was skipped due to conflict resolution (lower-priority group already claimed the field) — no entry
- Fields that were evaluated but unchanged (same value) — no entry

**One `audit_events` entry per field per classification event.** A single `classify_transaction/1` call that sets both `category` and `tags` writes two `audit_events` rows.

**`old_value`/`new_value` serialization in metadata:**
- Scalar fields (`category_account_id`, `investment_type`, `notes`): stored as plain string (account UUID for `category`)
- List fields (`tags`): stored as canonical JSON string (e.g., `"[\"ride\",\"uber\"]"`)

**Query patterns supported via `audit_events`:**
- "Show me the full classification history of this transaction" — filter by `entity_id` + `entity_type: "classification_record"` + correlate on transaction metadata
- "What changed in the last bulk apply?" — filter by `entity_id` + `action: "rule_applied"` + `inserted_at` window
- "Did anything overwrite a previous classification?" — find rows where metadata `old_value` is present

### Apply API

```
Classification.classify_transactions(opts)
```

- Input options: `entity_id` (required), `date_from` and `date_to` (required)
- Behavior: loads all active rule groups + transactions in range; evaluates engine; upserts `ClassificationRecord` per transaction (skipping per-field manual overrides); writes `audit_events` entry for each changed field
- Returns: `{:ok, %{classified: count, fields_applied: count, fields_skipped_manual: count, no_match: count}}`
- Also exposes: `Classification.classify_transaction(transaction, opts)` for single-transaction apply

```
Classification.set_manual_classification(transaction_id, field, value, opts)
```

- Sets a specific classification field manually
- Sets `{field}_manually_overridden = true`, `{field}_classified_by = %{source: "user", ...}`
- Writes `audit_events` entry

### User Stories -- Issue #21

#### US-12: Apply Rules to Unclassified Transactions in Date Range

As an **authenticated root user**, I want to bulk-apply all active rules to unclassified transactions within a date range, so that I can efficiently classify a batch of imported transactions.

#### US-13: Apply Rules to a Single Transaction

As an **authenticated root user**, I want to apply rules to a single transaction from the transaction detail view, so that I can classify individual transactions on demand.

#### US-14: Manual Classification Override

As an **authenticated root user**, I want to manually set a classification on a transaction (category, tags, notes), so that I can override or supplement rule-based classification.

#### US-15: Manual Classifications Protected from Rule Runs

As an **authenticated root user**, I want my manual classifications to be preserved when I re-run rules, so that my deliberate overrides are never lost.

#### US-16: View Per-Field Classification Provenance

As an **authenticated root user**, I want to see, per classification field, whether the value was set by a rule (and which rule/group) or manually set, and whether it is currently locked from automation, so that I have full per-field explainability.

### Acceptance Criteria -- Issue #21

#### US-12: Bulk Apply Rules

**Scenario: Happy path -- apply to unclassified transactions**
- **Given** I have 20 unclassified transactions in March 2026 and active rules that match 15 of them
- **When** I select date range 2026-03-01 to 2026-03-31 and click "Apply Rules"
- **Then** 15 `ClassificationRecord`s are created/updated with classification values and `{field}_classified_by` set to the matching rule provenance
- **And** 5 transactions remain unclassified (no group matched)
- **And** I see a summary: "Classified: 15, No match: 5"

**Scenario: Re-run with a manually-overridden field**
- **Given** transaction T has `ClassificationRecord` with `category_account_id: <food-uuid>` (displayed as "Food"), `category_manually_overridden: true`, `tags: []`, `tags_manually_overridden: false`
- **And** a rule matches T proposing `category_account_id: <transport-uuid>` and `tags: ["ride"]`
- **When** I bulk-apply rules for the date range
- **Then** `category_account_id` stays `<food-uuid>` (manually overridden — skipped)
- **And** `tags` is updated to `["ride"]` (not manually overridden — applied)
- **And** the summary shows "Fields applied: 1, Fields skipped (manual override): 1"

**Scenario: Re-run updates stale rule classifications**
- **Given** a transaction has `ClassificationRecord` with `category_account_id: <food-uuid>` (displayed as "Food"), `category_manually_overridden: false`, `category_classified_by: %{source: "rule", rule_id: old_rule}`
- **And** the rules have been updated so a different rule now matches with `category_account_id: <transport-account-uuid>`
- **When** I bulk-apply rules
- **Then** `category_account_id` is updated to `<transport-account-uuid>`, `category_classified_by` updated with new rule provenance

**Criteria Checklist:**
- [ ] Date range filter required (no unbounded bulk apply)
- [ ] Entity scope enforced via `entity_id`
- [ ] Only transactions from non-voided entries are considered
- [ ] Per-field override guard: `{field}_manually_overridden: true` fields are skipped; other fields on same record are still processed
- [ ] Upsert pattern for `ClassificationRecord` (one per transaction)
- [ ] `audit_events` entry written for each field that changes (old_value, new_value, rule provenance in metadata)
- [ ] Transactions where no group matches: no record created / existing record unchanged, counted as "no match"
- [ ] Operation is atomic per-transaction (individual failures do not roll back the entire batch)
- [ ] Summary returned: `classified`, `fields_applied`, `fields_skipped_manual`, `no_match` counts
- [ ] Audit event emitted for the bulk apply operation with metadata (date range, counts)

#### US-13: Apply Rules to Single Transaction

**Scenario: Apply from transaction detail**
- **Given** I am viewing transaction "Uber trip" in the transactions list (expanded detail view)
- **When** I click "Apply Rules" on that transaction
- **Then** rules are evaluated for that transaction's postings
- **And** the `ClassificationRecord` for that transaction is created/updated (respecting per-field manual overrides)
- **And** I see the resulting per-field classification inline

**Criteria Checklist:**
- [ ] Action available in transaction detail view (expanded row in TransactionsLive)
- [ ] Respects per-field manual override protection
- [ ] Shows resulting classification (per field) immediately after apply
- [ ] If no group matches, shows "No matching rules"

#### US-14: Manual Classification Override

**Scenario: Set manual classification on a specific field**
- **Given** I am viewing a transaction's classification (expanded detail view)
- **When** I select "Groceries" from the category account picker and save
- **Then** the `ClassificationRecord` is upserted with `category_account_id: <groceries-account-uuid>`, `category_classified_by: %{source: "user", ...}`, `category_manually_overridden: true`
- **And** `tags` and `notes` on the same record are unaffected
- **And** subsequent rule runs will not overwrite `category` (but will still process `tags` and `notes` if not manually overridden)

**Criteria Checklist:**
- [ ] Each field (category, tags, investment_type, notes) can be manually set independently
- [ ] `category` input is a **picker** (not free text) showing only accounts with `management_group: :category` for the current entity; stores selected `account.id` as `category_account_id`
- [ ] Setting a field manually sets `{field}_manually_overridden: true`
- [ ] Tags input allows free-form tag entry; saving sets `tags_manually_overridden: true`
- [ ] Notes field is optional free text
- [ ] User can explicitly clear a manual override: sets `{field}_manually_overridden: false`, value retained
- [ ] `audit_events` entry written for each changed field
- [ ] Clearing a field value (setting to nil/empty) AND clearing `manually_overridden` is distinct from just clearing the override

#### US-15: Manual Override Protection

**Scenario: Rules skip only the manually-overridden field**
- **Given** transaction has `ClassificationRecord` with `category_account_id: <personal-uuid>` (displayed as "Personal"), `category_manually_overridden: true`, `tags: []`, `tags_manually_overridden: false`
- **When** I run bulk apply and a rule matches proposing `category_account_id: <transport-uuid>` and `tags: ["personal"]`
- **Then** `category_account_id` remains `<personal-uuid>` (manually overridden — skipped)
- **And** `tags` is updated to `["personal"]` (not manually overridden — applied)

**Criteria Checklist:**
- [ ] Override guard is per-field: `{field}_manually_overridden: true` only protects that specific field
- [ ] Engine check per action: `if classification_record[field <> "_manually_overridden"] == true, skip this action`
- [ ] This per-field protection applies to both bulk apply and single-transaction apply
- [ ] Preview (Issue #20) shows per-field "protected" indicator but still shows what the rule would propose for that field
- [ ] User can explicitly clear override for a field to re-enable automation for it

---

#### US-16: View Per-Field Classification Provenance

**Scenario: Transaction detail shows full per-field provenance**
- **Given** transaction T has `ClassificationRecord` with: `category_account_id: <transport-uuid>` (displayed as "Transport") set by rule "Uber" in group "Expense" (automated), `tags: ["personal"]` set manually (overridden), `notes: nil` (unclassified)
- **When** I view the transaction detail
- **Then** the UI shows:
  - `category`: "Transport" (resolved from `category_account_id`) | Rule: "Uber" (Expense group) | `[clear override not shown]`
  - `tags`: ["personal"] | Manual | 🔒 locked | `[Clear lock]` action
  - `notes`: (unclassified) | `[Set manually]` action

**Scenario: View full classification history for a transaction**
- **Given** transaction T has been classified twice: first by rule "Uber" setting `category_account_id = <transport-uuid>`, then manually overridden to `<food-uuid>`
- **When** I view the classification history for T (via `audit_events` filtered by this transaction's classification record)
- **Then** I see two entries in order (UUIDs resolved to account names for display):
  1. `action: rule_applied`, `field: category`, `old: nil`, `new: "<transport-uuid>"` (shown as "Transport"), `rule: Uber / Expense`, timestamp T1
  2. `action: manual_override`, `field: category`, `old: "<transport-uuid>"` (shown as "Transport"), `new: "<food-uuid>"` (shown as "Food"), timestamp T2

**Criteria Checklist:**
- [ ] Transaction detail shows `{field}_classified_by` provenance inline for each classification field
- [ ] Rule-classified fields show: group name + rule name + `classified_at` (from `*_classified_by` JSONB)
- [ ] Manually-classified fields show: "Manual" badge + lock icon + `classified_at`
- [ ] Unclassified fields shown explicitly as "(unclassified)" — not hidden
- [ ] "Clear override" action visible on manually-overridden fields
- [ ] Classification history view available per transaction showing `audit_events` entries (filtered by classification record, ordered by `inserted_at ASC`)
- [ ] Each history entry shows: field, old value, new value, source (rule name or "manual"), timestamp
- [ ] History entries for rule-based changes reference the rule name with graceful "rule deleted" fallback

---

## Edge Cases

### Empty States

- [ ] No rule groups exist -> Show "No rule groups yet" with CTA to create one
- [ ] Selected group has no rules -> Show "No rules in this group" with CTA to add a rule
- [ ] Preview returns no matches for any transaction -> Show "No rules matched any transaction in this range"
- [ ] No unclassified transactions in date range -> Show "All transactions in this range are already classified"
- [ ] No transactions exist at all -> Show "No transactions to classify"
- [ ] No category accounts exist -> Block creation of an action with `field: "category"` with message "Create category accounts first"

### Error States

- [ ] Invalid regex in `matches_regex` condition -> Reject at rule creation with inline error "Invalid regular expression"
- [ ] Action with `field: "category"` — `value` must be a UUID resolving to an `Account` with `management_group: :category` in the same entity; reject at rule creation with validation error "Category account not found". Show warning on existing rules if the account is archived after creation.
- [ ] Condition with `field: "account_name"` and a value that matches no account -> Allowed (no DB FK on condition values); rule simply won't match
- [ ] Bulk apply fails partway through -> Individual transaction failures do not roll back other transactions; report partial results
- [ ] Rule group name conflict (duplicate within the same scope target) -> Show "A group with this name already exists in this scope"

### Permission/Scope

- [ ] Unauthenticated user -> Redirect to `/login` (existing pattern)
- [ ] Rules use explicit `global` / `entity` / `account` scopes; switching entities changes which entity/account-scoped groups are visible, while global groups remain visible
- [ ] Action with `field: "category"` value must be a UUID of an `Account` with `management_group: :category` belonging to the same entity; account name is only used for display
- [ ] Classifications are entity-scoped; cross-entity data is never visible

### Concurrent/Ordering

- [ ] Two rules in same group match same transaction -> Only first (by `position`) fires when `stop_processing: true`; if `stop_processing: false`, both fire additively
- [ ] Two groups both match same transaction on different fields -> Both apply; outputs compose (Group 1 sets `category`, Group 2 adds `tags`)
- [ ] If matching groups exist in different scopes, precedence is `account > entity > global`
- [ ] Two groups both target same field (e.g., both `set category`) -> Higher scope precedence wins first; inside the same scope, group with lower `priority` number wins; remaining groups' action for that field is skipped. Field is "claimed" after first-writer sets it. `audit_events` records the winning group only.
- [ ] Group priority ties within the same scope -> Tiebreak by `name ASC` (deterministic, documented)
- [ ] Rule position ties within a group -> Tiebreak by `name ASC` (deterministic, documented)

### Boundary Conditions

- [ ] Maximum rule groups per scope target: no hard limit (soft guidance: warn at 50+)
- [ ] Maximum rules per group: no hard limit (soft guidance: warn at 100+)
- [ ] Maximum conditions per rule: no hard limit in DB; validated as non-empty before compiling to `expression`
- [ ] Maximum actions per rule: no hard limit in DB; validated as non-empty `actions` JSONB array
- [ ] Rule name max length: 160 characters (consistent with other name fields)
- [ ] Notes max length: 2000 characters
- [ ] Tags: each tag max 50 characters, max 20 tags per classification
- [ ] Empty conditions -> Validation error (at least one condition required; `expression` must be non-empty)
- [ ] Empty actions -> Validation error (`actions` JSONB must be a non-empty array)

### Data Integrity

- [ ] Deleting a rule group cascades deletion of contained rules
- [ ] Deleting a rule that is referenced in `ClassificationRecord.{field}_classified_by` JSONB -> Provenance JSON retains the `rule_id` UUID. No FK to worry about (it's JSONB). UI should gracefully handle "rule deleted" case when looking up rule by ID.
- [ ] Deleting a rule group -> Cascade delete contained rules. Existing `ClassificationRecord` provenance JSON retains the IDs (historical record).
- [ ] `ClassificationRecord.transaction_id` has UNIQUE constraint -> Upsert pattern required for apply
- [ ] `audit_events` entries for classification changes are append-only: no update or delete path exposed via context API

---

## UX States

### Rules Page (Group List + Detail)

| State | Behavior |
|-------|----------|
| **Loading** | Show skeleton for groups list |
| **Empty (no groups)** | Show "No rule groups yet" with "New Group" CTA |
| **Has groups, none selected** | Show groups list, auto-select first group |
| **Group selected, no rules** | Show group detail with "Add Rule" CTA |
| **Group selected, has rules** | Show rules table ordered by position with visible scope badge/target |
| **Inactive group** | Dimmed styling, "Inactive" badge, rules still viewable |

### Preview Page/Modal

| State | Behavior |
|-------|----------|
| **Loading preview** | Show spinner with "Running rules..." message |
| **Preview complete, matches found** | Table with transaction rows, matched rules, proposed field changes |
| **Preview complete, no matches** | Show "No rules matched" message |
| **Preview with conflicts** | Highlight manual-override protected rows distinctly |
| **Preview error** | Show error message with retry option |

### Bulk Apply

| State | Behavior |
|-------|----------|
| **Before apply** | Date range selector, "Apply Rules" button |
| **Applying** | Progress indicator, disable button |
| **Apply complete** | Summary: applied/skipped/no-match counts |
| **Apply with errors** | Summary with error details for failed transactions |

### Classification Display (Transaction Detail)

Displayed **per field** (category, tags, investment_type, notes):

| State | Behavior |
|-------|----------|
| **Field unclassified** | Show "(unclassified)" for that field with "Apply Rules" and "Set manually" actions |
| **Field rule-classified** | Show value with "Rule: [group/rule name]" provenance badge; `classified_at` tooltip |
| **Field manually overridden** | Show value with "Manual" provenance badge and lock icon; "Clear override" action visible |
| **Rule ID no longer exists** | Show value with "Rule deleted" warning (graceful JSONB lookup failure) |
| **Mixed** | e.g., `category` manually overridden + lock, `tags` rule-classified — shown independently |

---

## Out of Scope

Explicitly excluded from this feature (Issues #19, #20, #21):

1. **Rule import/export** -- Importing/exporting rules as JSON/YAML files for backup or sharing is deferred.
2. **Rule versioning/history** -- Tracking historical versions of rules (beyond audit events) is deferred. Changes are audited but old rule versions are not preserved as snapshots.
3. **Scheduled rule application** -- Automatically running rules on new transactions (e.g., via Oban job on import completion) is deferred to a follow-up.
4. **Rules against imported rows pre-materialization** -- Running rules against `ImportedRow` records before they become transactions/postings is deferred.
5. **Split classifications** -- Splitting a transaction's classification across multiple categories (partial assignment) is deferred.
6. **Machine learning / confidence scoring** -- The mock UI shows confidence percentages; ML-based matching is out of scope.
7. **Condition type: `merchant_is`** -- The mock UI references merchant matching; there is no merchant field on transactions today. Deferred until merchant extraction is built.
8. **Scope templates / inheritance** -- The unified scope model supports `global`, `entity`, and `account` groups only. Template inheritance, cloning, or cross-scope derivation is deferred.
9. **Rule testing with custom input** -- The mock UI shows a JSON test input; structured test-against-custom-data is deferred (preview against real transactions covers the immediate need).
10. **Zero-condition catch-all rules** -- Rules with no conditions (always-match) are deferred. v1 requires at least one condition. A catch-all can be approximated with `description is_not_empty` if needed.

---

## Context API Shape (Suggested)

The following function names follow project conventions. The tech lead owns the final API design.

**New context: `AurumFinance.Classification`**

Rule Group CRUD:
- `list_rule_groups(opts)` -- scope-aware filters: `scope_type`, `entity_id`, `account_id`, `visible_to_entity_id`, `visible_to_account_ids`, optional `is_active`
- `get_rule_group!(rule_group_id)`
- `create_rule_group(attrs, opts)` -- with audit
- `update_rule_group(rule_group, attrs, opts)` -- with audit
- `delete_rule_group(rule_group, opts)` -- cascades to rules, with audit
- `change_rule_group(rule_group, attrs)` -- for form handling

Rule CRUD (with inline conditions/actions):
- `list_rules(opts)` -- `rule_group_id` required
- `get_rule!(rule_id)`
- `create_rule(attrs, opts)` -- `attrs` include `conditions` (list of structured maps) and `actions` (list of action maps); context compiles `conditions` to `expression`, stores `actions` as JSONB; validates together
- `update_rule(rule, attrs, opts)` -- replaces `expression` and `actions` from structured input
- `delete_rule(rule, opts)` -- with audit
- `change_rule(rule, attrs)` -- for form handling

Engine (Issue #20):
- `preview_classification(opts)` -- `entity_id` required, `date_from`/`date_to` required; returns list of `%ClassificationPreview{}`, no DB writes. Internally loads global groups, entity-scoped groups for the entity, and account-scoped groups matching posting accounts involved in the previewed transactions
- `Classification.Engine.evaluate(transactions, rule_groups)` -- pure function, no DB access; selects matching scoped groups, evaluates `rule.expression`, and applies `rule.actions` in-memory

ClassificationRecord + Manual Override (Issue #21):
- `classify_transactions(opts)` -- `entity_id`, `date_from`, `date_to` required; bulk apply
- `classify_transaction(transaction, opts)` -- single-transaction apply
- `get_classification_record(transaction_id)` -- returns `ClassificationRecord` or nil
- `set_manual_field(transaction_id, field, value, opts)` -- sets one field + `{field}_manually_overridden: true` + audit event
- `clear_manual_override(transaction_id, field, opts)` -- sets `{field}_manually_overridden: false`; does NOT clear the value

---

## Schema Design (ADR-0011)

### `rule_groups` table

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `binary_id` | PK |
| `scope_type` | enum | NOT NULL -- `global | entity | account` |
| `entity_id` | `binary_id` | FK to `entities`, nullable |
| `account_id` | `binary_id` | FK to `accounts`, nullable |
| `name` | `string` | NOT NULL |
| `description` | `text` | nullable |
| `priority` | `integer` | NOT NULL — execution order for conflict resolution (ASC = higher precedence) |
| `target_fields` | `{:array, :string}` / `text[]` | NOT NULL, default `[]` — when non-empty, actions in this group's rules must target listed fields (validated at write time, not at engine eval) |
| `is_active` | `boolean` | NOT NULL, default `true` |
| `inserted_at` | `utc_datetime_usec` | NOT NULL |
| `updated_at` | `utc_datetime_usec` | NOT NULL |

Constraints:
- `global => entity_id IS NULL AND account_id IS NULL`
- `entity => entity_id IS NOT NULL AND account_id IS NULL`
- `account => account_id IS NOT NULL AND entity_id IS NULL`
- `entity_id` and `account_id` are never both set

Indexes: `(scope_type)`, `(entity_id)`, `(account_id)`, unique partial/conditional name indexes per scope target (`global:name`, `entity:(entity_id,name)`, `account:(account_id,name)`), `(scope_type, priority)`, `(scope_type, is_active)`.

### `rules` table

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `binary_id` | PK |
| `rule_group_id` | `binary_id` | FK to `rule_groups`, NOT NULL, on_delete: cascade |
| `name` | `string` | NOT NULL |
| `description` | `text` | nullable |
| `position` | `integer` | NOT NULL — execution order within group (ASC) |
| `is_active` | `boolean` | NOT NULL, default `true` |
| `stop_processing` | `boolean` | NOT NULL, default `true` — first-match-wins per group |
| `expression` | `text` | NOT NULL — compiled condition expression |
| `actions` | `JSONB` | NOT NULL, default `[]` — array of action maps (validated non-empty at context layer) |
| `inserted_at` | `utc_datetime_usec` | NOT NULL |
| `updated_at` | `utc_datetime_usec` | NOT NULL |

Indexes: `(rule_group_id)`, `(rule_group_id, position)`.

Note: `expression` replaces a separate `rule_conditions` table. `actions` replaces a separate `rule_actions` table. No separate condition or action schemas exist.

### `classification_records` table (Issue #21)

Wide table with per-field provenance (ADR-0011 §4). 4 classification fields × 3 columns each = 12 data columns.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `binary_id` | PK |
| `transaction_id` | `binary_id` | FK to `transactions`, NOT NULL, UNIQUE |
| `entity_id` | `binary_id` | FK to `entities`, NOT NULL (denormalized) |
| `category_account_id` | `binary_id` | FK to `accounts` (`management_group: :category`), nullable |
| `category_classified_by` | `JSONB` | nullable — provenance map |
| `category_manually_overridden` | `boolean` | NOT NULL, default `false` |
| `tags` | `JSONB` | NOT NULL, default `[]` — array of strings |
| `tags_classified_by` | `JSONB` | nullable |
| `tags_manually_overridden` | `boolean` | NOT NULL, default `false` |
| `investment_type` | `string` | nullable |
| `investment_type_classified_by` | `JSONB` | nullable |
| `investment_type_manually_overridden` | `boolean` | NOT NULL, default `false` |
| `notes` | `text` | nullable |
| `notes_classified_by` | `JSONB` | nullable |
| `notes_manually_overridden` | `boolean` | NOT NULL, default `false` |
| `inserted_at` | `utc_datetime_usec` | NOT NULL |
| `updated_at` | `utc_datetime_usec` | NOT NULL |

Indexes: unique `(transaction_id)`, `(entity_id)`.

Note: Classification changes are audited via the existing `audit_events` table. No separate `classification_audit_logs` table is created.

---

## Migration Strategy

### Commit 1 (Issue #19): `create_rule_groups_and_rules`
- Creates `rule_groups` table (with `scope_type`, nullable `entity_id`, nullable `account_id`, `priority`, `target_fields`, `is_active`)
- Creates `rules` table (with `expression`, `actions`, `position`, `stop_processing`)
- All indexes and constraints for both tables
- Reversible

### Commit 3 (Issue #21): `create_classification_records`
- Creates `classification_records` table (unique on `transaction_id`, all per-field provenance columns)
- All indexes
- Reversible
- No `classification_audit_logs` migration — uses existing `audit_events` infrastructure

---

## Involved Roles

| Commit | Recommended Agent | Scope |
|--------|-------------------|-------|
| 1 (Issue #19) | `dev-backend-elixir-engineer` | Migrations (2 tables), schemas (RuleGroup, Rule), context CRUD with expression compilation + actions JSONB, factories, context tests |
| 1 (Issue #19) | `dev-frontend-ui-engineer` | Rewrite RulesLive + RulesComponents for real data; condition builder UI; action builder UI |
| 2 (Issue #20) | `dev-backend-elixir-engineer` | Classification.Engine module (expression evaluator + actions JSONB parser), preview_classification/1 API, engine tests |
| 2 (Issue #20) | `dev-frontend-ui-engineer` | Preview UI in RulesLive (per-field diff view) |
| 3 (Issue #21) | `dev-backend-elixir-engineer` | ClassificationRecord schema/migration, classify_transactions/1, set_manual_field/4, per-field override guard, audit_events integration, tests |
| 3 (Issue #21) | `dev-frontend-ui-engineer` | Bulk apply UI, per-field classification display in TransactionsLive (provenance badges, lock icons, clear override) |

---

## Summary of Changes

| Area | What Changes |
|------|-------------|
| **New context** | `AurumFinance.Classification` with rule group/rule CRUD, expression-based engine, preview, classification records |
| **New schema** | `AurumFinance.Classification.RuleGroup` with explicit scope model (`global`, `entity`, `account`) |
| **New schema** | `AurumFinance.Classification.Rule` (with `expression :text` + `actions :jsonb`) |
| **New schema** | `AurumFinance.Classification.ClassificationRecord` (per-field provenance, per-field manual overrides) |
| **New module** | `AurumFinance.Classification.Engine` (pure-function expression evaluator + actions JSONB interpreter) |
| **New migrations** | `create_rule_groups_and_rules`, `create_classification_records` |
| **Rewritten LiveView** | `AurumFinanceWeb.RulesLive` replaces mock data with real CRUD + preview + condition/action builders |
| **Rewritten components** | `AurumFinanceWeb.RulesComponents` updated for real data structures |
| **Modified LiveView** | `AurumFinanceWeb.TransactionsLive` gains per-transaction "Apply Rules" and per-field classification display |
| **Modified components** | `AurumFinanceWeb.TransactionsComponents` gains per-field classification display with provenance badges |
| **New factories** | `rule_group_factory`, `rule_factory`, `classification_record_factory` |
| **Tests** | Context tests for CRUD (expression compilation, actions JSONB validation), engine evaluation, per-field manual override protection, audit_events emission; LiveView tests |

---

## Change Log

| Date | Change | Reason |
|------|--------|--------|
| 2026-03-12 | Initial spec creation | Consolidate issues #19, #20, #21 into unified spec |
| 2026-03-12 | ADR alignment revision | Align with ADR-0003/0004/0011: per-field override semantics, context renamed to `AurumFinance.Classification`, `ClassificationRecord` per transaction |
| 2026-03-12 | Scope model revision | Replaced entity-only groups with a unified explicit scope model: `global`, `entity`, `account`, all using the same `rule_groups` table/schema. |
| 2026-03-12 | Group conflict resolution | Added deterministic scope precedence and `rule_groups.priority` for conflict resolution: groups evaluated by `account > entity > global`, then `priority ASC`, then `name ASC`; first-writer-wins per field. `target_fields` upgraded to weak validation at write time. |
| 2026-03-12 | Target fields persistence | Normalized `rule_groups.target_fields` to Postgres string array (`text[]`) instead of JSONB so DB type and Ecto schema match the actual usage. |
| 2026-03-12 | Simplified persistence model | Removed `rule_conditions` and `rule_actions` tables. Conditions compiled to `rules.expression :text`; actions stored as `rules.actions :jsonb`. Removed `ClassificationAuditLog` / `classification_audit_logs` table; classification audit events use existing `audit_events` infrastructure. |
| 2026-03-12 | Rule authoring UX v1 | Create via guided builder only; edit via raw expression editor only (no bidirectional parse). Backend validates `expression` on every save — invalid expressions rejected, never persisted. No "broken rule" state. |
